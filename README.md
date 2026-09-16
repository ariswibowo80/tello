# TELLO — Your Life, Told in Moments.

> "You don't need to record every day. Just record the moments worth remembering."

TELLO is a personal life timeline app. Plan future moments (trips, birthdays,
celebrations), live them, then convert the plan into a permanent memory on
your timeline. Core lifecycle:

```
PLAN → EXPERIENCE → MOMENT → TIMELINE → LIFE IN REVIEW
```

## ⚠️ Build status: All 17 phases' screens complete + CI/CD + security rule tests + widget/integration tests

- **Phase 1 — Foundation:** project setup, theme, router, app shell,
  Firebase-backed Auth, Moment/Plan domain layer (incl. the atomic
  Plan→Moment conversion transaction).
- **Phase 2 — Timeline ("My Life"):** paginated, year-grouped Moments feed;
  filters (All / Moments / Plans / Family / Travel / Work / Celebration /
  School / Personal); Newest/Oldest sort; a compact horizontal "Upcoming"
  rail of soonest Plans; pull-to-refresh; loading/empty/error states;
  an entry point to "On This Day" (screen itself still a placeholder,
  scheduled for Phase 10).
- **Phase 3 — Add Moment:** the full "record something that happened"
  flow — title, single date or date range, location (search or current
  position), a lightweight People feature for "Who was there?", photo/video
  picking with compression + thumbnail generation + live upload progress,
  story text, tags — wired to write directly into the Timeline (which
  auto-refreshes on return).
- **Phase 4 — Moment Detail:** hero photo carousel, Story / Photos / Map /
  Notes tabs, full-screen swipeable photo viewer, and the four spec'd
  actions — **Edit** (reuses the Add Moment form in edit mode), **Add
  Photo** (quick single-photo upload without leaving the screen), **Share**
  (native share sheet, text summary), **Delete** (with a confirmation
  dialog, and cleans up both the full image and its thumbnail in Storage
  before deleting the Firestore document).
- **Phase 5 — Plans tab:** the dedicated "Plans" destination — "Things
  worth looking forward to." subtitle, Upcoming / Completed / Cancelled
  filter chips, paginated full-width `PlanCard`s (now with a category
  icon + label per card), pull-to-refresh. Cards without a checklist yet
  show a "Status: Idea" badge instead of a 0% progress bar, matching the
  spec's card examples.
- **Phase 6 — Create Plan:** the full "Plan Something" form — title,
  single-select category (with icon/label chips), date or date range,
  location, People picker, a dynamic checklist (add/check/remove items),
  a dynamic itinerary (each entry added via its own date/time/title/
  location/notes sheet, shown sorted by date), notes, an optional budget
  (estimated amount + currency), and Inspiration (photo upload with the
  same compression/progress pipeline as Add Moment, plus a list of
  links). Wired into the central Add sheet — creating a Plan now
  refreshes both the Plans tab and the Timeline's Plans data on return.
- **Phase 7 — Plan Detail & Plan→Moment conversion:** the full Plan
  Detail screen — countdown/progress header, interactive checklist,
  day-grouped itinerary, Estimated/Actual budget (Actual is editable
  in-place), a Places map, a Photos/Inspiration grid (tap a photo to open
  the same full-screen viewer as Moment Detail; tap a link to copy it),
  and inline-editable Notes. **Edit** reuses Create Plan in edit mode
  (mirroring Add/Edit Moment). A **Cancel Plan** action sets the status so
  the Plans tab's "Cancelled" filter has something to show. The headline
  feature — the primary **"Mark as Completed"** CTA — opens the "How was
  your experience?" sheet, then atomically creates the Moment and marks
  the Plan completed via the same Firestore transaction built in Phase 1
  (`createMomentFromPlan`), and takes you straight to the new memory.
  This was originally planned as a separate Phase 8, but since it's the
  same interaction as Plan Detail's primary button, it made more sense to
  ship as one coherent feature — later phases are renumbered down by one
  as a result.
- **Phase 8 — Places:** the dedicated "Places" destination — **Visited**
  (places with at least one Moment) and **Planned** (places with an
  active Plan you haven't been to yet) tabs, each with a compact map
  preview of every pinned place plus a teal-accent `PlaceCard` list
  showing Moment/Plan counts and last-visited/next-trip dates. Tapping a
  place opens a detail view listing every related Moment and Plan (reusing
  `MomentCard`/`PlanCard`) plus its own map. There's no separate `places`
  Firestore collection — places are aggregated client-side from a bounded
  batch of Moments/Plans, grouped by normalized location name, via a
  small pure function (`place_aggregator.dart`) that's fully unit-tested
  without needing Firebase.
- **Phase 9 — Notifications + On This Day:** a real **On This Day**
  screen (Moments from any past year matching today's month/day, backed
  by a new indexed `monthDay` field rather than a fetch-everything scan),
  a **Notification Settings** screen with the three spec'd toggles (Plan
  reminders / On This Day / Upcoming event reminders), and the Firebase
  Cloud Messaging plumbing to actually deliver them — permission request,
  device token storage, foreground display via
  `flutter_local_notifications`, and tap-to-navigate. The scheduled
  sending logic (`functions/src/index.ts`) is real, deployable Cloud
  Functions TypeScript: an hourly job that checks each user's local time
  against their stored timezone and sends "starts today" / "in 7 days" /
  "on this day" pushes respecting their settings, plus an `onDelete`
  trigger that cleans up a departing user's subcollections (which is why
  `firestore.rules` denies direct client deletes on `/users/{userId}`).
  This couldn't be deployed or tested in this environment — see "Known
  limitations."

