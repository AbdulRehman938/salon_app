// Bulk import salons from dataset.json to Firestore using Firebase Admin SDK
// Usage: node scripts/import-salons-admin.js [dataset.json]

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Path to your service account key JSON file (download from Firebase Console > Project Settings > Service Accounts)
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT || path.resolve(process.cwd(), 'serviceAccountKey.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('Service account key file not found:', serviceAccountPath);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});

const db = admin.firestore();

const datasetPath = process.argv[2] || path.resolve(process.cwd(), 'dataset.json');
if (!fs.existsSync(datasetPath)) {
  console.error('dataset.json not found:', datasetPath);
  process.exit(1);
}

async function main() {
  const raw = fs.readFileSync(datasetPath, 'utf8');
  const parsed = JSON.parse(raw);
  if (!parsed || !Array.isArray(parsed.salons)) {
    throw new Error('dataset.json must contain a top-level "salons" array.');
  }
  const salons = parsed.salons;
  console.log(`Importing ${salons.length} salons from ${datasetPath}...`);
  let success = 0, failed = 0;
  for (let i = 0; i < salons.length; i++) {
    const salon = salons[i];
    const id = (salon.id || '').toString().trim();
    if (!id) {
      console.warn(`Skipping salon at index ${i} (missing id)`);
      failed++;
      continue;
    }
    try {
      await db.collection('salons').doc(id).set(salon, { merge: true });
      success++;
      if ((success + failed) % 10 === 0 || i + 1 === salons.length) {
        console.log(`Imported ${success + failed}/${salons.length}`);
      }
    } catch (err) {
      console.error(`Failed to import salon ${id}:`, err.message);
      failed++;
    }
  }
  console.log(`Done. Success: ${success}, Failed: ${failed}`);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
