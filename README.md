<div align="center">

# 📅 DH Schedule Generator UTB

**Generador de horarios académicos para la Universidad Tecnológica de Bolívar.**
Selecciona tus materias y obtén automáticamente todas las combinaciones de horario válidas, con filtros, optimizaciones y horarios destacados.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python%203.13-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org)

### 🔗 [**Abrir la app en producción → horario.lab.utb.edu.co**](https://horario.lab.utb.edu.co)

</div>

---

## ✨ Características

- 🔐 **Autenticación segura** — Inicio de sesión con Microsoft Entra ID (Azure AD) para usuarios institucionales.
- 🔍 **Búsqueda de materias** — Encuentra y selecciona materias por código o nombre (búsqueda por palabras).
- ⚙️ **Generación automática** — Algoritmo de *backtracking* que encuentra todas las combinaciones válidas sin cruces.
- 🎯 **Filtros avanzados** — Excluir profesores, restringir rangos de horas y límite de créditos por semestre.
- 🧠 **Optimización** — Maximizar días libres y minimizar huecos entre clases.
- ⭐ **Horarios destacados** — Guarda tus horarios favoritos y revisa el **estado de cupos** en vivo (🟢 seguro / 🟡 precaución / 🔴 en riesgo / ⚫ eliminado).
- 🎨 **Visualización interactiva** — Grilla semanal con código de colores.
- 📄 **Exportación** — Descarga de horarios en PDF.
- 📱 **Multiplataforma** — Web, móvil y escritorio, con layout responsivo.
- 🔄 **Datos siempre frescos** — Sincronización automática con el sistema Banner de la UTB (cada ~10 min en producción).
- 💾 **Respaldos** — Backups automáticos de los datos de usuario cada 4 horas.

## 🏗️ Arquitectura

Microservicios contenerizados con Docker, detrás de un único Nginx (reverse proxy + SSL):

```
┌─────────────────────────────────────────────────────────────────────┐
│                              NGINX                                    │
│                    (Reverse Proxy + SSL)                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│    ┌──────────────────┐              ┌──────────────────┐            │
│    │     Frontend     │              │     Backend      │            │
│    │  (Flutter Web)   │◄────────────►│    (FastAPI)     │            │
│    │                  │   /api/*     │                  │            │
│    └──────────────────┘              └────────┬─────────┘            │
│                                               │                       │
│                                               ▼                       │
│                                      ┌──────────────────┐            │
│                                      │   PostgreSQL     │            │
│                                      │  (Base de Datos) │            │
│                                      └────────▲─────────┘            │
│                                               │                       │
│                                      ┌────────┴─────────┐            │
│                                      │   Cron Updater   │            │
│                                      │  (ETL Banner +   │            │
│                                      │     backups)     │            │
│                                      └──────────────────┘            │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

## 🛠️ Tecnologías

| Capa | Stack |
|------|-------|
| 🎨 **Frontend** | Flutter 3 · Dart · Provider · Firebase Analytics |
| ⚡ **Backend** | Python 3.13 · FastAPI · Pydantic · psycopg3 · python-jose · httpx |
| 🗄️ **Datos** | PostgreSQL |
| 📦 **Infra** | Docker & Docker Compose · Nginx · Let's Encrypt (SSL) |
| 🔄 **CI/CD** | GitHub Actions (build + deploy por SSH a la VM) |

## 🚀 Instalación y Despliegue

### 📋 Requisitos

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)

### 💻 Desarrollo local

```bash
# 1. Clonar
git clone https://github.com/ISCOUTB/DH-ScheduleGeneratorUTB.git
cd DH-ScheduleGeneratorUTB

# 2. Configurar archivos ignorados por Git (ver guía 👇)
cp backend/.env.example backend/.env     # editar con tus credenciales
#   + docker-compose.override.yml y frontend/nginx.dev.conf (ver guía)

