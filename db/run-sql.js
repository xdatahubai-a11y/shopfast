#!/usr/bin/env node
// Usage: node run-sql.js <server> <database> <user> <password> <file.sql>
const sql = require('mssql');
const fs = require('fs');

const [,, server, database, user, password, file] = process.argv;
if (!file) { console.error('Usage: node run-sql.js <server> <db> <user> <pass> <file.sql>'); process.exit(1); }

(async () => {
  const pool = await sql.connect({
    server, database, user, password,
    options: { encrypt: true, trustServerCertificate: false },
    requestTimeout: 60000
  });
  const content = fs.readFileSync(file, 'utf8');
  // Split on GO statements and execute each batch
  const batches = content.split(/^\s*GO\s*$/mi).filter(b => b.trim());
  for (const batch of batches.length > 1 ? batches : [content]) {
    if (!batch.trim()) continue;
    await pool.request().query(batch);
  }
  console.log(`✓ Applied ${file}`);
  await pool.close();
})().catch(err => { console.error(`✗ ${err.message}`); process.exit(1); });
