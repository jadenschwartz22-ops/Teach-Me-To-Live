// migrate-createdAt.js
const admin = require("firebase-admin");

// Load your service account key
admin.initializeApp({
  credential: admin.credential.cert(require("./service-account.json"))
});

const db = admin.firestore();

async function migrate() {
  console.log("🔄 Starting createdAt migration…");
  const batchSize = 500;
  let lastDoc = null;

  while (true) {
    let query = db.collection("wisdom")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) {
      console.log("✅ No more documents. Migration complete.");
      break;
    }

    const batch = db.batch();
    snap.docs.forEach(doc => {
      const data = doc.data();
      if (!data.createdAt && typeof data.timestamp === "number") {
        const legacySec = data.timestamp;
        batch.update(doc.ref, {
          createdAt: admin.firestore.Timestamp.fromMillis(legacySec * 1000)
        });
      }
    });

    await batch.commit();
    lastDoc = snap.docs[snap.docs.length - 1];
    console.log(`  ↳ Processed ${snap.size} documents`);
  }
}

migrate().catch(err => {
  console.error("Migration failed:", err);
  process.exit(1);
});

