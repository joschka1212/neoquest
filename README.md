# NeoQuest

Geo-Schatzsuche für das lokale Netz: Spieler:innen laufen mit einer Flutter-App GPS-Checkpoints ab, lösen Rätsel und laden Fotos, Routen und Ergebnisse hoch. Server und Datenbank laufen auf einem Windows-Rechner im LAN, eine Internetverbindung ist nicht nötig.

## Aufbau

| Ordner | Technik | Zweck |
|---|---|---|
| `neoquest_app/` | Flutter / Dart | Client-App (Android, Windows, Web) |
| `neoquest_server/` | Node.js, Express 5 | REST-API auf Port 3000, Einstieg `src/server.js` |
| `neoquest_db/` | PostgreSQL 18, db-migrate | Schema `neoquest`, Migrationen, Setup |
| `documentation/` | Text / Markdown / HTML | Installationsanleitung, Befehle, Designstudien |

## Voraussetzungen

- PostgreSQL 18
- Node.js ab Version 18 und npm
- Flutter SDK (Dart ab 3.8) für die App

## Einrichtung

### 1. Datenbank

```powershell
cd neoquest_db
npm install
Copy-Item .env.example .env     # Zugangsdaten eintragen
npm run setup:db                # Datenbank, User neoquest_app und Schema anlegen
npm run migrate:up              # Migrationen ausführen, danach Rechte setzen
```

Details: [documentation/neoquest-db-installation-guide.md](documentation/neoquest-db-installation-guide.md)

### 2. Server

```powershell
cd neoquest_server
Copy-Item .env.example .env     # DB_PASSWORD wie in neoquest_db/.env, eigenes JWT_SECRET
cd ..
.\start-server.ps1              # installiert bei Bedarf Pakete und startet mit nodemon
Invoke-RestMethod http://localhost:3000/health
```

Der Server lauscht auf `0.0.0.0`, damit Handys im LAN ihn erreichen. PostgreSQL lauscht nur auf `localhost`.

### 3. App

```powershell
cd neoquest_app
flutter pub get
flutter run
```

Weitere Befehle: [documentation/commandos.txt](documentation/commandos.txt)

## Server-API

Alle Endpunkte liegen unter `/api/…`:

| Bereich | Präfix | Zweck |
|---|---|---|
| Auth | `/api/auth` | Registrierung, Token verknüpfen und prüfen |
| Spiel | `/api/game` | Spieldaten, Medien, Konfiguration, Rangliste |
| Session | `/api/session` | gemeinsamer Spielstart, Countdown, Status |
| Missionen | `/api/mission` | Route und Fotos hochladen, Abschluss, Rangliste |
| Uploads | `/api/upload` | Ergebnisse, GPS-Tracks, Fotos |
| Level 1 | `/api/level1` | einfaches Rennen: Tokens, Inhalte, Ergebnisse |
| ESP32 | `/api/esp32` | Hardware-Checkpoints steuern |
| Admin | `/api/admin` | Tokens, Spieler:innen, Statistik, Systemstatus |

Dazu kommen `/health` sowie die statischen Ordner `/media` (Spiel-Assets) und `/uploads` (hochgeladene Dateien).

## Datenbank

Das Schema `neoquest` enthält unter anderem:

- **Spiel:** `games`, `game_config`, `checkpoints`, `puzzles`, `hints`, `media_files`
- **Spieler:innen:** `players`, `player_games`, `checkpoint_visits`, `puzzle_attempts`, `hint_usage`
- **Sessions:** `game_sessions`, `coordinated_sessions`, `session_participants`, `session_events`
- **Uploads und Ergebnisse:** `gps_tracks`, `photo_uploads`, `mission_uploads`, `mission_results`, `upload_queue`
- **Auswertung:** `leaderboards`, `game_statistics`, `quiz_results`
- **Hardware:** `esp`

Die Seed-Migration legt Beispielspiele an, darunter die **Möllersdorf Schatzsuche** mit vier Checkpoints (Start Münchendorferstrasse 12, Brücke über den Mühlbach, Bahnschranken, Ziel Bahnhaltestelle Aspangbahn).

Schema-Änderungen nur als neue Migration:

```powershell
cd neoquest_db
npm run migrate:create -- <name>
```

## Sicherheit

- Zugangsdaten stehen nur in `neoquest_db/.env` und `neoquest_server/.env` (gitignored). Vorlagen: `.env.example`.
- Der Server nutzt den eingeschränkten DB-User `neoquest_app` (nur SELECT/INSERT/UPDATE/DELETE, kein DDL).
- Zugriffe sind auf die IP-Bereiche aus `ALLOWED_IP_RANGES` beschränkt, `/api/` hat ein Rate-Limit.
- Laufzeitdaten (`uploads/`, `logs/`, `temp/`) bleiben lokal und kommen nicht ins Repo.
