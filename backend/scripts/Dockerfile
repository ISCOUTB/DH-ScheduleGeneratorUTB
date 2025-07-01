FROM python:3.11-slim

WORKDIR /app

COPY . .
COPY ../.env /app/.env

# Instalar cron, pg_dump y herramientas útiles
RUN apt-get update && \
    apt-get install -y \
    cron \
    nano \
    postgresql-client \
    procps \
    vim \
    && pip install --no-cache-dir requests psycopg[binary] \
    && rm -rf /var/lib/apt/lists/*

# Dar permisos de ejecución al runner
RUN chmod +x /app/cron_runner.sh

# Copiar y registrar el cronjob
RUN chmod 0644 /app/backend_cronjob && \
    crontab /app/backend_cronjob

# Ejecutar el script una vez al inicio y luego iniciar cron
CMD ["/bin/bash", "-c", "/app/cron_runner.sh && cron -f"]