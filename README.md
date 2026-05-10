# DH-ScheduleGeneratorUTB

Generador de horarios académicos para estudiantes de la Universidad Tecnológica de Bolívar (UTB). Esta aplicación permite a los estudiantes seleccionar las materias que desean cursar y genera automáticamente todas las combinaciones de horarios posibles, aplicando filtros y optimizaciones según las preferencias del usuario.

🔗 **Aplicación en producción:** [horario.lab.utb.edu.co](https://horario.lab.utb.edu.co)

## Tabla de Contenidos

- [Características](#características)
- [Arquitectura del Proyecto](#arquitectura-del-proyecto)
- [Tecnologías Utilizadas](#tecnologías-utilizadas)
- [Instalación y Despliegue](#instalación-y-despliegue)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Documentación Adicional](#documentación-adicional)
- [Contribuciones](#contribuciones)
- [Licencia](#licencia)

## Características

- **Autenticación segura:** Inicio de sesión con Microsoft Entra ID (Azure AD) para usuarios institucionales.
- **Búsqueda de materias:** Busca y selecciona materias por código o nombre.
- **Generación automática de horarios:** Algoritmo de backtracking que encuentra todas las combinaciones válidas sin conflictos de horario.
- **Filtros avanzados:**
  - Exclusión de profesores específicos.
  - Restricción por rango de horas (evitar clases muy temprano o muy tarde).
  - Límite de créditos por semestre.
- **Optimización de horarios:**
  - Maximizar días libres.
  - Minimizar huecos entre clases.
- **Visualización interactiva:** Vista de grilla semanal con los horarios generados.
- **Exportación:** Descarga de horarios en formato PDF.
- **Datos actualizados:** Sincronización automática con el sistema Banner de la universidad con alta frecuencia (cada 10 minutos en producción) para garantizar la frescura de la información sin afectar el historial de las preferencias de usuarios.
- **Respaldo funcional:** Backups automáticos de la información de los usuarios cada 4 horas con retención extendida de historial físico frente a caídas.

## Arquitectura del Proyecto

El proyecto sigue una arquitectura de microservicios contenerizados con Docker:

```
┌─────────────────────────────────────────────────────────────────────┐
│                              NGINX                                  │
│                    (Reverse Proxy + SSL)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    ┌──────────────────┐              ┌──────────────────┐          │
│    │     Frontend     │              │     Backend      │          │
│    │  (Flutter Web)   │◄────────────►│   (FastAPI)      │          │
│    │                  │   /api/*     │                  │          │
│    └──────────────────┘              └────────┬─────────┘          │
│                                               │                     │
│                                               ▼                     │
│                                      ┌──────────────────┐          │
│                                      │   PostgreSQL     │          │
│                                      │   (Base de Datos)│          │
│                                      └────────▲─────────┘          │
│                                               │                     │
│                                      ┌────────┴─────────┐          │
│                                      │   Cron Updater   │          │
│                                      │ (Actualización   │          │
│                                      │   automática)    │          │
│                                      └──────────────────┘          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Tecnologías Utilizadas

### Backend
- **Python 3.13**
- **FastAPI** - Framework web de alto rendimiento
- **PostgreSQL** - Base de datos relacional
- **psycopg3** - Driver de PostgreSQL para Python
- **Pydantic** - Validación de datos
- **python-jose** - Decodificación de JWT (tokens de Entra ID)
- **httpx** - Cliente HTTP asíncrono para flujo OAuth

### Frontend
- **Flutter 3** - Framework de UI multiplataforma
- **Dart** - Lenguaje de programación
- **Firebase Analytics** - Análisis de uso

### Infraestructura
- **Docker & Docker Compose** - Contenerización y orquestación
- **Nginx** - Servidor web y reverse proxy
- **Let's Encrypt** - Certificados SSL

## Instalación y Despliegue

### Requisitos Previos

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

### Despliegue Local (Desarrollo)

1. **Clona el repositorio:**
   ```bash
   git clone https://github.com/ISCOUTB/DH-ScheduleGeneratorUTB.git
   cd DH-ScheduleGeneratorUTB
   ```

2. **Configura las variables de entorno:**
   
   Copia el archivo de ejemplo y configúralo:
   ```bash
   cp backend/.env.example backend/.env
   ```
   
   Edita `backend/.env` con tus valores:
   ```env
   # Base de datos
   POSTGRES_USER=tu_usuario
   POSTGRES_PASSWORD=tu_contraseña
   POSTGRES_DB=schedule_db
   DATABASE_URL=postgresql://tu_usuario:tu_contraseña@db:5432/schedule_db
   
   # Autenticación Microsoft Entra ID (Azure AD)
   AZURE_TENANT_ID=tu_tenant_id
   AZURE_CLIENT_ID=tu_client_id
   AZURE_CLIENT_SECRET=tu_client_secret
   AZURE_REDIRECT_URI=http://localhost/api/auth/callback
   FRONTEND_URL=http://localhost
   AZURE_ALLOWED_TENANTS=tu_tenant_id
   ```
   
   > 📝 Para obtener las credenciales de Azure, ve a [Azure Portal](https://portal.azure.com) > App registrations.

3. **Levanta los servicios:**
   ```bash
   docker-compose up --build
   ```

   > Docker Compose automáticamente utiliza `docker-compose.override.yml` para configuraciones de desarrollo (HTTP sin SSL, configuración de Nginx simplificada).

4. **Accede a la aplicación:**
   - Frontend: http://localhost
   - API Docs (Swagger): http://localhost/api/docs

### Despliegue en Producción

Para producción, usa únicamente el archivo base:

```bash
docker-compose -f docker-compose.yml up --build -d
```

Esto habilita:
- HTTPS con certificados Let's Encrypt
- Renovación automática de certificados
- Configuración de Nginx optimizada para producción

### Verificar Configuración

Para ver la configuración final que Docker Compose utilizará:
```bash
docker-compose config
```

## Estructura del Proyecto

```
DH-ScheduleGeneratorUTB/
├── backend/                    # API y lógica del servidor
│   ├── app/                    # Código fuente de FastAPI
│   │   ├── main.py             # Punto de entrada de la API
│   │   ├── models.py           # Modelos Pydantic
│   │   ├── auth/               # Autenticación OAuth con Microsoft Entra ID
│   │   │   └── routes.py       # Flujo OAuth con PKCE
│   │   ├── db/                 # Capa de acceso a datos
│   │   │   └── repository.py
│   │   ├── routes/             # Rutas modulares
│   │   │   └── subject_routes.py
│   │   └── services/           # Lógica de negocio
│   │       └── schedule_generator.py
│   ├── scripts/                # Scripts de actualización y mantenimiento
│   │   ├── actualizar_datos.py # Orquestador del pipeline ETL
│   │   ├── descargar_json.py   # Web scraping de Banner
│   │   ├── parser.py           # Procesamiento de datos
│   │   ├── insertar_en_db.py   # Carga en PostgreSQL
│   │   ├── backup.py           # Respaldos periódicos de datos de usuario
│   │   ├── rescatador.py       # Recuperación de secciones ligadas
│   │   ├── config.py           # Configuración compartida de scripts
│   │   └── utils.py            # Utilidades compartidas
│   ├── Dockerfile              # Imagen Docker de la API
│   ├── scripts.Dockerfile      # Imagen Docker para scripts ETL y backups
│   ├── requirements.txt
│   └── init.sql                # Esquema inicial de la BD
│
├── frontend/                   # Aplicación Flutter
│   ├── lib/                    # Código fuente Dart
│   │   ├── main.dart           # Punto de entrada
│   │   ├── models/             # Modelos de datos
│   │   ├── providers/          # Manejo de estado (Provider)
│   │   ├── screens/            # Pantallas principales
│   │   ├── services/           # Servicios (API, Auth)
│   │   ├── widgets/            # Componentes de UI
│   │   └── utils/              # Utilidades
│   ├── Dockerfile
│   ├── nginx.conf              # Configuración Nginx (producción)
│   ├── nginx.dev.conf          # Configuración Nginx (desarrollo)
│   └── pubspec.yaml
│
├── docs/                       # Documentación adicional
│   ├── backend.md              # Documentación del backend
│   ├── frontend.md             # Documentación del frontend
│   ├── modelo_datos.md         # Modelo de datos
│   └── issues/                 # Registros técnicos de decisiones
│
├── tests/                      # Tests del backend
│
├── docker-compose.yml          # Configuración Docker (producción)
├── docker-compose.override.yml # Sobrescritura para desarrollo
└── README.md
```

## Documentación Adicional

- [Documentación del Backend](./docs/backend.md) - Arquitectura, endpoints y flujo de datos.
- [Modelo de Datos](./docs/modelo_datos.md) - Esquema de la base de datos.
- [Documentación del Frontend](./docs/frontend.md) - Arquitectura y componentes de la UI.

## API Endpoints

### Materias y Horarios

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/subjects` | Lista todas las materias disponibles |
| `GET` | `/api/subjects/{code}?name=...` | Obtiene detalles de una materia por código y nombre |
| `POST` | `/api/schedules/generate` | Genera horarios válidos |

### Autenticación (Microsoft Entra ID)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/auth/login` | Inicia flujo OAuth (redirige a Microsoft) |
| `GET` | `/api/auth/callback` | Callback de Microsoft tras autenticación |
| `GET` | `/api/auth/me` | Retorna información del usuario autenticado |
| `POST` | `/api/auth/logout` | Cierra sesión del usuario |

Para documentación interactiva completa, accede a `/api/docs` cuando la API esté corriendo.

## Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Haz fork del repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Haz commit de tus cambios (`git commit -m 'Añadir nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## Licencia

Este proyecto está desarrollado por estudiantes de la Universidad Tecnológica de Bolívar como parte del programa de Ingeniería de Sistemas.
