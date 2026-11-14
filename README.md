# neoquest
Repository for a geo tracking game

# NeoQuest Server - Schatzsuche App Backend

PostgreSQL-basierte Serverkomponente für eine Flutter-Schatzsuche-App mit Geotracking, entwickelt für lokale LAN-Umgebungen.

## 🚀 Quick Start

### 1. Voraussetzungen

- **Node.js** >= 16.x
- **PostgreSQL** >= 12.x  
- **npm** oder **yarn**

### 2. Installation

```bash
# Repository klonen
git clone <repository-url>
cd neoquest-server

# Dependencies installieren
npm install

# Environment-Datei erstellen
cp .env.example .env
# .env bearbeiten und Datenbankzugangsdaten anpassen
```

### 3. Datenbank Setup

```bash
# Automatisches Setup (erstellt DB, Schema, User)
npm run setup:db

# Migrationen ausführen
npm run migrate:up

# Migration Status prüfen
npm run migrate:status
```

### 4. Server starten

```bash
# Development
npm run dev

# Production
npm start
```

## 📁 Projektstruktur

```
neoquest-server/
├── migrations/                 # db-migrate Dateien
│   ├── 20240627000001-init-neoquest-schema.js
│   ├── 20240627000002-add-indexes.js
│   └── 20240627000003-seed-data.js
├── scripts/                   # Setup & Utility Scripts
│   └── setup-database.js
├── database.json             # db-migrate Konfiguration
├── .env.template             # Environment Template
└── package.json
```

## 🗄️ Datenbankschema

### Haupt-Tabellen

- **`players`** - Spieler:innen mit QR-Tokens
- **`games`** - Spielszenarien/Schatzsuchen
- **`checkpoints`** - GPS-Punkte mit QR-Codes
- **`puzzles`** - Rätsel mit Antworten
- **`gps_tracks`** - GPS-Verlauf der Spieler:innen
- **`upload_queue`** - Warteschlange für Uploads

### Beispiel-Spiel: Möllersdorf Schatzsuche

**Zentrum:** Münchendorferstrasse 12, Möllersdorf  

**Checkpoints:**
1. **Start** - Münchendorferstrasse 12 (Zentrum)
2. **Brücke über Mühlbach** - Brückengasse
3. **Bahnschranken** - Münchendorferstrasse  
4. **Finish** - Bahnhaltestelle Möllersdorf Aspangbahn

## 🛠️ Available Scripts

### Database Management
```bash
npm run migrate:up        # Alle Migrationen ausführen
npm run migrate:down      # Letzte Migration rückgängig
npm run migrate:reset     # Alle Migrationen rückgängig
npm run migrate:create    # Neue Migration erstellen
npm run setup:db          # Komplettes DB-Setup
```

### Development
```bash
npm run dev              # Development Server mit Hot-Reload
npm start                # Production Server
```

## 🔧 Konfiguration

### Environment Variables (.env)

> Zugangsdaten stehen **nur** in der lokalen `.env` (nicht im Repo). Vorlage: `.env.example`.

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=neoquest
DB_USER=neoquest_app
DB_PASSWORD=<nur in der lokalen .env>
DB_SCHEMA=neoquest

# Server
PORT=3000
NODE_ENV=development

# Security
JWT_SECRET=<nur in der lokalen .env>
ALLOWED_IP_RANGES=192.168.1.0/24

# ESP32
ESP32_UDP_PORT=8888
ESP32_BROADCAST_IP=192.168.1.255
```

### Database Configuration (database.json)

Unterstützt mehrere Umgebungen:
- **dev** - Development (lokale DB)
- **test** - Testing (separate Test-DB)  
- **production** - Production (Environment Variables)

## 📊 Test-Daten

Das System kommt mit vorgefertigten Test-Daten:

### Spieler:innen
- `QR_TOKEN_ABC123` - Max Mustermann  
- `QR_TOKEN_DEF456` - Lisa Schmidt
- `QR_TOKEN_GHI789` - Tom Weber
- `QR_TOKEN_JKL012` - Anna Müller
- `QR_TOKEN_MNO345` - Klaus Bauer

### Spiele
1. **Möllersdorf Schatzsuche** - Lokale Tour um Münchendorferstrasse
2. **Wien Alternative Tour** - Wien-Tour für Vergleichstests  
3. **Traiskirchen Geschichte** - Historische Tour

## 🔄 Migration Workflow

### Neue Migration erstellen
```bash
npm run migrate:create add-new-feature
```

### Migration entwickeln
```javascript
// migrations/TIMESTAMP-add-new-feature.js
exports.up = function(db) {
  return db.runSql(`
    -- SQL für "up" Migration
    ALTER TABLE neoquest.games ADD COLUMN new_field VARCHAR(255);
  `);
};

exports.down = function(db) {
  return db.runSql(`
    -- SQL für "down" Migration  
    ALTER TABLE neoquest.games DROP COLUMN new_field;
  `);
};
```

### Migration ausführen
```bash
npm run migrate:up
```

## 🚨 Troubleshooting

### Database Connection Issues
```bash
# PostgreSQL Service prüfen
sudo systemctl status postgresql

# Connection testen
psql -h localhost -U postgres -d neoquest

# Logs prüfen
tail -f /var/log/postgresql/postgresql-*.log
```

### Migration Problems
```bash
# Migration Status prüfen
npm run migrate:status

# Letzte Migration rückgängig
npm run migrate:down

# Reset und neu aufbauen
npm run migrate:reset
npm run migrate:up
```

### Schema Issues
```bash
# Schema existiert?
psql -h localhost -U postgres -d neoquest -c "\dn"

# Tabellen im Schema prüfen
psql -h localhost -U postgres -d neoquest -c "\dt neoquest.*"
```

## 🔐 Sicherheit

- **LAN-only**: Server nur für lokale IP-Bereiche konfiguriert
- **Token-basiert**: QR-Codes enthalten eindeutige Spieler-Tokens
- **No Internet**: Funktioniert vollständig offline im LAN
- **Prepared Statements**: SQL-Injection Schutz

## 📱 Flutter App Integration

Der Server stellt folgende APIs bereit:

- `POST /register` - Spieler:in registrieren
- `GET /getGameData` - Spielpaket laden  
- `POST /uploadResults` - Ergebnisse hochladen
- `GET /getQueueStatus` - Upload-Status prüfen
- `POST /triggerEspCommand` - ESP32 steuern
- `GET /admin/getRoutes` - Admin-Übersicht