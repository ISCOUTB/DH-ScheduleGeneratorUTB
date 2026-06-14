#!/usr/bin/env pwsh
#
# dev-frontend.ps1 - Desarrollo rapido de la interfaz (Nivel 2).
# Equivalente en PowerShell de scripts/dev-frontend.sh, para Windows.
#
# Levanta backend + db + cron-updater (poblador) + un proxy Nginx liviano que
# expone /api en Docker (sin reconstruir la imagen pesada del frontend) y
# arranca Flutter con -d chrome (hot reload nativo). Chrome se abre solo en
# http://localhost:8080 con datos reales y login de Microsoft funcional
# (favoritos incluidos), gracias al CORS de desarrollo del backend.
#
# Poblado de la DB:
#   - Si la DB esta vacia, se ejecuta initial-data automaticamente.
#   - Si ya tiene datos, no se re-puebla (cron-updater la mantiene fresca).
#   - Con --seed se fuerza el poblado aunque ya tenga datos.
#
# Uso:
#   ./scripts/dev-frontend.ps1                                  # login real de Microsoft
#   ./scripts/dev-frontend.ps1 --seed                           # forzar repoblado
#   ./scripts/dev-frontend.ps1 --dart-define=DEV_SKIP_AUTH=true # usuario mock (UI sin login)
#
# Cualquier argumento extra (que no sea --seed) se pasa tal cual a `flutter run`.

$ErrorActionPreference = "Stop"

# Raiz del proyecto (carpeta padre de este script).
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Compose = @("compose", "-f", "docker-compose.yml", "-f", "docker-compose.frontend-dev.yml")

# Separa la flag --seed de los argumentos que van a `flutter run`.
$Seed = $false
$FlutterArgs = @()
foreach ($arg in $args) {
    if ($arg -eq "--seed") { $Seed = $true }
    else { $FlutterArgs += $arg }
}

Write-Host "Levantando backend + db + cron-updater + proxy Nginx (sin reconstruir el frontend)..."
docker @Compose up -d backend db cron-updater frontend
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Esperando a que la DB este lista..."
do {
    Start-Sleep -Seconds 1
    $health = docker inspect -f '{{.State.Health.Status}}' db 2>$null
} until ($health -eq "healthy")

# Decide si poblar: forzado con --seed, o automatico si la tabla de materias
# esta vacia. Se consulta con las credenciales del propio contenedor.
$needSeed = $Seed
if (-not $Seed) {
    $count = docker exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM public.materia"' 2>$null
    $count = ($count -replace '[^0-9]', '')
    if ([string]::IsNullOrEmpty($count) -or [int]$count -eq 0) {
        Write-Host "La DB esta vacia."
        $needSeed = $true
    }
}

if ($needSeed) {
    Write-Host "Poblando la base de datos con initial-data (puede tardar ~1-2 min)..."
    docker @Compose run --rm initial-data
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Iniciando Flutter en Chrome (se abre solo en http://localhost:8080)."
Write-Host "Tras editar el codigo: pulsa 'r' (hot reload) en esta terminal."
Set-Location (Join-Path $Root "frontend")
flutter run -d chrome --web-port 8080 @FlutterArgs
