# docker-compose.yml
FROM instrumentisto/flutter:3 AS builder

# Copiamos el código fuente del frontend.
WORKDIR /app
COPY . .

# Instalamos las dependencias.
RUN flutter pub get

# Compilamos la aplicación web para producción.
RUN flutter build web --release


FROM nginx:1.29.0-alpine

# Copiamos los archivos web compilados desde la etapa 'builder'.
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copiamos nuestro archivo de configuración de Nginx.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponemos el puerto 80 para el tráfico web.
EXPOSE 80