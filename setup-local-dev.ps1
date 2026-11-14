<#
  NeoQuest - lokale Entwicklungsumgebung einrichten (DB + Server)
  ---------------------------------------------------------------
  1. Kopiert das Projekt aus OneDrive nach C:\dev\neoquest (ohne node_modules/Build-Artefakte)
  2. Fragt das postgres-Passwort ab (wird NICHT geaendert), vergibt ein neues Zufallspasswort
     fuer neoquest_app und ein neues JWT-Secret - alles nur in den lokalen .env-Dateien.
     Der Server nutzt ab jetzt neoquest_app. Das Skript kann gefahrlos erneut gestartet werden.
  3. Legt in C:\dev\neoquest ein frisches Git-Repo an (getrennte Commits: Basis, db, server, app)
     und pusht es nach Rueckfrage per --force zu GitHub. Das alte Repo bleibt im OneDrive-Ordner.
  4. Datenbank: npm install, Setup (DB/User/Schema), Migrationen, Rechte fuer neoquest_app
  5. Server: npm install und Probestart mit Health-Check
  6. Prueft, dass PostgreSQL nur auf localhost lauscht

  Ausfuehren in PowerShell (im Projektordner):
    powershell -ExecutionPolicy Bypass -File .\setup-local-dev.ps1
  Danach den Server starten mit:  C:\dev\neoquest\start-server.ps1
  Der alte OneDrive-Ordner wird NICHT geloescht - das machst du selbst, wenn alles laeuft.
#>

$ErrorActionPreference = 'Stop'
$Source = "$env:USERPROFILE\OneDrive\Hannes\Projects\neoquest"
$Target = 'C:\dev\neoquest'

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Get-EnvValue($file, $key) {
  $line = Get-Content $file | Where-Object { $_ -match "^\s*$key\s*=" } | Select-Object -First 1
  if ($line) { return ($line -split '=', 2)[1].Trim() } else { return $null }
}
function Set-EnvValue($file, $key, $value) {
  $lines = [System.Collections.Generic.List[string]](Get-Content $file)
  $idx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^\s*$key\s*=") { $idx = $i; break } }
  if ($idx -ge 0) { $lines[$idx] = "$key=$value" } else { $lines.Add("$key=$value") }
  [System.IO.File]::WriteAllLines($file, $lines)
}
function New-Secret([int]$len) {
  $chars = [char[]](48..57 + 65..90 + 97..122)
  $bytes = New-Object byte[] $len
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}
function Invoke-Checked($what) { if ($LASTEXITCODE -ne 0) { throw "$what fehlgeschlagen (Exit-Code $LASTEXITCODE)" } }

