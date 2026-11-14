#!/usr/bin/env node

/**
 * NeoQuest Database Setup Script
 * Erstellt Datenbank, Benutzer und führt Migrationen aus
 */

const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

// Zugangsdaten kommen ausschliesslich aus der lokalen .env (nicht im Repo)
function loadEnv(file) {
  if (!fs.existsSync(file)) {
    console.error(`❌ ${file} fehlt. Kopiere .env.example nach .env und trage die Zugangsdaten ein.`);
    process.exit(1);
  }
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
  }
}
loadEnv(path.join(__dirname, '..', '.env'));

function required(name) {
  const v = process.env[name];
  if (!v || v === 'CHANGE_ME') {
    console.error(`❌ ${name} ist in .env nicht gesetzt.`);
    process.exit(1);
  }
  return v;
}

const config = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  database: required('DB_NAME'),
  schema: process.env.DB_SCHEMA || 'neoquest',
  adminUser: required('DB_ADMIN_USER'),
  adminPassword: required('DB_ADMIN_PASSWORD'),
};

async function setupDatabase() {
  console.log('🚀 NeoQuest Database Setup gestartet...');
  
  // Verbindung als Superuser (für DB-Erstellung)
  const superClient = new Client({
    host: config.host,
    port: config.port,
    user: config.adminUser,
    password: config.adminPassword,
    database: 'postgres' // Standard-DB für Admin-Operationen
  });

  try {
    await superClient.connect();
    console.log('✅ Verbindung zu PostgreSQL hergestellt');

    // 1. Datenbank erstellen (falls nicht vorhanden)
    try {
      await superClient.query(`CREATE DATABASE ${config.database}`);
      console.log(`✅ Datenbank '${config.database}' erstellt`);
    } catch (error) {
      if (error.code === '42P04') { // Database already exists
        console.log(`ℹ️  Datenbank '${config.database}' existiert bereits`);
      } else {
        throw error;
      }
    }

    // 2. App-spezifischen Benutzer erstellen (optional)
    const appUser = process.env.DB_USER || 'neoquest_app';
    const appPassword = required('DB_PASSWORD');
    
    try {
      await superClient.query(`CREATE USER ${appUser} WITH PASSWORD '${appPassword}'`);
      console.log(`✅ Benutzer '${appUser}' erstellt`);
    } catch (error) {
      if (error.code === '42710') { // Role already exists
        console.log(`ℹ️  Benutzer '${appUser}' existiert bereits`);
      } else {
        throw error;
      }
    }

    await superClient.end();

    // 3. Verbindung zur App-Datenbank für Schema-Setup
    const appClient = new Client({
      host: config.host,
      port: config.port,
      user: config.adminUser,
      password: config.adminPassword,
      database: config.database
    });

    await appClient.connect();
    console.log(`✅ Verbindung zu Datenbank '${config.database}' hergestellt`);

    // 4. Schema erstellen
    await appClient.query(`CREATE SCHEMA IF NOT EXISTS ${config.schema}`);
    console.log(`✅ Schema '${config.schema}' vorhanden`);

    await appClient.end();

    console.log('\n🎉 Database Setup abgeschlossen!');
    console.log('\n📋 Nächste Schritte:');
    console.log('   npm run migrate:up    # Führt alle Migrationen aus');
    console.log('   npm run db:grant      # Setzt die Rechte für den App-User');
    
    console.log('\n🔐 Datenbankzugang:');
    console.log(`   Database: ${config.database}`);
    console.log(`   Schema: ${config.schema}`);
    console.log(`   App User: ${appUser}`);
    console.log('   App Password: (siehe lokale .env)');

  } catch (error) {
    console.error('❌ Fehler beim Database Setup:', error.message);
    process.exit(1);
  }
}


// Rechte fuer den App-User: nur Daten lesen/schreiben, keine Struktur aendern.
// Nach jeder Migration ausfuehren (npm run db:grant).
async function grantAppPrivileges() {
  const appUser = process.env.DB_USER || 'neoquest_app';
  if (appUser === config.adminUser) {
    console.error('❌ DB_USER darf nicht der Admin-User sein.');
    process.exit(1);
  }
  const s = config.schema;
  const client = new Client({
    host: config.host, port: config.port, database: config.database,
    user: config.adminUser, password: config.adminPassword,
  });
  await client.connect();
  try {
    const statements = [
      `GRANT CONNECT ON DATABASE ${config.database} TO ${appUser}`,
      `REVOKE CREATE ON SCHEMA ${s} FROM PUBLIC`,
      `REVOKE CREATE ON SCHEMA public FROM PUBLIC`,
      `GRANT USAGE ON SCHEMA ${s} TO ${appUser}`,
      `GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${s} TO ${appUser}`,
      `GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA ${s} TO ${appUser}`,
      `GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${s} TO ${appUser}`,
      `ALTER DEFAULT PRIVILEGES FOR ROLE ${config.adminUser} IN SCHEMA ${s} GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${appUser}`,
      `ALTER DEFAULT PRIVILEGES FOR ROLE ${config.adminUser} IN SCHEMA ${s} GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO ${appUser}`,
      `ALTER DEFAULT PRIVILEGES FOR ROLE ${config.adminUser} IN SCHEMA ${s} GRANT EXECUTE ON FUNCTIONS TO ${appUser}`,
    ];
    for (const sql of statements) await client.query(sql);
    const { rows } = await client.query(
      `SELECT count(*)::int AS n FROM information_schema.role_table_grants
       WHERE grantee = $1 AND table_schema = $2 AND privilege_type = 'SELECT'`, [appUser, s]);
    console.log(`✅ Rechte für '${appUser}' gesetzt (${rows[0].n} Tabellen/Views lesbar, keine DDL-Rechte)`);
  } finally {
    await client.end();
  }
}

// Hilfsfunktion: Migration-Status anzeigen
async function showMigrationStatus() {
  const { exec } = require('child_process');
  
  return new Promise((resolve, reject) => {
    exec('npm run migrate:status', (error, stdout, stderr) => {
      if (error) {
        console.log('ℹ️  Noch keine Migrationen ausgeführt');
        resolve();
        return;
      }
      console.log('\n📊 Migration Status:');
      console.log(stdout);
      resolve();
    });
  });
}

// CLI Interface
if (require.main === module) {
  const command = process.argv[2];
  
  switch (command) {
    case 'status':
      showMigrationStatus();
      break;
    case 'grant':
      grantAppPrivileges().catch((e) => { console.error('❌ Fehler beim Setzen der Rechte:', e.message); process.exit(1); });
      break;
    case 'setup':
    default:
      setupDatabase().then(() => {
        return showMigrationStatus();
      });
      break;
  }
}

module.exports = { setupDatabase, grantAppPrivileges, showMigrationStatus };