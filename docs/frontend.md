# Documentación del Frontend

## 1. Visión General

El frontend es una aplicación web construida con **Flutter**, el framework de Google para desarrollo multiplataforma. Aunque Flutter permite compilar para móvil, escritorio y web, esta aplicación está optimizada principalmente para navegadores web.

### Tecnologías Principales

| Tecnología | Propósito |
|------------|-----------|
| **Flutter 3** | Framework de UI |
| **Dart** | Lenguaje de programación |
| **Firebase Analytics** | Análisis de uso |
| **Nginx** | Servidor web para producción |

## 2. Estructura del Proyecto

```
frontend/lib/
├── main.dart                 # Punto de entrada y lógica principal
├── firebase_options.dart     # Configuración de Firebase
│
├── models/                   # Modelos de datos
│   ├── subject.dart          # Materia completa con opciones de clase
│   ├── subject_summary.dart  # Resumen de materia (búsqueda)
│   ├── class_option.dart     # Opción de clase individual
│   └── schedule.dart         # Bloque horario (día + hora)
│
├── services/                 # Servicios y comunicación
│   └── api_service.dart      # Cliente HTTP para la API
│
├── widgets/                  # Componentes de UI reutilizables
│   ├── search_widget.dart    # Buscador de materias
│   ├── subjects_panel.dart   # Panel de materias seleccionadas
│   ├── schedule_grid_widget.dart    # Grilla de horario semanal
│   ├── filter_widget.dart           # Panel de filtros
│   ├── professor_filter_widget.dart # Filtro de profesores
│   ├── schedule_overview_widget.dart # Vista resumen de horarios
│   ├── schedule_sort_widget.dart    # Ordenamiento de horarios
│   └── main_actions_panel.dart      # Botones de acción principales
│
└── utils/                    # Utilidades
    ├── platform_service_stub.dart   # Servicio de plataforma (stub)
    └── platform_service_web.dart    # Servicio de plataforma (web)
```

## 3. Arquitectura de la Aplicación

### Flujo de Datos

```
┌─────────────────────────────────────────────────────────────┐
│                         main.dart                           │
│                    (Estado Principal)                       │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Materias    │    │ Filtros     │    │ Horarios    │     │
│  │ Selec.      │    │ Aplicados   │    │ Generados   │     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            ▼                                │
│                    ┌───────────────┐                        │
│                    │  ApiService   │                        │
│                    └───────┬───────┘                        │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             ▼
                    ┌───────────────┐
                    │   Backend     │
                    │   (FastAPI)   │
                    └───────────────┘
```

### Gestión de Estado

La aplicación utiliza `StatefulWidget` con el estado centralizado en `_MyHomePageState`. Las principales variables de estado son:

```dart
// Materias seleccionadas por el usuario
List<Subject> addedSubjects = [];

// Horarios generados por la API
List<List<ClassOption>> allSchedules = [];

// Filtros aplicados
Map<String, dynamic> appliedFilters = {};

// Control de créditos
int usedCredits = 0;
final int creditLimit = 20;
```

## 4. Modelos de Datos

### Subject
Representa una materia completa con todas sus opciones de clase:

```dart
class Subject {
  final String code;      // Código (ej: "IING1011")
  final String name;      // Nombre (ej: "CÁLCULO I")
  final int credits;      // Créditos académicos
  final List<ClassOption> classOptions; // Grupos disponibles
}
```

### SubjectSummary
Versión ligera para el buscador:

```dart
class SubjectSummary {
  final String code;
  final String name;
  final int credits;
}
```

### ClassOption
Representa una opción de clase específica (un grupo):

```dart
class ClassOption {
  final String subjectName;
  final String subjectCode;
  final String type;           // "Teórico", "Laboratorio", "Teorico-practico"
  final String nrc;
  final int groupId;
  final String professor;
  final String campus;
  final int seatsAvailable;
  final int seatsMaximum;
  final int credits;
  final List<Schedule> schedules;
}
```

### Schedule
Bloque horario:

```dart
class Schedule {
  final String day;   // "Lunes", "Martes", etc.
  final String time;  // "08:00 - 10:00"
}
```

## 5. Componentes Principales

### SearchWidget
Diálogo modal para buscar y seleccionar materias:
- Búsqueda en tiempo real por nombre o código
- Normalización de acentos para búsqueda flexible
- Muestra código, nombre y créditos de cada materia

### SubjectsPanel
Panel lateral que muestra las materias seleccionadas:
- Lista de materias con colores asignados
- Contador de créditos usados vs límite
- Botón para eliminar materias

### ScheduleGridWidget
Grilla visual del horario semanal:
- Visualización de lunes a sábado
- Bloques de colores por materia
- Información del profesor y aula

### FilterWidget
Panel de configuración de filtros:
- Filtros por rango de horas
- Exclusión de profesores
- Opciones de optimización

### ScheduleOverviewWidget
Vista resumen de todos los horarios generados:
- Navegación entre horarios
- Vista compacta para comparar opciones

## 6. Servicio de API

El `ApiService` centraliza la comunicación con el backend:

```dart
class ApiService {
  static const String _baseUrl = "http://localhost:8000";

  // Obtiene lista resumida de todas las materias
  Future<List<SubjectSummary>> getAllSubjects();

  // Obtiene detalles completos de una materia
  Future<Subject> getSubjectDetails(String code, String name);

  // Genera horarios válidos
  Future<List<List<ClassOption>>> generateSchedules({
    required List<Subject> subjects,
    required Map<String, dynamic> filters,
    required int creditLimit,
  });
}
```

### Configuración de URL Base

Para desarrollo local:
```dart
static const String _baseUrl = "http://localhost:8000";
```

Para producción (usa el proxy de Nginx):
```dart
static const String _baseUrl = "";  // Peticiones relativas
```

## 7. Configuración de Nginx

### Desarrollo (`nginx.dev.conf`)
Configuración simplificada sin SSL:
```nginx
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://api:8000;
    }
}
```

### Producción (`nginx.conf`)
Configuración completa con HTTPS y certificados SSL de Let's Encrypt.

## 8. Flujo de Usuario

1. **Carga inicial:** Al abrir la app, se cargan todas las materias disponibles desde `/api/subjects`.

2. **Búsqueda de materias:** El usuario abre el buscador y filtra por nombre o código.

3. **Selección:** Al seleccionar una materia, se obtienen sus detalles completos desde `/api/subjects/{code}`.

4. **Configuración de filtros:** El usuario puede configurar restricciones de horario y profesores.

5. **Generación:** Al presionar "Generar", se envía la petición a `/api/schedules/generate`.

6. **Visualización:** Los horarios se muestran en la grilla y el usuario puede navegar entre opciones.

7. **Exportación:** El usuario puede descargar el horario seleccionado en PDF.

## 9. Desarrollo Local

### Requisitos
- Flutter SDK 3.x
- Dart SDK >=2.17.0

### Ejecutar en modo desarrollo

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### Compilar para producción

```bash
flutter build web --release
```

Los archivos compilados se generan en `build/web/`.

## 10. Dependencias Principales

Del `pubspec.yaml`:

| Paquete | Propósito |
|---------|-----------|
| `http` | Cliente HTTP para API |
| `pdf` | Generación de PDFs |
| `firebase_core` | Integración Firebase |
| `firebase_analytics` | Analytics |
| `url_launcher` | Abrir URLs externas |
| `diacritic` | Normalización de acentos |
| `flutter_svg` | Renderizado de SVGs |
