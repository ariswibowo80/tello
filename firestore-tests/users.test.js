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

test('a user can create their own profile document at their own uid', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('users/alice').set({ displayName: 'Alice' }));
});

test("a user cannot create a profile document under someone else's uid", async () => {
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(bob.doc('users/alice').set({ displayName: 'Fake Alice' }));
});

test('a user can read and update their own profile', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/alice').set({ displayName: 'Alice' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('users/alice').get());
  await assertSucceeds(alice.doc('users/alice').update({ displayName: 'Alice S.' }));
});

test("another signed-in user cannot read or update alice's profile", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/alice').set({ displayName: 'Alice' });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(bob.doc('users/alice').get());
  await assertFails(bob.doc('users/alice').update({ displayName: 'Hijacked' }));
});

test('no one can delete a user profile document directly — even the owner', async () => {
  // Account deletion is routed through the onUserDeleted Cloud Function
  // (see functions/src/index.ts) specifically because a client-side
  // recursive delete of every subcollection is unsafe/incomplete. This
  // is the rule that makes that routing mandatory rather than optional.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/alice').set({ displayName: 'Alice' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(alice.doc('users/alice').delete());
});

test('an unauthenticated request cannot read any profile', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/alice').set({ displayName: 'Alice' });
  });
  const anon = testEnv.unauthenticatedContext().firestore();
  await assertFails(anon.doc('users/alice').get());
});

test('a completely unmatched top-level path is denied by the default-deny rule', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(alice.doc('somethingElse/doc1').set({ value: 'x' }));
});
