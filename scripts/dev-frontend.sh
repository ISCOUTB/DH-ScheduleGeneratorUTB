#!/usr/bin/env bash
#
# dev-frontend.sh — Desarrollo rápido de la interfaz (Nivel 2).
#
# Levanta backend + db + cron-updater (poblador) + un proxy Nginx liviano que
# expone /api en Docker (sin reconstruir la imagen pesada del frontend) y
# arranca Flutter con `-d chrome` (hot reload nativo). Chrome se abre solo en
# http://localhost:8080 con datos reales y login de Microsoft funcional
# (favoritos incluidos), gracias al CORS de desarrollo del backend.
#
# Poblado de la DB:
#   - Si la DB está vacía, se ejecuta `initial-data` automáticamente.
#   - Si ya tiene datos, no se re-puebla (cron-updater la mantiene fresca).
#   - Con --seed se fuerza el poblado aunque ya tenga datos.
#
# Uso:
#   ./scripts/dev-frontend.sh                                  # login real de Microsoft
#   ./scripts/dev-frontend.sh --seed                           # forzar repoblado
#   ./scripts/dev-frontend.sh --dart-define=DEV_SKIP_AUTH=true # usuario mock (UI sin login)
#
# Cualquier argumento extra (que no sea --seed) se pasa tal cual a `flutter run`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.frontend-dev.yml)

# Separa la flag --seed de los argumentos que van a `flutter run`.
SEED=false
FLUTTER_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --seed) SEED=true ;;
    *) FLUTTER_ARGS+=("$arg") ;;
  esac
done

echo "Levantando backend + db + cron-updater + proxy Nginx (--build + --force-recreate aplican cambios de código y de .env; el frontend pesado no se reconstruye)..."
"${COMPOSE[@]}" up -d --build --force-recreate backend db cron-updater frontend

echo "Esperando a que la DB esté lista..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' db 2>/dev/null || true)" = "healthy" ]; do
  sleep 1
done

# Decide si poblar: forzado con --seed, o automático si la tabla de materias
# está vacía. Se consulta con las credenciales del propio contenedor.
need_seed=$SEED
if [ "$SEED" = false ]; then
  count="$(docker exec db sh -c \
    'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM public.materia"' \
    2>/dev/null || echo 0)"
  if [ "${count//[^0-9]/}" = "" ] || [ "${count//[^0-9]/}" -eq 0 ]; then
    echo "La DB está vacía."
    need_seed=true
  fi
fi

if [ "$need_seed" = true ]; then
  echo "Poblando la base de datos con initial-data (puede tardar ~1-2 min)..."
  "${COMPOSE[@]}" run --rm initial-data
fi

echo "Iniciando Flutter en Chrome (se abre solo en http://localhost:8080)."
echo "Tras editar el codigo: pulsa 'r' (hot reload) en esta terminal."
cd "$ROOT/frontend"
exec flutter run -d chrome --web-port 8080 ${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"}
