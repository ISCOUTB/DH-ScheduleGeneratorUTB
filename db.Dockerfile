FROM postgres:15-alpine

# Instala los paquetes de localización (icu-libs es suficiente)
RUN apk add --no-cache icu-libs

# Establece las variables de entorno para que PostgreSQL las use
ENV LANG=en_US.UTF-8
ENV LC_ALL?=en_US.UTF-8