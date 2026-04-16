#!/usr/bin/env node

// Root wrapper so the migration can be run from the repo root:
// node scripts/migrate-duplicate-users.js [--apply] [--delete-duplicates]
require('../functions/scripts/migrate-duplicate-users.js');
