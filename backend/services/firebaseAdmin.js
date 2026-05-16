const fs = require("fs");
const admin = require("firebase-admin");

function loadServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }

  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    return JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));
  }

  if (
    process.env.FIREBASE_PROJECT_ID &&
    process.env.FIREBASE_CLIENT_EMAIL &&
    process.env.FIREBASE_PRIVATE_KEY
  ) {
    return {
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
    };
  }

  return null;
}

function initFirebaseAdmin() {
  if (admin.apps.length > 0) {
    return admin;
  }

  const serviceAccount = loadServiceAccount();
  if (!serviceAccount) {
    console.warn('[firebaseAdmin] No service account found — Firebase admin not initialized');
    return null;
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  console.log('[firebaseAdmin] Initialized with service account for project:', serviceAccount.projectId || 'unknown');
  return admin;
}

async function sendPushNotification(tokens, payload) {
  const firebaseAdmin = initFirebaseAdmin();

  if (!firebaseAdmin || !tokens || tokens.length === 0) {
    return { sent: false };
  }

  const message = {
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: Object.fromEntries(
      Object.entries(payload.data || {}).map(([key, value]) => [key, String(value)])
    ),
  };

  // Use sendMulticast which accepts {tokens, notification, data}
  const response = await firebaseAdmin.messaging().sendEachForMulticast(message);
  return { sent: true, response };
}

module.exports = {
  initFirebaseAdmin,
  sendPushNotification,
};