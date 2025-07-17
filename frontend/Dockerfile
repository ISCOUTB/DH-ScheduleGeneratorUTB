# docker-compose.yml
# --- Compilación de Flutter ---
FROM instrumentisto/flutter:3 AS builder

# Copia el código fuente del frontend.
WORKDIR /app
COPY . .

# Instala las dependencias.
RUN flutter pub get

# Se declara un argumento que se puede pasar desde docker-compose.
# Este será el URL de nuestra API de backend.
ARG API_URL

# Se compila la aplicación web para producción.
# Se usa --dart-define para inyectar la variable API_URL en el código Dart.
RUN flutter build web --release --dart-define=API_URL=${API_URL}


# --- Servidor Web Nginx ---
FROM nginx:1.29.0-alpine

# Copiamos los archivos web compilados desde la etapa 'builder'.
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copiamos nuestro archivo de configuración de Nginx.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponemos el puerto 80 para el tráfico web.
EXPOSE 80