# 3. Levantar todo
docker compose up --build
```

- 🖥️ Frontend → http://localhost
- 📚 API Docs (Swagger) → http://localhost/api/docs

> 📖 La estructura y contenido de los archivos de desarrollo está en la **[Guía de Desarrollo Local](./docs/desarrollo-local.md)**.

> ⚡ **¿Solo cambias la interfaz?** No reconstruyas la imagen del frontend (tarda minutos). Compila Flutter con *hot reload*: `cd frontend && flutter run -d chrome --dart-define=DEV_SKIP_AUTH=true` (UI pura) o `./scripts/dev-frontend.sh` (UI con datos reales, login y favoritos). Ver [Desarrollo Rápido de Interfaz](./docs/desarrollo-local.md#7-desarrollo-rápido-de-interfaz-sin-reconstruir-el-frontend).

### ☁️ Producción

Solo el archivo base (HTTPS + Let's Encrypt + Nginx de producción):

```bash
docker compose -f docker-compose.yml up --build -d
```

El despliegue es automático: cada **push a `master`** dispara el workflow de GitHub Actions que reconstruye y publica en la VM.

## 🔌 API Endpoints

### 📚 Materias y horarios

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/subjects` | Lista todas las materias disponibles |
| `GET` | `/api/subjects/{code}?name=...` | Detalles de una materia |
| `POST` | `/api/schedules/generate` | Genera horarios válidos (devuelve `{ schedules, truncated }`) |

### 🔐 Autenticación (Microsoft Entra ID)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/auth/login` | Inicia el flujo OAuth (redirige a Microsoft) |
| `GET` | `/api/auth/callback` | Callback tras autenticación |
| `GET` | `/api/auth/me` | Usuario autenticado |
| `POST` | `/api/auth/logout` | Cierra sesión |

### ⭐ Horarios destacados (favoritos)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/favorites?term=202610` | Favoritos del usuario para un término |
| `GET` | `/api/favorites/terms` | Términos con favoritos + término actual |
| `GET` | `/api/favorites/status?nrcs=...` | Estado de cupos actuales de una lista de NRCs |
| `POST` | `/api/favorites` | Guarda un horario destacado |
| `DELETE` | `/api/favorites/{id}` | Elimina un horario destacado |

> 🗓️ El período académico actual se define con `CURRENT_TERM` en `backend/.env`. Documentación interactiva completa en `/api/docs`.

## 📁 Estructura del Proyecto

```
DH-ScheduleGeneratorUTB/
├── 📂 backend/                  # API y lógica del servidor (FastAPI)
│   ├── app/
│   │   ├── main.py              # Punto de entrada de la API
│   │   ├── models.py            # Modelos Pydantic
│   │   ├── auth/                # OAuth con Microsoft Entra ID (PKCE)
│   │   ├── db/repository.py     # Acceso a datos (psycopg)
│   │   ├── routes/              # Rutas (materias, favoritos)
│   │   └── services/            # Generador de horarios (backtracking)
│   ├── scripts/                 # ETL de Banner, backups y mantenimiento
│   ├── Dockerfile · scripts.Dockerfile
│   └── init.sql                 # Esquema inicial de la BD
│
├── 📂 frontend/                 # Aplicación Flutter (Web/Mobile/Desktop)
│   ├── lib/
│   │   ├── models/ · providers/ · screens/ · services/ · widgets/ · utils/
│   │   └── main.dart
│   ├── nginx.conf               # Nginx de producción
│   └── pubspec.yaml
│
├── 📂 docs/                     # Documentación (backend, frontend, RFCs)
├── 📂 scripts/                  # Atajos de desarrollo (dev-frontend.sh/.ps1)
├── 📂 tests/                    # Tests del backend
├── 🐳 docker-compose.yml        # Producción
└── 🐳 docker-compose.override.yml  # Desarrollo (HTTP, sin SSL)
```

## 📚 Documentación

| Documento | Descripción |
|-----------|-------------|
| 🧰 [Desarrollo Local](./docs/desarrollo-local.md) | Setup del entorno, archivos ignorados, iteración rápida y troubleshooting |
| ⚙️ [Backend](./docs/backend.md) | Arquitectura, endpoints y flujo de datos |
| 🎨 [Frontend](./docs/frontend.md) | Arquitectura y componentes de la UI |
| 🗃️ [Modelo de Datos](./docs/modelo_datos.md) | Esquema de la base de datos |
| 📝 [Decisiones técnicas (RFCs)](./docs/issues/) | Registros de diseño e historia del proyecto |

## 🤝 Contribuciones

¡Bienvenidas! 🎉

1. 🍴 Haz fork del repositorio
2. 🌿 Crea una rama (`git checkout -b feature/nueva-funcionalidad`)
3. 💾 Commitea tus cambios (`git commit -m 'feat: nueva funcionalidad'`)
4. 🚀 Push a tu rama (`git push origin feature/nueva-funcionalidad`)
5. 🔁 Abre un Pull Request

## 📄 Licencia

Desarrollado por estudiantes de **Ingeniería de Sistemas** de la Universidad Tecnológica de Bolívar.

---

<div align="center">
  <sub>Hecho con ❤️ para los estudiantes de la UTB</sub>
</div>
