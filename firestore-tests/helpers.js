const { readFileSync } = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'demo-tello-rules-test';

/**
 * Connects to the Firestore/Storage emulators (already running — this
 * package is meant to be invoked via
 * `firebase emulators:exec --only firestore,storage "npm test"`, not run
 * standalone) and loads the real rules files from the repo root.
 */
async function getTestEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
}

module.exports = { getTestEnv, PROJECT_ID };
