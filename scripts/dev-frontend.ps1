#!/usr/bin/env pwsh
#
# dev-frontend.ps1 - Desarrollo rapido de la interfaz (Nivel 2).
# Equivalente en PowerShell de scripts/dev-frontend.sh, para Windows.
#
# Levanta SOLO backend + db + un proxy Nginx en Docker (sin reconstruir la
# imagen pesada del frontend) y arranca el dev-server de Flutter en el host.
# La app queda disponible en http://localhost con datos reales del backend.
#
# Uso:
#   ./scripts/dev-frontend.ps1                                  # login real de Microsoft
#   ./scripts/dev-frontend.ps1 --dart-define=DEV_SKIP_AUTH=true # usuario mock
#
# Cualquier argumento extra se pasa tal cual a `flutter run`.

$ErrorActionPreference = "Stop"

# Raiz del proyecto (carpeta padre de este script).
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "Levantando backend + db + proxy Nginx (sin reconstruir el frontend)..."
docker compose -f docker-compose.yml -f docker-compose.frontend-dev.yml up -d backend db frontend
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Iniciando el dev-server de Flutter (accede via http://localhost)..."
Write-Host "Tras editar el codigo: pulsa 'R' aqui y refresca el navegador."
Set-Location (Join-Path $Root "frontend")
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 @args
