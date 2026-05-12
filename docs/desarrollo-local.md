# Guía de Desarrollo Local

Esta guía documenta cómo levantar el entorno de desarrollo completo en tu máquina local. Incluye la estructura y contenido de los archivos ignorados por Git que son necesarios para correr la aplicación.

## Requisitos Previos

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)
- Credenciales de Microsoft Entra ID (Azure AD). Ver sección de [Variables de Entorno](#1-variables-de-entorno).

## Archivos Ignorados por Git

Los siguientes archivos son necesarios para desarrollo pero están en `.gitignore` por contener configuración local o secretos. **Debes crearlos manualmente.**

| Archivo | Propósito |
|---------|-----------|
| `backend/.env` | Variables de entorno para Docker (DB + Azure) |
| `backend/.env.local` | Variables para ejecutar el backend fuera de Docker |
| `docker-compose.override.yml` | Sobrescritura del compose para desarrollo (sin SSL) |
| `frontend/nginx.dev.conf` | Configuración de Nginx simplificada (HTTP only) |

## 1. Variables de Entorno

### `backend/.env`

Este archivo es leído por Docker Compose (`env_file: ./backend/.env`) y por la aplicación FastAPI. Contiene las credenciales de la base de datos y de Microsoft Entra ID.

Copia el ejemplo y rellena con tus valores:

```bash
cp backend/.env.example backend/.env
```

Estructura esperada:

```env
# Base de datos PostgreSQL
POSTGRES_DB=schedules
POSTGRES_USER=postgres
POSTGRES_PASSWORD=tu_contraseña_segura
DATABASE_URL=postgresql://postgres:tu_contraseña_segura@db:5432/schedules

# Microsoft Entra ID (Azure AD) - Autenticación
# Obtener desde Azure Portal > App registrations > tu app
AZURE_TENANT_ID=tu_tenant_id
AZURE_CLIENT_ID=tu_client_id
AZURE_CLIENT_SECRET=tu_client_secret

# URLs de redirección (desarrollo)
AZURE_REDIRECT_URI=http://localhost/api/auth/callback
FRONTEND_URL=http://localhost

# Tenants permitidos (separados por coma)
AZURE_ALLOWED_TENANTS=tu_tenant_id
```

> **Nota:** El `DATABASE_URL` usa `db` como host porque ese es el nombre del servicio/contenedor en Docker Compose. Dentro de la red Docker, los contenedores se resuelven por nombre de servicio.

### `backend/.env.local`

Este archivo se usa **solo cuando ejecutas el backend fuera de Docker** (por ejemplo, con `uvicorn` directo para hot-reload). La diferencia principal es que el host de la DB apunta a `localhost` en lugar de `db`.

```env
DB_NAME=schedules
DB_USER=postgres
DB_PASSWORD=tu_contraseña_segura
DATABASE_URL=postgresql://postgres:tu_contraseña_segura@localhost:5433/schedules

# Microsoft Entra ID (Azure AD)
AZURE_TENANT_ID=tu_tenant_id
AZURE_CLIENT_ID=tu_client_id
```

> **Nota:** El puerto es `5433` porque `docker-compose.yml` mapea el puerto interno 5432 de PostgreSQL al puerto 5433 del host (`"5433:5432"`). Esto evita conflictos si tienes un PostgreSQL local en el puerto 5432.

### ¿Cuándo se usa cada archivo `.env`?

| Escenario | Archivo utilizado | Host de la DB |
|-----------|-------------------|---------------|
| Todo dentro de Docker (`docker compose up`) | `backend/.env` | `db:5432` |
| Backend fuera de Docker, DB en Docker | `backend/.env.local` | `localhost:5433` |

El código en `repository.py` intenta cargar `.env.local` primero; si `DATABASE_URL` no se encuentra, carga `.env` como fallback.

## 2. Docker Compose Override

### `docker-compose.override.yml`

Docker Compose [aplica automáticamente](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/) este archivo cuando ejecutas `docker compose up` sin la flag `-f`. Sobrescribe la configuración de producción para adaptarla a desarrollo:

**Diferencias con producción (`docker-compose.yml`):**

| Aspecto | Producción | Desarrollo (override) |
|---------|------------|----------------------|
| Nginx config | `nginx.conf` (HTTPS + SSL) | `nginx.dev.conf` (HTTP only) |
| Puerto 443 | Expuesto | No expuesto |
| Certbot | Renueva certificados SSL | Deshabilitado (alpine echo) |
| Cron ETL | Cada 10 min + backups cada 4h | Cada 13 min, sin backups |
| Volumen snapshots | Montado para backups | No montado |

Crea el archivo en la raíz del proyecto con este contenido:

```yaml
services:
  # Servicio del Backend (API)
  backend:
    build: ./backend
    container_name: api
    restart: unless-stopped
    env_file: ./backend/.env
    depends_on:
      db:
        condition: service_healthy
    networks:
      - schedule-net

  # Servicio del Frontend (Flutter + Nginx)
  frontend:
    build: ./frontend
    container_name: web
    restart: unless-stopped
    ports:
      - "80:80"
      # No se expone el puerto 443 en desarrollo
    volumes:
      # Usa la configuración de Nginx de desarrollo (HTTP sin SSL)
      - ./frontend/nginx.dev.conf:/etc/nginx/conf.d/default.conf
      - ./data/www:/var/www/html
    depends_on:
      - backend
    networks:
      - schedule-net

  # Certbot deshabilitado en desarrollo
  certbot:
    image: alpine
    command: echo "Certbot is disabled in development mode. No certificates will be generated."

  # Servicio de la Base de Datos (PostgreSQL)
  db:
    build:
      context: .
      dockerfile: db.Dockerfile
    container_name: db
    restart: unless-stopped
    env_file: ./backend/.env
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - schedule-net

  # Se ejecuta UNA VEZ para poblar la DB
  initial-data:
    build:
      context: ./backend
      dockerfile: scripts.Dockerfile
    env_file: ./backend/.env
    depends_on:
      db:
        condition: service_healthy
    command: python scripts/actualizar_datos.py
    networks:
      - schedule-net

  # Actualización periódica (frecuencia reducida en desarrollo)
  cron-updater:
    build:
      context: ./backend
      dockerfile: scripts.Dockerfile
    env_file: ./backend/.env
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    command: >
      sh -c "
        apt-get update && apt-get install -y cron &&
        printenv | grep -v 'no_proxy' > /etc/environment &&
        echo '*/13 * * * * root . /etc/environment; /usr/local/bin/python /app/scripts/actualizar_datos.py >> /var/log/cron.log 2>&1' > /etc/cron.d/update-task &&
        chmod 0644 /etc/cron.d/update-task &&
        touch /var/log/cron.log &&
        cron &&
        tail -f /var/log/cron.log
      "
    networks:
      - schedule-net

volumes:
  postgres_data:

networks:
  schedule-net:
```

> **Nota:** En desarrollo no se monta el volumen de snapshots ni se programa el cron de backups, porque no necesitamos respaldos en local.

## 3. Configuración de Nginx

### `frontend/nginx.conf` (Producción — versionado en Git)

Configuración completa con HTTPS, certificados SSL de Let's Encrypt, redirección HTTP→HTTPS, y resolver DNS de Docker. **No necesitas modificar este archivo.**

### `frontend/nginx.dev.conf` (Desarrollo — ignorado por Git)

Versión simplificada que solo sirve HTTP en el puerto 80. Crea este archivo en `frontend/`:

```nginx
server {
    listen 80;
    server_name localhost;

    # Sirve los archivos estáticos de la aplicación Flutter.
    location / {
        root   /usr/share/nginx/html;
        index  index.html;
        try_files $uri $uri/ /index.html;
    }

    # Proxy para la API del backend
    location /api/ {
        proxy_pass http://api:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Diferencias con producción:**

| Aspecto | `nginx.conf` (producción) | `nginx.dev.conf` (desarrollo) |
|---------|--------------------------|-------------------------------|
| Protocolo | HTTPS (443) con redirect HTTP→HTTPS | HTTP (80) solamente |
| Certificados SSL | Let's Encrypt (`/etc/letsencrypt/...`) | Ninguno |
| Resolver DNS | `127.0.0.11` (Docker DNS) con variable | Proxy directo a `http://api:8000` |
| Server name | `horario.lab.utb.edu.co` | `localhost` |

## 4. Levantar el Entorno

### Primera vez (setup completo)

```bash
# 1. Clonar el repositorio
git clone https://github.com/ISCOUTB/DH-ScheduleGeneratorUTB.git
cd DH-ScheduleGeneratorUTB

# 2. Crear los archivos de configuración
cp backend/.env.example backend/.env
# Editar backend/.env con tus credenciales de Azure y contraseña de DB

# 3. Crear docker-compose.override.yml y nginx.dev.conf
# (ver secciones anteriores de este documento)

# 4. Levantar todo
docker compose up --build
```

La primera ejecución:
- Construye las imágenes de Docker (backend, frontend, scripts, DB).
- Inicializa la base de datos con `init.sql`.
- Ejecuta `initial-data` para poblar la DB con datos de Banner (tarda ~1-2 minutos).
- El frontend queda disponible en http://localhost.

### Ejecuciones posteriores

```bash
# Levantar sin reconstruir (más rápido)
docker compose up -d

# Reconstruir solo el backend (después de cambios en Python)
docker compose up -d --build backend

# Reconstruir solo el frontend (después de cambios en Flutter)
docker compose up -d --build frontend

# Ver logs en tiempo real
docker compose logs -f backend
docker compose logs -f frontend
```

### Acceso directo a la base de datos

```bash
# Desde el contenedor
docker exec -it db psql -U postgres -d schedules

# Desde el host (si tienes psql instalado)
psql -h localhost -p 5433 -U postgres -d schedules
```

## 5. Migraciones de Esquema

El archivo `init.sql` solo se ejecuta cuando el volumen de PostgreSQL se crea por primera vez. Si necesitas aplicar cambios de esquema sobre una base de datos existente:

```bash
# Ejecutar SQL directamente en el contenedor
docker exec -i db psql -U postgres -d schedules <<'SQL'
-- Tu SQL de migración aquí
SQL
```

> **Importante:** Si necesitas empezar desde cero (destruir datos), elimina el volumen:
> ```bash
> docker compose down -v   # ⚠️ Elimina TODOS los datos de la DB
> docker compose up --build
> ```

## 6. Troubleshooting Común

### El frontend no carga / muestra error de red
- Verifica que `nginx.dev.conf` exista y esté montado correctamente.
- Revisa que el backend esté corriendo: `docker compose logs backend`.

### Error de autenticación con Azure
- Verifica que `AZURE_REDIRECT_URI` en `.env` sea exactamente `http://localhost/api/auth/callback`.
- Confirma que el `Redirect URI` en Azure Portal coincida con el de `.env`.
- Revisa que `FRONTEND_URL` sea `http://localhost` (sin trailing slash).

### La DB no tiene datos (tablas vacías)
- El servicio `initial-data` solo corre una vez. Si falló, ejecútalo de nuevo:
  ```bash
  docker compose run --rm initial-data
  ```

### Cambios en `init.sql` no se reflejan
- Ver sección de [Migraciones de Esquema](#5-migraciones-de-esquema). El archivo solo se ejecuta al crear el volumen por primera vez.
