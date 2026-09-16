const { test, before, after, beforeEach } = require('node:test');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { getTestEnv } = require('./helpers');

let testEnv;

before(async () => {
  testEnv = await getTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Every one of these subcollections shares the same isOwner(userId)-gated
// rule shape in firestore.rules (see the repeated
// `match /{collection}/{docId} { allow read, create, update, delete: if
// isOwner(userId); }` blocks under `match /users/{userId}`). Testing them
// in one parameterized suite means all five stay in sync automatically —
// five near-identical copy-pasted test files would drift the moment
// someone updates the rule for only one of them.
const OWNED_SUBCOLLECTIONS = ['moments', 'plans', 'people', 'places', 'settings'];

for (const collection of OWNED_SUBCOLLECTIONS) {
  test(`${collection}: owner can create, read, update, and delete their own document`, async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    const docRef = alice.doc(`users/alice/${collection}/doc1`);

    await assertSucceeds(docRef.set({ value: 'a' }));
    await assertSucceeds(docRef.get());
    await assertSucceeds(docRef.update({ value: 'b' }));
    await assertSucceeds(docRef.delete());
  });

  test(`${collection}: another signed-in user cannot read it`, async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`users/alice/${collection}/doc1`).set({ value: 'a' });
    });
    const bob = testEnv.authenticatedContext('bob').firestore();
    await assertFails(bob.doc(`users/alice/${collection}/doc1`).get());
  });

  test(`${collection}: another signed-in user cannot create a document under alice's uid`, async () => {
    const bob = testEnv.authenticatedContext('bob').firestore();
    await assertFails(bob.doc(`users/alice/${collection}/hijack`).set({ value: 'x' }));
  });

  test(`${collection}: another signed-in user cannot update alice's document`, async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`users/alice/${collection}/doc1`).set({ value: 'a' });
    });
    const bob = testEnv.authenticatedContext('bob').firestore();
    await assertFails(bob.doc(`users/alice/${collection}/doc1`).update({ value: 'hijacked' }));
  });

  test(`${collection}: another signed-in user cannot delete alice's document`, async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`users/alice/${collection}/doc1`).set({ value: 'a' });
    });
    const bob = testEnv.authenticatedContext('bob').firestore();
    await assertFails(bob.doc(`users/alice/${collection}/doc1`).delete());
  });

  test(`${collection}: an unauthenticated request is denied entirely`, async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`users/alice/${collection}/doc1`).set({ value: 'a' });
    });
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(anon.doc(`users/alice/${collection}/doc1`).get());
    await assertFails(anon.doc(`users/alice/${collection}/doc2`).set({ value: 'x' }));
  });
}
