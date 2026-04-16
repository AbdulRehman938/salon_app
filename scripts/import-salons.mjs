import { readFile } from 'node:fs/promises';
import path from 'node:path';

const projectId = process.env.FIREBASE_PROJECT_ID || 'salonapp-3ba4c';
const apiKey = process.env.FIREBASE_WEB_API_KEY;
const datasetPath = process.argv[2] || path.resolve(process.cwd(), 'dataset.json');

function toFirestoreValue(value) {
  if (value === null) {
    return { nullValue: null };
  }

  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((item) => toFirestoreValue(item)),
      },
    };
  }

  const type = typeof value;

  if (type === 'string') {
    return { stringValue: value };
  }

  if (type === 'boolean') {
    return { booleanValue: value };
  }

  if (type === 'number') {
    if (Number.isInteger(value)) {
      return { integerValue: value.toString() };
    }
    return { doubleValue: value };
  }

  if (type === 'object') {
    const fields = {};
    for (const [key, nested] of Object.entries(value)) {
      if (nested === undefined) {
        continue;
      }
      fields[key] = toFirestoreValue(nested);
    }
    return { mapValue: { fields } };
  }

  return { stringValue: String(value) };
}

function toFirestoreFields(doc) {
  const fields = {};
  for (const [key, value] of Object.entries(doc)) {
    if (value === undefined) {
      continue;
    }
    fields[key] = toFirestoreValue(value);
  }
  return fields;
}

async function upsertSalonDoc(salon) {
  const id = (salon.id ?? '').toString().trim();
  if (!id) {
    throw new Error('Encountered salon record without a valid id.');
  }

  const endpoint = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/salons/${encodeURIComponent(id)}?key=${apiKey}`;
  const response = await fetch(endpoint, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(salon) }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to upsert salon ${id}: ${response.status} ${response.statusText} - ${text}`);
  }
}

async function main() {
  if (!apiKey) {
    throw new Error('FIREBASE_WEB_API_KEY is missing. Set it in your environment before running this script.');
  }

  const raw = await readFile(datasetPath, 'utf8');
  const parsed = JSON.parse(raw);

  if (!parsed || !Array.isArray(parsed.salons)) {
    throw new Error('dataset.json must contain a top-level "salons" array.');
  }

  const salons = parsed.salons;
  console.log(`Importing ${salons.length} salons from ${datasetPath} into project ${projectId}...`);

  for (let i = 0; i < salons.length; i += 1) {
    await upsertSalonDoc(salons[i]);
    if ((i + 1) % 10 === 0 || i + 1 === salons.length) {
      console.log(`Imported ${i + 1}/${salons.length}`);
    }
  }

  console.log('Salon dataset import completed successfully.');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
