#!/bin/bash

# Cargar variables de entorno desde el archivo .env
set -o allexport
source /app/.env
set +o allexport
#cambio
# Situarse en la carpeta destino
cd /app

# Ejecutar el script y redirigir salida a log
/usr/local/bin/python /app/actualizar_datos.py >> /var/log/cron.log 2>&1
