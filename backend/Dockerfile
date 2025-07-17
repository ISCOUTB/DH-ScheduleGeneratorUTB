# Dockerfile para el backend de la aplicación FastAPI
FROM python:3.13.5-slim

# Establece el directorio de trabajo dentro del contenedor.
WORKDIR /app

# Copia primero el archivo de requerimientos para aprovechar el cache de Docker.
# Si este archivo no cambia, Docker no volverá a instalar las dependencias.
COPY requirements.txt .

# Instala las dependencias de Python.
RUN pip install --no-cache-dir -r requirements.txt

# Copia todo el código de la aplicación.
COPY ./app /app/app

# Expone el puerto en el que correrá la API dentro del contenedor.
EXPOSE 8000

# Comando para iniciar la aplicación usando Uvicorn.
# --host 0.0.0.0 para que sea accesible desde fuera del contenedor.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]