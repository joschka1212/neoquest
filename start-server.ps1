<#
  NeoQuest-Server lokal starten (mit automatischem Neustart bei Code-Aenderungen)
  Aufruf:  .\start-server.ps1          -> Entwicklungsmodus (nodemon)
           .\start-server.ps1 -Prod    -> ohne nodemon
  Beenden: Strg+C
#>
param([switch]$Prod)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot 'neoquest_server')

if (-not (Test-Path '.env'))         { throw '.env fehlt in neoquest_server - .env.example kopieren und ausfuellen.' }
if (-not (Test-Path 'node_modules')) { npm install --no-fund --no-audit }

$pg = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pg -and $pg.Status -ne 'Running') {
  Write-Warning "PostgreSQL-Dienst '$($pg.Name)' laeuft nicht (Status: $($pg.Status)). Starten mit: Start-Service $($pg.Name)  (als Administrator)"
}

if ($Prod) { npm start } else { npm run dev }
