const { test, before, after } = require('node:test');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, getBytes } = require('firebase/storage');
const { getTestEnv } = require('./helpers');

let testEnv;

before(async () => {
  testEnv = await getTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

// Rules check size/content-type metadata, not actual image validity, so
// tiny placeholder bytes are fine here. Each test uses its own file path
// rather than clearing storage between tests, since
// @firebase/rules-unit-testing doesn't expose a Storage-clearing helper
// the way it does for Firestore.
const tinyPayload = new Uint8Array([0, 1, 2, 3]);
const imageMeta = { contentType: 'image/jpeg' };

test('owner can upload a small image to their own moment folder', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  const fileRef = ref(alice, 'users/alice/moments/m1/photo.jpg');
  await assertSucceeds(uploadBytes(fileRef, tinyPayload, imageMeta));
});

test('owner can read their own uploaded media', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), 'users/alice/moments/m1/read-check.jpg'), tinyPayload, imageMeta);
  });
  const alice = testEnv.authenticatedContext('alice').storage();
  await assertSucceeds(getBytes(ref(alice, 'users/alice/moments/m1/read-check.jpg')));
});

test("another signed-in user cannot read alice's media", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), 'users/alice/moments/m1/private.jpg'), tinyPayload, imageMeta);
  });
  const bob = testEnv.authenticatedContext('bob').storage();
  await assertFails(getBytes(ref(bob, 'users/alice/moments/m1/private.jpg')));
});

test("another signed-in user cannot upload into alice's moment folder", async () => {
  const bob = testEnv.authenticatedContext('bob').storage();
  const fileRef = ref(bob, 'users/alice/moments/m1/hijack.jpg');
  await assertFails(uploadBytes(fileRef, tinyPayload, imageMeta));
});

test('an unauthenticated request cannot upload anywhere', async () => {
  const anon = testEnv.unauthenticatedContext().storage();
  const fileRef = ref(anon, 'users/alice/moments/m1/anon.jpg');
  await assertFails(uploadBytes(fileRef, tinyPayload, imageMeta));
});

test('rejects a non-image/video content type', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  const fileRef = ref(alice, 'users/alice/moments/m1/notes.txt');
  await assertFails(uploadBytes(fileRef, tinyPayload, { contentType: 'text/plain' }));
});

test('rejects a file over the 25MB cap', async () => {
  const bigFile = new Uint8Array(26 * 1024 * 1024);
  const alice = testEnv.authenticatedContext('alice').storage();
  const fileRef = ref(alice, 'users/alice/moments/m1/huge.jpg');
  await assertFails(uploadBytes(fileRef, bigFile, imageMeta));
});

test('accepts a video content type in the plan folder', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  const fileRef = ref(alice, 'users/alice/plans/p1/clip.mp4');
  await assertSucceeds(uploadBytes(fileRef, tinyPayload, { contentType: 'video/mp4' }));
});

test('owner can upload their own profile photo', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  const fileRef = ref(alice, 'users/alice/profile/avatar.jpg');
  await assertSucceeds(uploadBytes(fileRef, tinyPayload, imageMeta));
});

test("another user cannot write to alice's profile photo path", async () => {
  const bob = testEnv.authenticatedContext('bob').storage();
  const fileRef = ref(bob, 'users/alice/profile/avatar.jpg');
  await assertFails(uploadBytes(fileRef, tinyPayload, imageMeta));
});

test('an entirely unmatched path is denied by the default-deny rule', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  const fileRef = ref(alice, 'some/other/path/file.jpg');
  await assertFails(uploadBytes(fileRef, tinyPayload, imageMeta));
});
