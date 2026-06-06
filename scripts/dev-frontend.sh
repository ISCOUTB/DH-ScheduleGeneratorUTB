#!/usr/bin/env bash
#
# dev-frontend.sh — Desarrollo rápido de la interfaz (Nivel 2).
#
# Levanta SOLO backend + db + un proxy Nginx en Docker (sin reconstruir la
# imagen pesada del frontend) y arranca el dev-server de Flutter en el host.
# La app queda disponible en http://localhost con datos reales del backend.
#
# Uso:
#   ./scripts/dev-frontend.sh                      # login real de Microsoft
#   ./scripts/dev-frontend.sh --dart-define=DEV_SKIP_AUTH=true   # usuario mock
#
# Cualquier argumento extra se pasa tal cual a `flutter run`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Levantando backend + db + proxy Nginx (sin reconstruir el frontend)..."
docker compose \
  -f docker-compose.yml \
  -f docker-compose.frontend-dev.yml \
  up -d backend db frontend

echo "Iniciando el dev-server de Flutter (accede via http://localhost)..."
echo "Tras editar el codigo: pulsa 'R' aqui y refresca el navegador."
cd "$ROOT/frontend"
exec flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 "$@"
