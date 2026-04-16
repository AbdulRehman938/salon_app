import { readFile } from 'node:fs/promises';
import path from 'node:path';

const projectId = process.env.FIREBASE_PROJECT_ID || 'salonapp-3ba4c';
const apiKey = process.env.FIREBASE_WEB_API_KEY;
const datasetPath = process.argv[2] || path.resolve(process.cwd(), 'dataset.json');

function fromFirestoreValue(value) {
  if (!value || typeof value !== 'object') {
    return null;
  }

  if ('nullValue' in value) {
    return null;
  }
  if ('stringValue' in value) {
    return value.stringValue;
  }
  if ('booleanValue' in value) {
    return value.booleanValue;
  }
  if ('integerValue' in value) {
    return Number(value.integerValue);
  }
  if ('doubleValue' in value) {
    return Number(value.doubleValue);
  }
  if ('timestampValue' in value) {
    return value.timestampValue;
  }
  if ('arrayValue' in value) {
    const values = value.arrayValue?.values || [];
    return values.map((item) => fromFirestoreValue(item));
  }
  if ('mapValue' in value) {
    const fields = value.mapValue?.fields || {};
    const out = {};
    for (const [k, v] of Object.entries(fields)) {
      out[k] = fromFirestoreValue(v);
    }
    return out;
  }

  return null;
}

function flattenPaths(value, prefix = '', acc = new Set()) {
  const isObj = value !== null && typeof value === 'object' && !Array.isArray(value);
  const isArr = Array.isArray(value);

  if (!isObj && !isArr) {
    if (prefix) {
      acc.add(prefix);
    }
    return acc;
  }

  if (isArr) {
    if (prefix) {
      acc.add(prefix);
    }

    for (const item of value) {
      const itemIsObj = item !== null && typeof item === 'object';
      if (!itemIsObj) {
        continue;
      }

      const childPrefix = prefix ? `${prefix}[]` : '[]';
      flattenPaths(item, childPrefix, acc);
    }
    return acc;
  }

  if (prefix) {
    acc.add(prefix);
  }

  for (const [key, child] of Object.entries(value)) {
    const childPrefix = prefix ? `${prefix}.${key}` : key;
    flattenPaths(child, childPrefix, acc);
  }

  return acc;
}

function diffSets(expected, actual) {
  const missing = [];
  const extra = [];

  for (const item of expected) {
    if (!actual.has(item)) {
      missing.push(item);
    }
  }

  for (const item of actual) {
    if (!expected.has(item)) {
      extra.push(item);
    }
  }

  missing.sort();
  extra.sort();
  return { missing, extra };
}

async function fetchAllSalonDocs() {
  const docs = [];
  let pageToken = '';

  while (true) {
    const qs = new URLSearchParams({ key: apiKey, pageSize: '200' });
    if (pageToken) {
      qs.set('pageToken', pageToken);
    }

    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/salons?${qs.toString()}`;
    const response = await fetch(url);
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Failed to fetch Firestore salons: ${response.status} ${response.statusText} - ${text}`);
    }

    const json = await response.json();
    const documents = json.documents || [];
    docs.push(...documents);

    pageToken = json.nextPageToken || '';
    if (!pageToken) {
      break;
    }
  }

  return docs;
}

function docIdFromName(name = '') {
  const parts = name.split('/');
  return parts[parts.length - 1] || '';
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

  const datasetById = new Map();
  for (const salon of parsed.salons) {
    const id = (salon?.id ?? '').toString().trim();
    if (!id) {
      throw new Error('Found salon without id in dataset.json');
    }
    datasetById.set(id, salon);
  }

  const firestoreDocs = await fetchAllSalonDocs();
  const firestoreById = new Map();
  for (const doc of firestoreDocs) {
    const id = docIdFromName(doc.name);
    const jsDoc = {};
    const fields = doc.fields || {};
    for (const [k, v] of Object.entries(fields)) {
      jsDoc[k] = fromFirestoreValue(v);
    }
    firestoreById.set(id, jsDoc);
  }

  const missingDocs = [];
  const extraDocs = [];
  const keyMismatches = [];

  for (const id of datasetById.keys()) {
    if (!firestoreById.has(id)) {
      missingDocs.push(id);
    }
  }

  for (const id of firestoreById.keys()) {
    if (!datasetById.has(id)) {
      extraDocs.push(id);
    }
  }

  for (const [id, datasetDoc] of datasetById.entries()) {
    const firestoreDoc = firestoreById.get(id);
    if (!firestoreDoc) {
      continue;
    }

    const expectedPaths = flattenPaths(datasetDoc);
    const actualPaths = flattenPaths(firestoreDoc);
    const { missing, extra } = diffSets(expectedPaths, actualPaths);

    if (missing.length || extra.length) {
      keyMismatches.push({ id, missing, extra });
    }
  }

  missingDocs.sort();
  extraDocs.sort();
  keyMismatches.sort((a, b) => a.id.localeCompare(b.id));

  const report = {
    projectId,
    datasetSalonCount: datasetById.size,
    firestoreSalonCount: firestoreById.size,
    missingDocs,
    extraDocs,
    keyMismatches,
  };

  console.log(JSON.stringify(report, null, 2));

  const hasErrors = missingDocs.length > 0 || keyMismatches.length > 0;
  process.exit(hasErrors ? 2 : 0);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
