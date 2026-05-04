// This script removes the city name from the salon name if present, for all salons in dataset.json
// Usage: node scripts/remove-city-from-salon-names.js

const fs = require('fs');
const path = require('path');

const datasetPath = path.resolve(process.cwd(), 'dataset.json');

if (!fs.existsSync(datasetPath)) {
  console.error('dataset.json not found:', datasetPath);
  process.exit(1);
}

const raw = fs.readFileSync(datasetPath, 'utf8');
const parsed = JSON.parse(raw);
if (!parsed || !Array.isArray(parsed.salons)) {
  throw new Error('dataset.json must contain a top-level "salons" array.');
}

let changed = 0;
for (const salon of parsed.salons) {
  if (!salon.name || !salon.city) continue;
  // Remove city name from the end of the salon name (with or without comma)
  const city = salon.city.trim();
  const regex = new RegExp(`([,\s]+${city})$`, 'i');
  if (regex.test(salon.name)) {
    salon.name = salon.name.replace(regex, '').trim();
    changed++;
  }
}

if (changed > 0) {
  fs.writeFileSync(datasetPath, JSON.stringify(parsed, null, 2));
  console.log(`Updated ${changed} salon names in dataset.json.`);
} else {
  console.log('No salon names needed updating.');
}
