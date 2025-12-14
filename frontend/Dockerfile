# --- Compilación de Flutter ---
# Usar versión específica para evitar descargas innecesarias
FROM instrumentisto/flutter:3.38.4 AS builder

WORKDIR /app

# Primero copiar SOLO los archivos de dependencias
# Esto permite que Docker cachée las dependencias si no cambian
COPY pubspec.yaml pubspec.lock* ./

# Instalar dependencias (se cachea si pubspec no cambia)
RUN flutter pub get

# Ahora copiar el resto del código
COPY . .

# Compilar la aplicación web
RUN flutter build web --release


# --- Servidor Web Nginx ---
FROM nginx:1.29.0-alpine

# Copia los archivos web compilados desde la etapa 'builder'.
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
EXPOSE 443