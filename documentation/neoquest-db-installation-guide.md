# NeoQuest – Datenbank installieren und migrieren

Anleitung für die PostgreSQL-Datenbank in `neoquest_db/`: Datenbank, User und Schema anlegen, dann die Migrationen ausführen.

Alle Befehle sind für PowerShell und laufen im Ordner `neoquest_db/`, sofern nicht anders angegeben.

---

## Voraussetzungen

- **PostgreSQL 18** (lauscht nur auf `localhost`)
- **Node.js** ab Version 18 (getestet mit Node 26) und **npm**
- Optional: **pgAdmin** zum Ansehen der Daten

`db-migrate`, `db-migrate-pg` und `pg` sind lokale Abhängigkeiten im Projekt. Global muss nichts installiert werden.

---

## 1. Abhängigkeiten installieren

```powershell
cd C:\dev\neoquest\neoquest_db
npm install
```

## 2. Zugangsdaten eintragen

```powershell
Copy-Item .env.example .env
```

Danach in `.env` die Werte eintragen:

| Variable | Bedeutung |
|---|---|
| `DB_ADMIN_USER` / `DB_ADMIN_PASSWORD` | PostgreSQL-Superuser (meist `postgres`), für Setup und Migrationen |
| `DB_USER` / `DB_PASSWORD` | eingeschränkter App-User `neoquest_app`, wird vom Setup angelegt |
| `DB_NAME`, `DB_SCHEMA` | `neoquest` |

Passwörter stehen **nur** in der lokalen `.env` (gitignored), nie in Code, Doku oder Commits. Für `neoquest_app` ein eigenes, zufälliges Passwort wählen und dasselbe in `neoquest_server/.env` eintragen.

## 3. Datenbank, User und Schema anlegen

```powershell
npm run setup:db
```

Das Skript `scripts/setup-database.js`

- verbindet sich als Superuser,
- legt die Datenbank `neoquest` an (falls sie fehlt),
- legt den User `neoquest_app` mit dem Passwort aus `DB_PASSWORD` an,
- legt das Schema `neoquest` an und vergibt die Rechte.

## 4. Migrationen ausführen

```powershell
npm run migrate:up
```

Danach setzt das Skript automatisch die Rechte für `neoquest_app` (nur SELECT/INSERT/UPDATE/DELETE, kein DDL). Rechte lassen sich auch einzeln neu setzen mit `npm run db:grant`.

Erfolgreiche Ausgabe (gekürzt):

```
[INFO] Processed migration 19920214000001-init-new-quest-schema
[INFO] Processed migration 19920214000002-add-indexes
...
[INFO] Done
```

---

## Weitere Befehle

| Befehl | Zweck |
|---|---|
| `npm run migrate:status` | zeigt, welche Migrationen noch offen sind |
| `npm run migrate:down` | letzte Migration rückgängig machen |
| `npm run migrate:reset` | alle Migrationen rückgängig machen |
| `npm run migrate:create -- <name>` | neue Migration anlegen |

Schema-Änderungen immer als **neue** Migration in `migrations/` anlegen. Bestehende Migrationen nicht nachträglich ändern.

---

## Fehlerbehebung

| Fehlermeldung | Lösung |
|---|---|
| `.env fehlt` | `.env.example` nach `.env` kopieren und ausfüllen |
| `DB_… ist in .env nicht gesetzt` | Wert in `.env` eintragen (`CHANGE_ME` gilt als nicht gesetzt) |
| `No such driver found` | `npm install` in `neoquest_db` ausführen |
| `database "neoquest" does not exist` | zuerst `npm run setup:db` ausführen |
| `password authentication failed` | Passwort in `.env` prüfen |
| Verbindung abgelehnt | PostgreSQL-Dienst läuft nicht: `Get-Service postgresql*`, ggf. als Administrator `Start-Service <Name>` |
