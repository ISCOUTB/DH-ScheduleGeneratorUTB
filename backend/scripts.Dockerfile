# scripts.Dockerfile
FROM python:3.13.5-slim

# Previene que Python genere archivos .pyc y aseguramos que los logs se vean en tiempo real.
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Instala el cliente de PostgreSQL para tener acceso a pg_dump
RUN apt-get update && apt-get install -y postgresql-client && rm -rf /var/lib/apt/lists/*

# Establece el directorio de trabajo dentro del contenedor.
WORKDIR /app

# Copia solo el archivo de requisitos para aprovechar el caché de Docker.
COPY requirements.txt .

# Instala las dependencias de Python.
RUN pip install --no-cache-dir -r requirements.txt

# Copia todo el contenido del backend (la app y los scripts).
COPY . .