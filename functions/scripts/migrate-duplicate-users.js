#!/usr/bin/env node
/* eslint-disable no-console */

/**
 * Merge duplicate Firestore user docs by normalized email.
 *
 * Usage:
 *   node scripts/migrate-duplicate-users.js
 *   node scripts/migrate-duplicate-users.js --apply
 *   node scripts/migrate-duplicate-users.js --apply --delete-duplicates
 *
 * Optional env vars:
 *   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/service-account.json
 *   DRY_RUN=true|false (overridden by --apply)
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const apply = args.has('--apply');
const deleteDuplicates = args.has('--delete-duplicates');
const dryRun = !apply;

function getArgValue(flag) {
  for (let i = 0; i < rawArgs.length; i += 1) {
    const arg = rawArgs[i];
    if (arg === flag && i + 1 < rawArgs.length) {
      return rawArgs[i + 1];
    }
    if (arg.startsWith(`${flag}=`)) {
      return arg.slice(flag.length + 1);
    }
  }
  return null;
}

function findProjectIdFromFirebaserc() {
  // Try current directory and parents to support running from / or /functions.
  let current = process.cwd();
  for (let i = 0; i < 4; i += 1) {
    const candidate = path.join(current, '.firebaserc');
    if (fs.existsSync(candidate)) {
      try {
        const json = JSON.parse(fs.readFileSync(candidate, 'utf8'));
        const projectId = json && json.projects && json.projects.default;
        if (projectId && typeof projectId === 'string') {
          return projectId;
        }
      } catch (e) {
        // Ignore parse errors and continue searching.
      }
    }

    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return null;
}

const resolvedProjectId =
  getArgValue('--project') ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  findProjectIdFromFirebaserc();

if (!admin.apps.length) {
  const initConfig = {};
  if (resolvedProjectId) {
    initConfig.projectId = resolvedProjectId;
  }
  admin.initializeApp(initConfig);
}

const db = admin.firestore();

function toIsoString(value) {
  if (!value) return null;
  if (typeof value === 'string') return value;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return null;
}

function parseDateForSort(value) {
  const iso = toIsoString(value);
  if (!iso) return 0;
  const ts = Date.parse(iso);
  return Number.isFinite(ts) ? ts : 0;
}

function normalizeEmail(email) {
  if (!email || typeof email !== 'string') return null;
  const trimmed = email.trim().toLowerCase();
  return trimmed || null;
}

function isMeaningful(value) {
  if (value === null || value === undefined) return false;
  if (typeof value === 'string') return value.trim().length > 0;
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === 'object') return Object.keys(value).length > 0;
  return true;
}

function mergeUniqueObjects(arr, keyFn) {
  const map = new Map();
  for (const item of arr) {
    if (!item || typeof item !== 'object') continue;
    const key = keyFn(item);
    if (!key) continue;
    if (!map.has(key)) {
      map.set(key, item);
      continue;
    }

    // Prefer object with richer data while preserving existing values.
    const existing = map.get(key);
    const merged = { ...existing };
    for (const [field, value] of Object.entries(item)) {
      if (!isMeaningful(merged[field]) && isMeaningful(value)) {
        merged[field] = value;
      }
    }
    map.set(key, merged);
  }
  return Array.from(map.values());
}

function dedupePrimitiveArray(values) {
  return Array.from(new Set(values.filter((v) => isMeaningful(v))));
}

function chooseCanonical(docs) {
  const ranked = [...docs].sort((a, b) => {
    const aData = a.data;
    const bData = b.data;

    const aVerified = aData.emailVerified === true ? 1 : 0;
    const bVerified = bData.emailVerified === true ? 1 : 0;
    if (aVerified !== bVerified) return bVerified - aVerified;

    const aNonAnonymous = aData.isAnonymous === true ? 0 : 1;
    const bNonAnonymous = bData.isAnonymous === true ? 0 : 1;
    if (aNonAnonymous !== bNonAnonymous) return bNonAnonymous - aNonAnonymous;

    const aUpdated = parseDateForSort(aData.updatedAt || aData.lastLoginAt || aData.createdAt);
    const bUpdated = parseDateForSort(bData.updatedAt || bData.lastLoginAt || bData.createdAt);
    if (aUpdated !== bUpdated) return bUpdated - aUpdated;

    const aCreated = parseDateForSort(aData.createdAt);
    const bCreated = parseDateForSort(bData.createdAt);
    if (aCreated !== bCreated) return aCreated - bCreated;

    return a.id.localeCompare(b.id);
  });

  return ranked[0];
}

function mergeUserDocs(canonical, duplicates) {
  const all = [canonical, ...duplicates];
  const merged = { ...canonical.data };

  const firstMeaningful = (selector) => {
    for (const entry of all) {
      const value = selector(entry.data);
      if (isMeaningful(value)) return value;
    }
    return undefined;
  };

  merged.uid = canonical.id;
  merged.email = normalizeEmail(canonical.data.email || firstMeaningful((d) => d.email)) || canonical.data.email;
  merged.emailVerified = all.some((d) => d.data.emailVerified === true);

  const scalarFields = [
    'displayName',
    'name',
    'phoneNumber',
    'photoURL',
    'gender',
    'city',
    'address',
    'providerId',
    'provider',
    'role',
  ];

  for (const field of scalarFields) {
    if (!isMeaningful(merged[field])) {
      const value = firstMeaningful((d) => d[field]);
      if (isMeaningful(value)) merged[field] = value;
    }
  }

  merged.createdAt = firstMeaningful((d) => d.createdAt) || merged.createdAt;
  merged.lastLoginAt = firstMeaningful((d) => d.lastLoginAt) || merged.lastLoginAt;
  merged.updatedAt = admin.firestore.FieldValue.serverTimestamp();

  const favoriteSalonIds = dedupePrimitiveArray(
    all.flatMap((d) => Array.isArray(d.data.favoriteSalonIds) ? d.data.favoriteSalonIds : [])
  );
  if (favoriteSalonIds.length > 0) merged.favoriteSalonIds = favoriteSalonIds;

  const cards = mergeUniqueObjects(
    all.flatMap((d) => Array.isArray(d.data.savedCards) ? d.data.savedCards : []),
    (card) => [card.id, card.last4, card.brand, card.expiryMonth, card.expiryYear].filter(Boolean).join('|')
  );
  if (cards.length > 0) merged.savedCards = cards;

  const duplicateUids = duplicates.map((d) => d.id).sort();
  merged.mergedDuplicateUids = dedupePrimitiveArray([
    ...(Array.isArray(canonical.data.mergedDuplicateUids) ? canonical.data.mergedDuplicateUids : []),
    ...duplicateUids,
  ]);

  return merged;
}

async function readUserDocs() {
  const snapshot = await db.collection('users').get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ref: doc.ref, data: doc.data() || {} }));
}

function groupDuplicatesByEmail(userDocs) {
  const groups = new Map();
  for (const doc of userDocs) {
    const normalized = normalizeEmail(doc.data.email);
    if (!normalized) continue;
    const list = groups.get(normalized) || [];
    list.push(doc);
    groups.set(normalized, list);
  }

  return Array.from(groups.entries())
    .map(([email, docs]) => ({ email, docs }))
    .filter((entry) => entry.docs.length > 1);
}

async function applyMigration(operations) {
  let writes = 0;
  let deletes = 0;

  for (const op of operations) {
    await db.collection('users').doc(op.canonicalId).set(op.mergedData, { merge: true });
    writes += 1;

    if (deleteDuplicates) {
      for (const duplicateId of op.duplicateIds) {
        await db.collection('users').doc(duplicateId).delete();
        deletes += 1;
      }
    }
  }

  return { writes, deletes };
}

function printPlan(operations) {
  console.log('');
  console.log('Duplicate user migration plan');
  console.log('============================');
  console.log(`Duplicate email groups: ${operations.length}`);

  for (const op of operations) {
    console.log('');
    console.log(`Email: ${op.email}`);
    console.log(`Canonical: ${op.canonicalId}`);
    console.log(`Duplicates: ${op.duplicateIds.join(', ')}`);
  }

  console.log('');
  if (dryRun) {
    console.log('DRY RUN: no writes were made.');
    console.log('Run with --apply to write merged canonical docs.');
    console.log('Add --delete-duplicates to also remove duplicate docs after merge.');
  } else {
    console.log('APPLY MODE: merged docs will be written.');
    if (deleteDuplicates) {
      console.log('Duplicate docs will also be deleted.');
    } else {
      console.log('Duplicate docs will be kept (safe mode).');
    }
  }
}

async function main() {
  if (deleteDuplicates && dryRun) {
    throw new Error('Cannot use --delete-duplicates without --apply.');
  }

  const docs = await readUserDocs();
  const duplicateGroups = groupDuplicatesByEmail(docs);

  if (duplicateGroups.length === 0) {
    console.log('No duplicate user docs found by email.');
    return;
  }

  const operations = duplicateGroups.map((group) => {
    const canonical = chooseCanonical(group.docs);
    const duplicates = group.docs.filter((d) => d.id !== canonical.id);
    const mergedData = mergeUserDocs(canonical, duplicates);

    return {
      email: group.email,
      canonicalId: canonical.id,
      duplicateIds: duplicates.map((d) => d.id),
      mergedData,
    };
  });

  printPlan(operations);

  if (dryRun) {
    return;
  }

  const result = await applyMigration(operations);
  console.log('');
  console.log('Migration completed.');
  console.log(`Canonical docs updated: ${result.writes}`);
  console.log(`Duplicate docs deleted: ${result.deletes}`);
}

main().catch((error) => {
  console.error('Migration failed:', error.message || error);
  const message = String(error && error.message ? error.message : error || '');
  if (message.includes('default credentials')) {
    console.error('');
    console.error('Authentication required for Firebase Admin SDK. Use one of these options:');
    console.error('1) Set a service account key path:');
    console.error('   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\\path\\to\\service-account.json"');
    console.error('2) Or authenticate ADC with gcloud:');
    console.error('   gcloud auth application-default login');
    console.error('Then re-run: node scripts/migrate-duplicate-users.js');
  }
  process.exitCode = 1;
});
