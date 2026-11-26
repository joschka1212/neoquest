# NeoQuest

Geo-Schatzsuche: Spieler:innen laufen mit einer Flutter-App GPS-Checkpoints ab, lösen Rätsel und laden Fotos/Ergebnisse hoch. Läuft im lokalen Netz (LAN), Server und Datenbank auf diesem Windows-Rechner.

## Aufbau

| Ordner | Technik | Zweck |
|---|---|---|
| `neoquest_app/` | Flutter / Dart | Client-App (Android, Windows, Web) |
| `neoquest_server/` | Node.js, Express 5 | REST-API, Port 3000, `src/server.js` |
| `neoquest_db/` | PostgreSQL 18, db-migrate | Schema `neoquest`, Migrationen, Setup |
| `documentation/` | Text/Markdown | Designstudien, Installationshinweise |

## Befehle (PowerShell)

- Server starten: `.\start-server.ps1` (nodemon, Neustart bei Änderungen)
- Health-Check: `Invoke-RestMethod http://localhost:3000/health`
- Migrationen: in `neoquest_db`: `npm run migrate:up` (setzt danach automatisch die Rechte für `neoquest_app`)
- Neue Migration: in `neoquest_db`: `npm run migrate:create -- <name>`
- Server-Lint/Tests: in `neoquest_server`: `npm run lint`, `npm test`
- App: in `neoquest_app`: `flutter pub get`, `flutter run`

## Regeln

- **Keine Secrets ins Repo.** Zugangsdaten stehen nur in `neoquest_db/.env` und `neoquest_server/.env` (gitignored). Vorlagen: `.env.example`. Keine Passwörter oder Fallback-Passwörter in Code, Doku oder Logs schreiben.
- **Datenbank-Zugriff im Server nur über den gemeinsamen Pool** aus `neoquest_server/src/config/database.js`, keine eigenen `new Pool(...)`.
- **Der Server läuft mit dem eingeschränkten DB-User `neoquest_app`**: nur SELECT/INSERT/UPDATE/DELETE, kein DDL. Schema-Änderungen ausschließlich als neue Migration in `neoquest_db/migrations/`, niemals im Server-Code. Bestehende Migrationen nicht nachträglich ändern.
- PostgreSQL lauscht nur auf `localhost`. Der Server lauscht auf `0.0.0.0`, damit Handys im LAN ihn erreichen.
- Laufzeitdaten bleiben lokal und kommen nicht ins Repo: `neoquest_server/uploads/`, `logs/`, `temp/`. Spiel-Assets unter `neoquest_server/media/` gehören ins Repo.
- Commit-Nachrichten mit Präfix `db:`, `server:`, `app:` oder `chore:`; ein Commit pro Bereich, wenn möglich.
- Remote: `https://github.com/joschka1212/neoquest` (Branch `main`).
- Kommunikation mit dem Entwickler auf Deutsch.