# ---------- 0. Voraussetzungen pruefen ----------
# PATH neu einlesen, damit frisch installierte Programme ohne neues Terminal gefunden werden
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
Step "Pruefe Voraussetzungen"
$missing = @()
foreach ($tool in @(
    @{ cmd = 'git';  hint = 'Git for Windows:  winget install --id Git.Git -e --source winget' },
    @{ cmd = 'node'; hint = 'Node.js LTS:      winget install --id OpenJS.NodeJS.LTS -e --source winget' },
    @{ cmd = 'npm';  hint = '(kommt mit Node.js)' })) {
  $c = Get-Command $tool.cmd -ErrorAction SilentlyContinue
  if ($c) { Write-Host ("  OK  {0,-5} {1}" -f $tool.cmd, $c.Source) }
  else    { Write-Host ("  FEHLT {0,-5} -> {1}" -f $tool.cmd, $tool.hint) -ForegroundColor Yellow; $missing += $tool.cmd }
}
if (-not (Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' -ErrorAction SilentlyContinue)) {
  Write-Host "  FEHLT psql  -> PostgreSQL unter C:\Program Files\PostgreSQL nicht gefunden" -ForegroundColor Yellow; $missing += 'psql'
}
if ($missing) { throw "Bitte zuerst installieren: $($missing -join ', ') - danach das Skript erneut starten." }

# ---------- 1. Kopieren (bei erneutem Lauf: nur aktualisieren) ----------
$excludeDirs = @('node_modules', 'build', '.dart_tool', '.gradle', '.kotlin', 'ephemeral')
if (Test-Path $Target) {
  Step "$Target existiert schon - aktualisiere Dateien (ohne .git und .env)"
  robocopy $Source $Target /E /XD ($excludeDirs + '.git') /XF .env /NFL /NDL /NJH /NP | Out-Null
} else {
  Step "Kopiere Projekt nach $Target"
  New-Item -ItemType Directory -Path (Split-Path $Target) -Force | Out-Null
  robocopy $Source $Target /E /XD $excludeDirs /NFL /NDL /NJH /NP | Out-Null
}
if ($LASTEXITCODE -ge 8) { throw "robocopy fehlgeschlagen (Code $LASTEXITCODE)" }
Set-Location $Target

# ---------- 2. Zugangsdaten ----------
Step "Zugangsdaten: postgres-Passwort abfragen, neues Passwort fuer neoquest_app"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PGCLIENTENCODING = 'UTF8'
$dbEnv  = Join-Path $Target 'neoquest_db\.env'
$srvEnv = Join-Path $Target 'neoquest_server\.env'
$psql = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
if (-not $psql) { throw 'psql.exe nicht gefunden (C:\Program Files\PostgreSQL\<Version>\bin).' }

function Test-PgLogin($pw) {
  $env:PGPASSWORD = $pw
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  & $psql.FullName -h localhost -U postgres -d postgres -tAc 'SELECT 1' *> $null
  $ok = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $prev
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  return $ok
}

# Bei erneutem Lauf steht das Admin-Passwort schon in der lokalen .env
$adminPw = Get-EnvValue $dbEnv 'DB_ADMIN_PASSWORD'
if (-not $adminPw -or $adminPw -eq 'CHANGE_ME' -or -not (Test-PgLogin $adminPw)) {
  $adminPw = $null
  for ($try = 1; $try -le 3 -and -not $adminPw; $try++) {
    $sec = Read-Host 'Passwort des PostgreSQL-Users "postgres" eingeben' -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    if (Test-PgLogin $plain) { $adminPw = $plain } else { Write-Warning 'Anmeldung fehlgeschlagen - bitte nochmal.' }
  }
  if (-not $adminPw) { throw 'Keine Anmeldung als postgres moeglich. Passwort ggf. in pgAdmin pruefen.' }
}
Write-Host "OK - Anmeldung als postgres erfolgreich." -ForegroundColor Green

$newAppPw = New-Secret 24
$newJwt   = New-Secret 64
$sql = @"
DO `$`$BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'neoquest_app') THEN
    ALTER ROLE neoquest_app WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '$newAppPw';
  ELSE
    CREATE ROLE neoquest_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '$newAppPw';
  END IF;