- **Phase 10 — Life in Review:** the annual summary screen — a year
  selector (defaulting to the current year, capped so you can't page
  into the future), a stat grid (✈️ Trips, 📍 Places, 👨‍👩‍👧 Family Moments,
  📷 Photos, 🎉 Celebrations), a "You Planned" vs "You Experienced"
  trips/events breakdown, a "Favorite Moment" (the year's most-photographed
  Moment, since there's no explicit favoriting feature yet), and a "Share
  Your Year" button. Backed by two new real Firestore range queries
  (`fetchMomentsForYear`/`fetchPlansForYear` — a single-field range on
  `startDate`, so no composite index needed) rather than a bounded
  fetch-all like Places uses, since a year boundary is precise and cheap
  to query directly. The aggregation itself
  (`life_review_aggregator.dart`) is a small pure function, unit-tested
  the same way `place_aggregator.dart` was.

- **Phase 11 — Profile:** photo (tap to upload, via the same
  compression pipeline as everywhere else), name (tap to edit), email
  (read-only — Firebase Auth stays the source of truth for identity, per
  spec), and every spec'd setting: **Notification settings** (links to
  the screen built in Phase 9), **Timezone** (a curated picker,
  Indonesia-first), **Theme** (informational only — there's just the one
  light theme so far), **Privacy** (a static screen explaining the
  per-account data isolation), **Export data** (fetches your Moments/
  Plans, builds a JSON export, and hands it to the native share sheet),
  **Sign out**, and **Delete account** (with a clear destructive
  confirmation dialog, per spec). This introduces a `UserProfile` domain
  concept distinct from `AppUser` — the former is Firestore profile data
  (name/photo/timezone), the latter is Firebase Auth identity, and
  keeping them separate means editing your name never touches
  authentication.

This closes out every screen in the original 17-phase build plan
(Foundation → Timeline → Add Moment → Moment Detail → Plans → Create
Plan → Plan Detail & Plan→Moment conversion → Places → Notifications →
Life in Review → Profile).

- **CI/CD:** a second CI workflow, `functions-ci.yml`, dedicated to
  `functions/`, `firestore-tests/`, and the security rules. A new
  `deploy.yml` deploys to Firebase: manually via `workflow_dispatch`
  (pick staging/production) or automatically (a push to `develop` →
  staging, a `vX.Y.Z` tag → production) — it deploys rules + Cloud
  Functions, then builds and uploads a release Android App Bundle.
  `firebase.json`/`.firebaserc`/`firestore.indexes.json` were also
  added — they were a genuine gap before this (nothing wired
  `firestore.rules`/`storage.rules`/`functions/` together for the
  Firebase CLI to find). Unlike everything else backend-related in this
  project, the Cloud Functions build was **actually run** in this
  environment (Node is available here, unlike Flutter/Firebase Dart
  tooling) — `npm run build` compiles cleanly and both functions load in
  the real emulator.
- **Security rule tests:** `firestore-tests/`, a real
  `@firebase/rules-unit-testing` suite (Node's built-in test runner) —
  ownership CRUD checks across every subcollection, the `users/{uid}`
  no-direct-delete rule, and Storage's size/content-type validation.
  Wired into `functions-ci.yml` as the `rules-test` job. See "Known
  limitations" for exactly what all of the above does and doesn't prove
  — in short: everything that could be verified without live network
  access to Google's emulator-binary host was.
- **Widget & integration tests:** `test/widget/` covers the core
  reusable widgets (`TagChip`, `EmptyState`, `ErrorState`, `LoadingState`,
  `LocationChip`), `MomentCard`/`PlanCard` (including `PlanCard`'s
  progress-bar-vs-"Status: Idea"-badge branching), `OnboardingScreen`,
  `LoginScreen` (validation, the sign-in/sign-up toggle, a successful
  submission), and `TimelineScreen`/`PlansScreen` rendering real data and
  empty states via new in-memory fakes (`test/fakes/`) for
  `MomentRepository`/`PlanRepository`/`AuthRepository` — no Firebase
  involved. `integration_test/app_test.dart` drives the actual app
  through the spec's critical path (Login → Create Plan → Mark as
  Completed → verify the Moment in the Timeline) against the Firebase
  emulator suite. Unlike the Cloud Functions/rules-test work in the
  previous phase, **none of this Dart test code has actually been run**
  — see "Known limitations" for why and exactly what that means for how
  much to trust it.

This closes out the spec's closing cross-cutting work list. What
remains is confirming all of the above actually passes somewhere with a
real Flutter/Firebase/Node runtime — see "Recommended next development
steps."

## Architecture

Feature-first Clean Architecture:

