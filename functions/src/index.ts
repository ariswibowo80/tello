import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

const ACTIVE_PLAN_STATUSES = ["idea", "planning", "confirmed", "ongoing"];

interface NotificationSettings {
  planReminders: boolean;
  onThisDay: boolean;
  upcomingEventReminders: boolean;
}

const DEFAULT_SETTINGS: NotificationSettings = {
  planReminders: true,
  onThisDay: true,
  upcomingEventReminders: true,
};

function monthDayKey(date: Date): string {
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${month}-${day}`;
}

function isSameLocalDate(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function addDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

/** Best-effort conversion of "now" into a user's local time using their
 * stored IANA timezone string. Falls back to server time (UTC) if the
 * timezone is missing or invalid, rather than throwing — a wrong-timezone
 * notification hour is a much smaller problem than crashing the whole
 * scheduled run partway through every user.
 */
function localNowFor(timezone: string | undefined): Date {
  if (!timezone) return new Date();
  try {
    return new Date(new Date().toLocaleString("en-US", { timeZone: timezone }));
  } catch {
    return new Date();
  }
}

async function sendToUser(
  userId: string,
  tokens: string[],
  title: string,
  body: string,
  route: string
): Promise<void> {
  if (tokens.length === 0) return;
  try {
    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { route },
    });

    const invalidTokens = response.responses
      .map((r, i) => (r.success ? null : tokens[i]))
      .filter((t): t is string => t !== null);

    if (invalidTokens.length > 0) {
      await db
        .collection("users")
        .doc(userId)
        .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) });
    }
  } catch (error) {
    functions.logger.error(`Failed to send notification to user ${userId}`, error);
  }
}

/**
 * Runs hourly and, for each user, only actually sends notifications
 * during their local 9am hour. This is the practical stand-in for "one
 * scheduled trigger per user's timezone" — running N per-timezone
 * schedules (or a queue-based fan-out) would be the next step if this
 * hourly-scan-of-all-users approach stops scaling; documented as a known
 * limitation in the README.
 */
export const sendDailyNotifications = functions.pubsub
  .schedule("every 1 hours")
  .timeZone("UTC")
  .onRun(async () => {
    const usersSnapshot = await db.collection("users").get();

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const tokens: string[] = userData.fcmTokens ?? [];
      if (tokens.length === 0) continue;

      const localNow = localNowFor(userData.timezone as string | undefined);
      if (localNow.getHours() !== 9) continue;

      const settingsSnap = await db
        .collection("users")
        .doc(userId)
        .collection("settings")
        .doc("notifications")
        .get();
      const settings: NotificationSettings = {
        ...DEFAULT_SETTINGS,
        ...(settingsSnap.data() as Partial<NotificationSettings> | undefined),
      };

      if (settings.planReminders || settings.upcomingEventReminders) {
        await sendPlanNotifications(userId, tokens, localNow, settings);
      }
      if (settings.onThisDay) {
        await sendOnThisDayNotification(userId, tokens, localNow);
      }
    }
  });

async function sendPlanNotifications(
  userId: string,
  tokens: string[],
  localNow: Date,
  settings: NotificationSettings
): Promise<void> {
  const plansSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("plans")
    .where("status", "in", ACTIVE_PLAN_STATUSES)
    .get();

  const inSevenDays = addDays(localNow, 7);

  for (const planDoc of plansSnapshot.docs) {
    const plan = planDoc.data();
    const startDate: Date = plan.startDate.toDate();

    if (settings.planReminders && isSameLocalDate(startDate, localNow)) {
      await sendToUser(
        userId,
        tokens,
        "Your plan starts today!",
        `${plan.title} starts today.`,
        `/plan/${planDoc.id}`
      );
    } else if (settings.upcomingEventReminders && isSameLocalDate(startDate, inSevenDays)) {
      await sendToUser(
        userId,
        tokens,
        "Coming up in a week",
        `${plan.title} is in 7 days.`,
        `/plan/${planDoc.id}`
      );
    }
  }
}

async function sendOnThisDayNotification(
  userId: string,
  tokens: string[],
  localNow: Date
): Promise<void> {
  const momentsSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("moments")
    .where("monthDay", "==", monthDayKey(localNow))
    .get();

  const pastMoments = momentsSnapshot.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    .filter((m: any) => m.startDate.toDate().getFullYear() < localNow.getFullYear());

  if (pastMoments.length === 0) return;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  pastMoments.sort(
    (a: any, b: any) => b.startDate.toDate().getFullYear() - a.startDate.toDate().getFullYear()
  );
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const moment: any = pastMoments[0];
  const yearsAgo = localNow.getFullYear() - moment.startDate.toDate().getFullYear();
  const place = moment.location?.name ? ` in ${moment.location.name}` : "";

  await sendToUser(
    userId,
    tokens,
    "On This Day",
    `${yearsAgo} ${yearsAgo === 1 ? "year" : "years"} ago${place}: ${moment.title}`,
    `/moment/${moment.id}`
  );
}

/**
 * Firestore doesn't cascade-delete subcollections, and Firestore security
 * rules in this app deny direct client deletes on `/users/{userId}` (see
 * firestore.rules) specifically so account deletion routes through here
 * instead of an incomplete client-side recursive delete.
 */
export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  const subcollections = ["moments", "plans", "people", "places", "settings"];

  for (const name of subcollections) {
    await deleteCollectionInBatches(db.collection("users").doc(userId).collection(name), 200);
  }
  await db.collection("users").doc(userId).delete();
});

async function deleteCollectionInBatches(
  collectionRef: FirebaseFirestore.CollectionReference,
  batchSize: number
): Promise<void> {
  const snapshot = await collectionRef.limit(batchSize).get();
  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  if (snapshot.size === batchSize) {
    await deleteCollectionInBatches(collectionRef, batchSize);
  }
}