END`$`$;
"@
$sqlFile = Join-Path $env:TEMP 'neoquest-approle.sql'
[System.IO.File]::WriteAllText($sqlFile, $sql)
try {
  $env:PGPASSWORD = $adminPw
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  & $psql.FullName -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -q -f $sqlFile
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  if ($code -ne 0) { throw 'Anlegen/Aendern von neoquest_app fehlgeschlagen.' }
} finally {
  Remove-Item $sqlFile -ErrorAction SilentlyContinue
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

# neoquest_db/.env: Admin-Zugang fuer Setup/Migrationen, App-Zugang fuer neoquest_app
Set-EnvValue $dbEnv 'DB_ADMIN_USER' 'postgres'
Set-EnvValue $dbEnv 'DB_ADMIN_PASSWORD' $adminPw
Set-EnvValue $dbEnv 'DB_USER' 'neoquest_app'
Set-EnvValue $dbEnv 'DB_PASSWORD' $newAppPw
Set-EnvValue $dbEnv 'DB_SCHEMA' 'neoquest'
# neoquest_server/.env: Server laeuft ab jetzt mit dem eingeschraenkten User
Set-EnvValue $srvEnv 'DB_USER' 'neoquest_app'
Set-EnvValue $srvEnv 'DB_PASSWORD' $newAppPw
Set-EnvValue $srvEnv 'DB_SCHEMA' 'neoquest'
Set-EnvValue $srvEnv 'JWT_SECRET' $newJwt
Write-Host "OK - Zugangsdaten stehen nur in den lokalen .env-Dateien (dein postgres-Passwort bleibt unveraendert)." -ForegroundColor Green

# ---------- 3. Frisches Git-Repo, getrennte Commits ----------
# Das alte Repo (mit node_modules/.env in der Historie) bleibt im OneDrive-Ordner als Sicherung.
# In C:\dev\neoquest wird ein neues Repo ohne Altlasten angelegt und nach GitHub gepusht.
Step "Git: frisches Repo mit getrennten Commits (Basis, db, server, app)"
$leakPattern = '(^|/)\.env$|node_modules/|/logs/|/uploads/|local\.properties'
$done = $false
if ((Test-Path .git) -and (git rev-parse --verify -q HEAD)) {
  $hasMarker = git log --format=%s | Select-String -SimpleMatch 'chore: Projektbasis'
  $trackedLeaks = git ls-files | Select-String -Pattern $leakPattern
  $done = [bool]$hasMarker -and -not $trackedLeaks
}
if ($done) {
  Write-Host "Repo ist schon sauber aufgesetzt - uebersprungen."
} else {
  $remoteUrl = git -C $Source config --get remote.origin.url
  if (-not $remoteUrl) { throw "Remote-URL nicht gefunden in $Source\.git\config" }

  # Git-Identitaet (bei frischer Git-Installation noch nicht gesetzt)
  if (-not (git config --global user.email)) {
    $name  = Read-Host 'Dein Name fuer Git-Commits'
    $email = Read-Host 'Deine E-Mail fuer Git-Commits (die bei GitHub hinterlegte)'
    git config --global user.name  $name;  Invoke-Checked 'git config user.name'
    git config --global user.email $email; Invoke-Checked 'git config user.email'
  }

  if (Test-Path .git) {
    try { Remove-Item .git -Recurse -Force }
    catch { throw "Konnte $Target\.git nicht loeschen (Datei gesperrt?). VS Code/Explorer in diesem Ordner schliessen und Skript erneut starten." }
  }
  git init -q -b main;                   Invoke-Checked 'git init'
  git config core.autocrlf true
  git remote add origin $remoteUrl;      Invoke-Checked 'git remote add'

  $leaks = git ls-files --others --exclude-standard | Select-String -Pattern $leakPattern
  if ($leaks) { $leaks; throw 'Abbruch: .gitignore deckt nicht alles ab - es wuerden Secrets/Abhaengigkeiten committet.' }

  $parts = @(
    @{ paths = @('.gitignore', '.gitattributes', 'README.md', 'setup-local-dev.ps1', 'start-server.ps1', 'documentation');
       msg = 'chore: Projektbasis (gitignore, README, Setup-Skripte, Doku)' },
    @{ paths = @('neoquest_db');     msg = 'db: PostgreSQL-Schema, Migrationen und Setup (Zugangsdaten nur aus .env)' },
    @{ paths = @('neoquest_server'); msg = 'server: Express-API, laeuft mit eingeschraenktem DB-User neoquest_app' },
    @{ paths = @('neoquest_app');    msg = 'app: Flutter-Client' },
    @{ paths = @('.');               msg = 'chore: restliche Projektdateien' })
  foreach ($part in $parts) {
    $existing = $part.paths | Where-Object { Test-Path $_ }
    if (-not $existing) { continue }
    git add -- $existing;                Invoke-Checked "git add $($existing -join ' ')"
    if (git diff --cached --name-only) {
      git commit -q -m $part.msg;        Invoke-Checked "git commit ($($part.msg))"
    }
  }
  $trackedLeaks = git ls-files | Select-String -Pattern $leakPattern
  if ($trackedLeaks) { $trackedLeaks; throw 'Abbruch: Im Repo sind Secrets/Abhaengigkeiten gelandet - nichts gepusht.' }
  git log --oneline
  Write-Host ("Dateien im Repo: " + (git ls-files | Measure-Object).Count)

  $answer = Read-Host "GitHub-Repo $remoteUrl jetzt mit diesem sauberen Stand ueberschreiben (git push --force)? [j/N]"
  if ($answer -match '^[jJyY]') {
    git push --force -u origin main;     Invoke-Checked 'git push'
    Write-Host "OK - GitHub enthaelt jetzt nur noch den bereinigten Stand." -ForegroundColor Green
  } else {
    Write-Warning "Nicht gepusht. Spaeter in $Target mit:  git push --force -u origin main"
  }
}

# ---------- 4. Datenbank ----------
Step "Datenbank: Abhaengigkeiten, Setup, Migrationen, Rechte"
Push-Location neoquest_db
npm install --no-fund --no-audit;  Invoke-Checked 'npm install (db)'
npm run setup:db;                  Invoke-Checked 'setup:db'
npm run migrate:up;                Invoke-Checked 'migrate:up'
Pop-Location

# ---------- 5. Server ----------
Step "Server: Abhaengigkeiten und Probestart"
Push-Location neoquest_server
foreach ($d in 'logs', 'uploads', 'uploads\missions', 'temp') { New-Item -ItemType Directory -Path $d -Force | Out-Null }
npm install --no-fund --no-audit;  Invoke-Checked 'npm install (server)'
$port = Get-EnvValue $srvEnv 'PORT'; if (-not $port) { $port = 3000 }
$proc = Start-Process node -ArgumentList 'src/server.js' -PassThru -NoNewWindow `
          -RedirectStandardOutput "$env:TEMP\neoquest-test.out" -RedirectStandardError "$env:TEMP\neoquest-test.err"
$health = $null
for ($i = 0; $i -lt 20 -and -not $health; $i++) {
  Start-Sleep -Seconds 1
  try { $health = Invoke-RestMethod "http://localhost:$port/health" -TimeoutSec 3 } catch { }
}
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Pop-Location
if ($health) {
  Write-Host "OK - Server antwortet auf http://localhost:$port/health" -ForegroundColor Green
  $health | ConvertTo-Json -Depth 4 | Write-Host
} else {
  Write-Warning "Server hat nicht geantwortet. Ausgabe:"
  Get-Content "$env:TEMP\neoquest-test.out", "$env:TEMP\neoquest-test.err" -Tail 30 -ErrorAction SilentlyContinue
}

# ---------- 6. PostgreSQL pruefen ----------
Step "PostgreSQL-Konfiguration"
Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType -AutoSize
$conf = Get-ChildItem 'C:\Program Files\PostgreSQL\*\data\postgresql.conf' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($conf) {
  $line = Select-String -Path $conf.FullName -Pattern '^\s*listen_addresses' | Select-Object -First 1
  if (-not $line -or $line.Line -match "'localhost'") {
    Write-Host "OK - PostgreSQL lauscht nur auf localhost." -ForegroundColor Green
  } else {
    Write-Warning "listen_addresses ist '$($line.Line.Trim())' in $($conf.FullName). Fuer reinen Lokalbetrieb auf  listen_addresses = 'localhost'  setzen und Dienst neu starten."
  }
}

Write-Host "`nFertig." -ForegroundColor Green
Write-Host "  Server starten:   $Target\start-server.ps1"
Write-Host "  VS Code oeffnen:  code $Target"
Write-Host "  Wenn alles laeuft: alten Ordner $Source loeschen"