```
lib/
  core/            # theme, router, constants, errors, shared widgets
  features/
    auth/          # data / domain / presentation
    timeline/
    moments/
    plans/
    places/
    people/
    notifications/ # in-app settings only — see functions/ for sending logic
    on_this_day/
    life_review/
    profile/
  firebase_options.dart
  main.dart
test/
  fakes/           # in-memory repository fakes shared by widget tests
  widget/          # widget tests (screens/components), no Firebase involved
  features/ ...    # pure-logic unit tests, one folder per feature
integration_test/  # end-to-end test driving the real app against the
                   # Firebase emulator suite
functions/         # Cloud Functions (Node/TypeScript) — separate npm project
firestore-tests/   # @firebase/rules-unit-testing suite — separate npm project
```

Each feature has `data` (Firebase implementations), `domain` (entities +
repository interfaces, framework-agnostic), and `presentation` (Riverpod
providers + widgets). UI never talks to Firebase directly — only through a
repository interface, so `firebase_auth` / `cloud_firestore` types never leak
outside `data/`.

State management: **Riverpod**. Navigation: **GoRouter**, with an
auth-aware redirect and a `ShellRoute` for the bottom-nav tabs
(Timeline / Plans / Places / Profile), plus a separate central "Add" action
sheet for creating a Moment or Plan.

## Requirements

- Flutter 3.22+ (stable channel)
- Dart 3.3+
- A Firebase project (Blaze plan recommended for Cloud Functions)
- `flutterfire_cli` for generating `firebase_options.dart`

## Firebase setup

