# docker-compose.yml
# --- Compilación de Flutter ---
FROM instrumentisto/flutter:3 AS builder

# Copia el código fuente del frontend.
WORKDIR /app
COPY . .

# Instala las dependencias.
RUN flutter pub get
RUN flutter build web --release


# --- Servidor Web Nginx ---
FROM nginx:1.29.0-alpine

# Copia los archivos web compilados desde la etapa 'builder'.
COPY --from=builder /app/build/web /usr/share/nginx/html

# Ya no copiamos nginx.conf aquí, se monta como volumen.
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
EXPOSE 443