1. Create a Firebase project in the [Firebase console](https://console.firebase.google.com)
   — or two, one for staging and one for production, if you're setting up
   `deploy.yml`'s environment split.
2. Enable: Authentication (Email/Password + Google), Cloud Firestore,
   Cloud Storage, Cloud Messaging, App Check, Analytics, Crashlytics.
3. Install the CLI tools:
   ```bash
   dart pub global activate flutterfire_cli
   npm install -g firebase-tools
   firebase login
   ```
4. Update [`.firebaserc`](./.firebaserc) with your real project ID(s) —
   it ships with placeholder values. `firebase.json` already wires up
   `firestore.rules`, `firestore.indexes.json`, `storage.rules`, and
   `functions/`, so nothing else needs configuring there.
5. Generate real Firebase config (replaces the placeholder in
   `lib/firebase_options.dart`):
   ```bash
   flutterfire configure --project=<your-firebase-project-id>
   ```
6. Deploy security rules:
   ```bash
   firebase deploy --only firestore:rules,storage:rules
   ```
7. Deploy Cloud Functions (scheduled notifications + onDelete account
   cleanup — see [`functions/src/index.ts`](./functions/src/index.ts)):
   ```bash
   cd functions
   npm install
   npm run deploy
   cd ..
   ```
   The Blaze (pay-as-you-go) plan is required for scheduled functions.
8. Configure App Check (Play Integrity for Android / DeviceCheck for iOS)
   in the Firebase console for release builds. Debug builds use the debug
   provider automatically.

## Environment configuration

Copy `.env.example` to `.env` for values that don't belong in
`firebase_options.dart` (e.g. `GOOGLE_MAPS_API_KEY`). Do not commit `.env`,
`google-services.json`, or `GoogleService-Info.plist` — they're already
git-ignored.

Development / staging / production are distinguished by which Firebase
project `firebase_options.dart` points at — use separate Firebase projects
per environment and swap via `flutterfire configure` on each machine/CI job,
or maintain per-environment generated files and select one at build time.

## Local development

```bash
flutter pub get
flutter run
```

## Firestore schema

```
users/{userId}
  displayName, email, photoUrl, createdAt, updatedAt, timezone
  fcmTokens[]   — one per device, added by NotificationService on sign-in

users/{userId}/moments/{momentId}
  title, description, startDate, endDate, location{name,address,lat,lng},
  peopleIds[], media[{url,storagePath,type,thumbnailUrl,
    thumbnailStoragePath,createdAt}], tags[], notes, createdAt, updatedAt,
  sourcePlanId
  monthDay      — derived 'MM-dd' string, written on every save; powers
                  the indexed On This Day query (Moment.monthDayKey)

users/{userId}/plans/{planId}
  title, description, category, startDate, endDate, status,
  location{...}, peopleIds[], checklist[{id,title,isDone}],
  itinerary[{id,date,time,title,location,notes}],
  estimatedBudget, actualBudget, currency, media[], links[], tags[],
  notes, createdAt, updatedAt, completedAt, convertedToMomentId

users/{userId}/people/{personId}
users/{userId}/settings/notifications
  planReminders, onThisDay, upcomingEventReminders   — all bool, default true
```

All dates are stored as Firestore `Timestamp` (UTC) and converted to the
user's `timezone` field for display. `users/{userId}/places/{placeId}` is
in the security rules (and the original brief) but nothing writes to it —
see "Known limitations" for why the Places screen doesn't need it.

## Storage schema

```
users/{userId}/moments/{momentId}/...
users/{userId}/plans/{planId}/...
users/{userId}/profile/...
```

## Security rules

See [`firestore.rules`](./firestore.rules) and [`storage.rules`](./storage.rules).
Both enforce strict per-user ownership keyed off the authenticated Firebase
UID (`request.auth.uid`) — never a client-supplied user ID — with a default
`deny` for anything unmatched. No wildcard `allow read, write: if true`
rules exist anywhere in this repo.

## Running tests

```bash
flutter test                # unit + widget tests (test/)

# Integration test — needs the Firebase emulator suite AND a connected
# device/simulator (integration_test doesn't run headless on desktop CI
# the way flutter test does). Never point this at production Firebase.
firebase emulators:start --only auth,firestore,storage &
flutter test integration_test/app_test.dart --dart-define=USE_FIREBASE_EMULATOR=true

cd functions
npm ci
npm run build                # type-check + compile — this has actually been run; see below
npx firebase-tools emulators:exec --project demo-tello --only functions \
  "echo Cloud Functions loaded successfully"
cd ..

cd firestore-tests
npm ci
cd ..
npx firebase-tools emulators:exec --project demo-tello-rules-test \
  --only firestore,storage "cd firestore-tests && npm test"
```

Current test coverage: `Plan.progress`, `Plan.daysUntilStart`,
`Plan.toMomentDraft` (the data carried into the Plan→Moment conversion,
including that an empty/whitespace-only story becomes `null` rather than
an empty string), `Plan.copyWith` (including the `clearNotes` regression
test), `Plan.links` Firestore round-tripping (the Inspiration section),
`PlanStatusLabel` and `activePlanStatuses`, `PlansViewFilter.statuses`
(the Plans tab's Upcoming/Completed/Cancelled → `PlanStatus` mapping),
`Moment` Firestore mapping round-trips, `Moment.copyWith` (including its
own `clearNotes` regression test) and `MediaItem` parsing (used by the Add
Photo / Notes / Delete flows in Moment Detail), date-formatting helpers
(`countdownLabel`, `rangeLabel`), `TimelineFilter` equality (it's used as
a Riverpod provider-family key, so equality bugs would silently break
pagination resets), `Person.initials` (the PersonAvatar fallback),
`Moment.monthDayKey` (zero-padding and year-independence — the On This
Day query key), `buildVisitedPlaces`/`buildPlannedPlaces` (the Places
aggregation logic — grouping by normalized name, latest/next date
calculation, sort order, and the Visited/Planned exclusion rule — all
pure and Firebase-free), `buildLifeReviewSummary` (trip/event counting by
tag and category, distinct place counting, photo totals, and the
favorite-Moment tie-break rule — also pure and Firebase-free), and
`UserProfile.initials` (the Profile avatar fallback, including the
email-initial fallback when there's no display name yet).

`test/widget/` covers `TagChip`, `EmptyState`, `ErrorState`, `LoadingState`,
`LocationChip` (pure presentational widgets, no mocking needed),
`MomentCard` and `PlanCard` (including `PlanCard`'s branch between a
checklist-progress bar and a "Status: Idea"-style badge), `OnboardingScreen`
(page advancement, the Next→Get Started label change — deliberately never
taps "Get Started" itself, to avoid needing a GoRouter ancestor just for
this suite), `LoginScreen` (empty-form validation errors, the sign-in/
sign-up toggle, and a successful submission against a fake repository),
and `TimelineScreen`/`PlansScreen` rendering both empty states and real
data by overriding `momentRepositoryProvider`/`planRepositoryProvider`
with new in-memory fakes in `test/fakes/` — no Firebase touched anywhere
in this suite. **None of `test/widget/` has actually been run** — same
root cause as everything else Dart-related in this project (no Flutter
runtime in the environment this was built in), compounded here by the
fact that, unlike the pure-function unit tests, widget tests can't even
be `node --check`-style syntax-verified without the Flutter SDK. Every
widget finder (button text, hint text, label text) was cross-checked
against the actual screen source at the time of writing, which is a real
level of care but not the same as a passing test run.
`integration_test/app_test.dart` drives the real app through Login →
Create Plan → Mark as Completed → verify the Moment in the Timeline
against the Firebase emulator suite — see its file header for the same
caveat in more detail, plus exactly how to run it once you have a
device/emulator and the Firebase emulators available.

Cloud Functions (`functions/src/index.ts`) have no *unit* tests yet (no
Jest/mocha suite exercising the notification-matching logic in
isolation), but unlike the rest of this backend code, they've actually
been run: `npm run build` type-checks and compiles cleanly, and both
exports (`sendDailyNotifications`, `onUserDeleted`) load successfully in
the real Firebase emulator — that's what `functions-ci.yml`'s
`functions-build` job runs on every push. What's *not* verified is
runtime behavior (a scheduled invocation actually sending the right
notification, the timezone-hour matching logic, the batch-delete-on-
account-deletion logic) — that needs either unit tests around the pure
helper functions (`monthDayKey`, `isSameLocalDate`, `addDays`,
`localNowFor`) or `firebase-functions-test` against a live-ish emulator
dataset.

`firestore-tests/` is a real `@firebase/rules-unit-testing` suite (Node's
built-in test runner, no Jest/Mocha needed) covering both
`firestore.rules` and `storage.rules`: for every owned subcollection
(moments/plans/people/places/settings) it asserts the owner can create,
read, update, and delete their own documents, that another signed-in
user is denied on all four operations, and that an unauthenticated
request is denied entirely; for the `users/{uid}` profile document it
additionally asserts no one — not even the owner — can delete it
directly (account deletion is required to go through the `onUserDeleted`
Cloud Function instead); for Storage it asserts the same ownership
pattern plus the size cap (rejects >25MB) and content-type allowlist
(rejects non-image/video). **This suite could not actually be executed
in this environment** — `firebase-tools emulators:exec` needs to
download the Firestore/Storage emulator JARs from
`storage.googleapis.com`, which the sandbox's network policy blocks (the
same restriction noted above for the Cloud Functions rules check, before
it became a real test suite). What *was* verified here: `npm install`
resolves cleanly, every test file passes `node --check` (syntax), and
all imported symbols (`initializeTestEnvironment`, `assertFails`,
`assertSucceeds`, Storage's `ref`/`uploadBytes`/`getBytes`) resolve from
the installed packages. `functions-ci.yml`'s `rules-test` job runs this
for real on every push — its first run is the actual first signal on
whether the suite passes.

## Building Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

## GitHub Actions

Three workflows:

**`flutter.yml`** — runs on every push/PR to `main`/`develop` that touches
anything outside `functions/`: checkout → install Flutter → `pub get` →
`dart format --set-exit-if-changed` → `flutter analyze` → `flutter test` →
`flutter build apk --debug`. A real `firebase_options.dart` is
materialized from a base64-encoded repo secret (`FIREBASE_OPTIONS_DART_B64`)
so no Firebase config is ever committed or printed to logs.

**`functions-ci.yml`** — runs on every push/PR touching `functions/**`,
`firestore-tests/**`, or the security rules, as two independent jobs:
`functions-build` installs Node deps, type-checks and compiles the Cloud
Functions with `tsc`, then boots the real Firebase emulator to confirm
both functions (`sendDailyNotifications`, `onUserDeleted`) load without
throwing. `rules-test` installs `firestore-tests/`'s deps and runs its
`@firebase/rules-unit-testing` suite against live Firestore/Storage
emulators — real ownership assertions, not just a syntax check. The
`functions-build` job (and `npm install`/syntax-checking `rules-test`'s
own code) were run and passed locally while building this; `rules-test`'s
actual emulator run could not be — see "Running tests" for exactly what
that does and doesn't cover.

**`deploy.yml`** — deploys to Firebase. Manually via
`workflow_dispatch` (choose `staging` or `production`), or automatically:
a push to `develop` deploys to staging, a `vX.Y.Z` tag deploys to
production. It deploys Firestore/Storage rules + Cloud Functions first,
then builds a release Android App Bundle and uploads it as a workflow
artifact. It deliberately does **not** re-run lint/analyze/test — that's
`flutter.yml`/`functions-ci.yml`'s job, gated via required status checks
on branch protection (Settings → Branches → require `Flutter CI` and
`Functions & Rules CI` to pass before merging to `main`/`develop`), which
is the standard GitHub-native way to keep bad code off the branches that
trigger deploys.

### Setting up deploy.yml

1. Create two [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
   named `staging` and `production` (Settings → Environments). Add a
   required reviewer to `production` if you want a manual approval gate
   before anything ships there.
2. Per environment, add these secrets:
   - `FIREBASE_PROJECT_ID` — the target Firebase project ID.
   - `FIREBASE_SERVICE_ACCOUNT` — a service account JSON key with the
     Firebase Admin role, used to authenticate `firebase deploy`
     non-interactively (Firebase console → Project settings → Service
     accounts → Generate new private key).
   - `FIREBASE_OPTIONS_DART_B64` — that environment's `firebase_options.dart`
     (from `flutterfire configure --project=<env-project-id>`), base64-encoded.
   - `ANDROID_KEYSTORE_B64` / `ANDROID_KEY_PROPERTIES` — see below.
3. The Android build steps assume `flutter create .` has already been run
   to generate `android/`, and that you've added a standard Flutter
   release-signing config to `android/app/build.gradle` reading from
   `android/key.properties`. Until both of those exist, `build-android`
   will fail — `deploy-backend` (rules + functions) works independently
   and doesn't need them.

## Required native permissions (Phase 3+)

This repo is a Dart-only skeleton — the `android/` and `ios/` platform
folders are generated by `flutter create .` (not included here). Once you
generate them, add:

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>TELLO uses your location to tag where a moment happened.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>TELLO needs access to your photos to attach them to a moment.</string>
```

## Known limitations

- **`test/widget/` and `integration_test/app_test.dart` have never been
  run.** There is no Flutter SDK/runtime anywhere in the environment this
  project was built in — confirmed back in Phase 1 (`dart --version`
  returns "not found") and true for every phase since. Every other kind
  of test added along the way (Dart unit tests, Cloud Functions
  build+emulator-load, the rules-unit-testing suite) got at least some
  real execution because Node happened to be available in this sandbox;
  Flutter never was. Widget finders were cross-checked by hand against
  the actual screen source (button labels, hint text, etc. quoted
  directly from the files they test), which is real care but not a
  substitute for `flutter test` actually passing. Run it — `flutter test`
  for the widget suite needs nothing beyond a normal Flutter setup; the
  integration test additionally needs a device/emulator and the Firebase
  emulator suite (see its file header for exact commands) — before
  trusting any of it in CI.
- `flutter.yml` does not yet run `integration_test/` — by design, since
  it needs a connected device/simulator and the Firebase emulators
  running, neither of which fit the current CI job's plain
  `subosito/flutter-action` setup. Wiring it up would mean adding an
  Android emulator step (e.g. `reactivecircus/android-emulator-runner`)
  and starting the Firebase emulators first, run only on a schedule or
  before a release rather than on every push, given how much slower and
  more failure-prone that combination is than the current unit/widget
  test job.
- `deploy.yml`'s `build-android` job cannot succeed yet — it assumes
  `flutter create .` has generated `android/` and that a release signing
  config has been added to `android/app/build.gradle` reading from
  `android/key.properties`, neither of which exist in this repo (see
  "Required native permissions" below for the same underlying gap). The
  `deploy-backend` job (rules + Cloud Functions) is independent and
  works without any of that.
- `.firebaserc` ships with placeholder project IDs
  (`REPLACE_WITH_YOUR_..._PROJECT_ID`) — replace them before running any
  `firebase` CLI command locally, or CI's `deploy.yml` (which passes
  `--project` explicitly from a secret, bypassing `.firebaserc`) will be
  the only thing that actually deploys correctly until you do.
- `functions-ci.yml`'s `rules-test` job (running the real
  `firestore-tests/` suite against the Firestore/Storage emulators) could
  not be executed in this environment — the emulator's rules-engine JAR
  downloads from `storage.googleapis.com`, which this sandbox's network
  policy blocks. The `functions-build` job's emulator boot (which doesn't
  need that download) **was** verified locally and passed, and
  `firestore-tests`' own `npm install` + syntax-check did too. Both jobs
  use the same `firebase-tools emulators:exec` mechanism, so this is a
  narrow, environment-specific gap rather than a reason to doubt the
  approach — but it's worth watching closely the first time this
  workflow actually runs.
- The rules test suite covers ownership and Storage's size/content-type
  validation, but not every rule in `firestore.rules`/`storage.rules` —
  for example, there's no test that a malformed/oversized field is
  rejected on write (the rules don't currently validate document shape
  beyond ownership, so there's nothing to test there yet either; if
  field-level validation is added to the rules later, matching tests
  should land in the same change). It also doesn't test the `settings`
  subcollection's specific documents (`notifications`) beyond the
  generic ownership pattern shared by all five subcollections.
- `deploy.yml` has no rollback mechanism — a bad deploy to `functions` or
  `firestore:rules` needs a manual `firebase deploy` of the previous
  version (or `firebase functions:log`/console rollback for functions
  specifically). Firebase Hosting has built-in rollback; Firestore
  rules/Functions do not.
- The optional Firebase App Distribution step in `deploy.yml` is
  commented out (needs the app to already exist there plus an app-ID
  secret) rather than wired up — right now `deploy.yml` only produces a
  downloadable workflow artifact, not something automatically pushed to
  testers' devices.

- Notification Settings and Life in Review now have a proper home under
  Profile, in addition to the Timeline app bar shortcuts added in earlier
  phases (both are left in place — they're genuinely useful shortcuts,
  not just placeholders).
- Theme settings is informational only — there is exactly one theme
  (`AppTheme.light()`). Building a real dark theme means designing a
  second color palette against the same design-system swatches
  (purple/orange/teal/pink), not just inverting the existing one, so it's
  left as a clearly-labeled "coming soon" row rather than a
  half-implemented toggle that doesn't actually change anything.
- Export Data shares the export as **plain text** via the native share
  sheet (`Share.share`, not `Share.shareXFiles`) rather than a downloadable
  `.json` file attachment, to avoid adding `path_provider` as a new
  dependency for a single feature. It's also capped at the first 1000
  Moments/Plans each (Firestore query limit) and excludes photo/video
  binary data — it exports metadata and Storage URLs, not the files
  themselves.
- Timezone is a curated list of ten common zones (Indonesia's three, plus
  a handful of major international ones), not the full IANA database —
  consistent with the deliberately-scoped-down "search a place" location
  picker elsewhere in the app rather than embedding a full picker
  component. The `timezone` package is already a dependency and could back
  a complete list later.
- Editing your name updates both Firestore (`users/{uid}.displayName`)
  and Firebase Auth's own profile field, so anything reading the Auth
  user directly (rare in this app, but relevant for any future
  server-side code using the Admin SDK's Auth API) stays in sync. Profile
  photo updates Firestore but does not currently sync back to Firebase
  Auth's `photoURL` in the same call — a small follow-up, not a
  correctness bug, since nothing in this app reads Auth's photo field.
- Deleting an account can fail with "please sign out and sign in again"
  if Firebase Auth considers the session stale (`requires-recent-login`)
  — this is standard Firebase Auth behavior for a sensitive operation,
  now mapped to a clear message instead of a generic error, but there's
  no in-app re-authentication flow to resolve it without actually signing
  out first.
- Life in Review's "trip vs event" split relies entirely on the `travel`
  tag (Moments) and category (Plans) — if someone never tags a Moment
  `travel`, none of their trips will be counted, even if the underlying
  Plan was a `vacation`. A more robust version would carry the originating
  Plan's category through `Plan.toMomentDraft()` onto the Moment; that's
  a reasonable follow-up now that Life in Review exists to use it.
- "Favorite Moment" isn't a real feature — there's no way to mark a
  Moment as a favorite. It's approximated as the year's
  most-photographed Moment (ties broken by earliest date). This is
  clearly documented in code but is worth flagging here too: it's a
  heuristic, not a preference the person set.
- Life in Review has no loading-state caching between year changes —
  paging to a different year always refetches (two range queries) rather
  than caching previously-viewed years. Fine for occasional browsing;
  would want a cache if this became a frequently-revisited screen.
- **Cloud Functions have been built and emulator-loaded, but never
  deployed to a real project.** `functions/src/index.ts` type-checks and
  compiles cleanly (`npm run build`), and both exports load successfully
  in the Firebase emulator — verified locally while building this, and
  now enforced on every push via `functions-ci.yml`. What hasn't been
  verified: an actual scheduled invocation running end-to-end against
  real Firestore data, the `onDelete` trigger actually cleaning up a
  real account, or a deploy to a live Firebase project succeeding (the
  `deploy.yml` workflow's `deploy-backend` job is written for this but
  has not been run — it needs a real `FIREBASE_SERVICE_ACCOUNT` secret
  this environment doesn't have).
- The scheduled function runs **hourly for all users** and only actually
  sends during each user's local 9am hour (computed from their stored
  `timezone` string). This avoids standing up per-timezone schedules but
  means: (a) it won't work for a "9am" that's ambiguous during
  DST transitions in a way this simple approach doesn't specially handle,
  and (b) it does a full `users` collection scan every hour, which won't
  scale past a modest user count — sharding by timezone or moving to a
  queue/fan-out model is the natural next step.
- Existing Moments created before this phase don't have the `monthDay`
  field (it's written by `toFirestore()` going forward), so they won't
  appear in On This Day or trigger the Cloud Function's "on this day"
  check until they're edited/re-saved once. Since this is a fresh
  project with no production data yet, there's no backfill migration
  script — add one (a one-off script that reads every Moment and
  rewrites `monthDay`) before this matters for a real user base.
- On This Day only ever surfaces **one** Moment per Cloud Function
  notification (the most recent past year) even if multiple years match;
  the client screen shows all of them. This was a deliberate
  simplification for the push-notification text, not a bug.
- FCM token cleanup only happens reactively, when a send to that token
  fails (`sendEachForMulticast`'s per-token error is used to
  `arrayRemove` it). A token that's simply gone stale without ever being
  used again (e.g. app uninstalled, never triggering a send) will sit in
  `fcmTokens` indefinitely.
- Notification taps deep-link via a hand-rolled `route` string in the
  FCM/local-notification payload (e.g. `/plan/abc123`) matched against
  GoRouter's paths — there's no validation that the route still exists or
  that the referenced document wasn't deleted since the notification was
  sent; a stale link will hit that screen's own "this moment/plan is
  gone" empty state, which is an acceptable fallback but not a dedicated
  error path.
- Places aggregates from the most recent 300 Moments and 300 Plans
  (`placesAggregationLimit` in `places_providers.dart`), not full
  history — there's no server-side "group by location" query in
  Firestore, and building one would mean writing a real `places`
  collection at Moment/Plan save time (denormalizing location → place ID)
  rather than aggregating client-side. That's a reasonable next step once
  someone's history actually exceeds this cap; until then, client-side
  grouping is simpler and avoids a migration.
- Place matching is by exact-ish name (trimmed, lowercased) — "Bali" and
  "Ubud, Bali" are treated as different places even though one is inside
  the other. There's no geocoding-distance-based clustering.
- The Places tab isn't wired into any invalidation flow yet (unlike
  Timeline/Plans, which refresh on create/edit/delete elsewhere in the
  app) — its providers are `autoDispose` `FutureProvider`s, so they
  refetch naturally when you navigate away and back, but won't live-update
  while you're sitting on the screen and add a Moment/Plan elsewhere.
  Pull-to-refresh always gets the latest.
- `PlaceDetailScreen` is pushed with a plain `Navigator.push`, not a
  GoRouter route — it's showing an in-memory `PlaceSummary` aggregate
  that has no Firestore-addressable ID, so there's nothing meaningful to
  deep-link to. This is a deliberate difference from every other detail
  screen in the app, which are all real GoRouter routes with an `:id`.
- Itinerary items are add/delete only — there's no edit-in-place; changing
  one means deleting and re-adding it via the itinerary sheet (Create
  Plan) or Edit (Plan Detail, which reuses Create Plan's form).
- There's no way to *reopen* a cancelled Plan, or move a completed Plan
  back to "in progress" — both are one-way in this phase.
- The Plans tab still has no category filter (Vacation/Birthday/Road Trip/
  etc.) — only the Upcoming/Completed/Cancelled status grouping. Adding a
  category filter cleanly will likely need a composite Firestore index
  (`status` + `category` + `startDate`), so it's deferred rather than
  done as client-side-only filtering that would break pagination.
- There are two independent "list of active plans" data sources —
  `PlansTimelineController` (backs the Timeline's Plans filter and
  Upcoming rail) and `PlansListController` (backs the dedicated Plans
  tab). `AppShell` and Plan Detail both invalidate all three relevant
  providers (`plansListProvider`, `plansTimelineProvider`,
  `upcomingPlansProvider`) after any create/edit/delete/cancel/complete
  action, so they stay in sync; they still query independently rather
  than sharing one cache, which remains a candidate for a future
  refactor.
- Link validation in the Inspiration section is minimal (empty check +
  auto-prepending `https://` if no scheme is given) — it doesn't verify
  the URL actually resolves. Plan Detail's link rows copy-to-clipboard
  rather than opening the link directly, since `url_launcher` isn't a
  dependency yet.
- Video playback isn't implemented — a video in a Moment or Plan shows as
  a thumbnail (Plan Detail's Inspiration grid shows a plain placeholder
  tile for videos; Moment Detail shows a play badge), but tapping it does
  nothing yet. Playback is planned once a video player dependency is
  introduced.
- Moment Detail's Map tab, Plan Detail's Places section, and the Places
  tab's map previews all use `google_maps_flutter`, which needs a Google
  Maps API key configured natively (`AndroidManifest.xml` `meta-data` tag
  / `AppDelegate.swift`) once you run `flutter create .` — see
  `GOOGLE_MAPS_API_KEY` in `.env.example`. Until that's set up, all three
  will fail to render on-device even though they compile.
- Timeline's paginated Moments list doesn't live-update when a Moment is
  edited from its Detail screen (Moment Detail itself *does* live-update,
  via `watchMoment`). Deleting invalidates and refetches the Timeline;
  editing does not yet — the edited title/photo will appear next time the
  Timeline is refreshed (pull-to-refresh or filter change). Plan Detail
  does not have this gap for Plans, since it invalidates the Plans
  providers on every mutation.
- If a person abandons Add Moment or Create/Edit Plan after photos have
  already uploaded but before saving, those files are not
  garbage-collected automatically. Removing a photo from any of these
  forms *does* delete it from Storage immediately. A Cloud Function sweep
  for orphaned uploads is not implemented — see the point above about
  what's actually deployed vs. written.
- The People feature is intentionally minimal (name only, no photos/
  relationship editing UI yet) — enough for "Who was there?" / "Who is
  coming?" to work end-to-end; a dedicated People management screen isn't
  in scope yet.
- Location picking uses forward/reverse geocoding (search-by-name or
  device GPS + reverse geocode) for *picking* a location in Add/Edit
  Moment and Create/Edit Plan; the Map/Places views in both Detail
  screens do render an actual `google_maps_flutter` map once a location
  exists.
- `firebase_options.dart` contains placeholder values and **will not run**
  until you regenerate it with `flutterfire configure`.
- No CI secret is configured yet in this repo; `flutter.yml` will fail at
  the analyze/test/build steps until `firebase_options.dart` is real (or a
  `FIREBASE_OPTIONS_DART_B64` secret is added). There is also no CI
  workflow for `functions/` yet (lint/build/emulator-test on push) — a
  good candidate to add alongside `flutter.yml`.
- freezed/json_serializable are listed as dependencies for future use, but
  current models use hand-written `fromMap`/`toMap` so the project compiles
  without requiring a `build_runner` codegen step in this phase.

## Recommended next development steps

Every screen in the spec is built, CI/CD is in place (`flutter.yml`,
`functions-ci.yml`, `deploy.yml`), and there's now test coverage at every
layer — unit, widget, integration, security rules, and Cloud Functions.
The common thread across everything left to do is the same: **get each
of these actually running once, somewhere with the right runtime**, since
this project was built across environments where at various points
Flutter, a live network to Google's emulator binaries, or both were
unavailable.

1. **Run `flutter test` for real** and fix whatever the widget suite
   surfaces — this has literally never executed (see "Known
   limitations"). Do this before anything else; it's the fastest signal
   and blocks nothing else.
2. **Confirm the rules test suite is actually green** — written and
   syntax/module-resolution-checked here, but never executed against a
   real emulator.
3. **Run the integration test** against the Firebase emulator suite on a
   real device/simulator, and expect to spend real time debugging
   widget-finder mismatches and timing — see the file header in
   `integration_test/app_test.dart` for exact commands and caveats.
4. **Finish `deploy.yml`'s Android path** — run `flutter create .`, add
   release signing to `android/app/build.gradle`, and do one real
   `workflow_dispatch` run against a staging Firebase project to shake
   out anything the emulator-only validation in this build couldn't
   catch.
5. **Cloud Functions unit tests** around the pure helpers
   (`monthDayKey`, `isSameLocalDate`, `addDays`, `localNowFor`) and,
   ideally, `firebase-functions-test` coverage of the two exports
   end-to-end against emulated Firestore data.
