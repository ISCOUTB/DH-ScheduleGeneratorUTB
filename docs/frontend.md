# Documentacion del Frontend

## 1. Vision General

El frontend es una aplicacion web construida con **Flutter 3**, optimizada para navegadores web. Implementa autenticacion con **Microsoft Entra ID** (Azure AD) y utiliza el patron **Provider** para manejo de estado.

### Tecnologias Principales

| Tecnologia | Proposito |
|------------|-----------|
| **Flutter 3.38+** | Framework de UI multiplataforma |
| **Dart** | Lenguaje de programacion |
| **Provider** | Manejo de estado reactivo |
| **Firebase Analytics** | Analisis de uso |
| **BrowserClient** | Peticiones HTTP con soporte de cookies |
| **Nginx** | Servidor web para produccion |

## 2. Estructura del Proyecto

`
frontend/lib/
+-- main.dart                 # Punto de entrada, autenticacion y configuracion
+-- firebase_options.dart     # Configuracion de Firebase (autogenerado)
|
+-- config/                   # Configuracion global
|   +-- constants.dart        # Constantes (colores, breakpoints, URLs)
|   +-- theme.dart            # Tema visual (AppTheme, WebScrollBehavior)
|
+-- models/                   # Modelos de datos
|   +-- user.dart             # Usuario autenticado (Microsoft Entra ID)
|   +-- subject.dart          # Materia con opciones de clase
|   +-- subject_summary.dart  # Resumen ligero de materia
|   +-- class_option.dart     # Opcion de clase individual
|   +-- schedule.dart         # Bloque horario (dia + hora)
|
+-- providers/                # Proveedores de estado (ChangeNotifier)
|   +-- schedule_provider.dart # Estado global de materias, horarios y filtros
|
+-- screens/                  # Pantallas principales
|   +-- home_screen.dart      # Pantalla principal con toda la funcionalidad
|
+-- services/                 # Servicios para comunicacion externa
|   +-- auth_service.dart     # Autenticacion OAuth con Microsoft Entra ID
|   +-- api_service.dart      # Comunicacion con API del backend
|
+-- utils/                    # Utilidades y helpers
|   +-- time_utils.dart       # Conversion de tiempos (militar a AM/PM)
|   +-- file_utils*.dart      # Exportacion de archivos (web/mobile/stub)
|   +-- platform_service*.dart # Deteccion de plataforma (web/stub)
|   +-- storage_permissions.dart # Permisos de almacenamiento
|
+-- widgets/                  # Componentes de UI
    +-- search_widget.dart           # Buscador de materias
    +-- filter_widget.dart           # Panel de filtros
    +-- subjects_panel.dart          # Panel de materias seleccionadas
    +-- main_actions_panel.dart      # Acciones principales
    +-- schedule_grid_widget.dart    # Grilla visual del horario
    +-- schedule_overview_widget.dart # Resumen del horario
    +-- schedule_sort_widget.dart    # Ordenamiento de horarios
    +-- professor_filter_widget.dart # Filtro por profesor
    |
    +-- common/               # Widgets comunes reutilizables
    |   +-- common.dart       # Barrel export
    |   +-- nav_link.dart     # Enlaces de navegacion
    |   +-- loading_overlay.dart # Overlay de carga
    |   +-- custom_notification.dart # Notificaciones
    |
    +-- dialogs/              # Dialogos modales
    |   +-- dialogs.dart      # Barrel export
    |   +-- creators_dialog.dart  # Dialogo de creadores
    |   +-- clear_confirmation_dialog.dart # Confirmacion
    |   +-- important_notice_dialog.dart   # Avisos
    |
    +-- layout/               # Componentes de layout
        +-- layout.dart       # Barrel export
        +-- mobile_menu.dart  # Menu para movil
        +-- speed_dial_menu.dart   # Menu flotante (FAB)
        +-- user_info_badge.dart   # Badge de usuario
        +-- pagination_control.dart # Paginacion
        +-- schedule_counter_badge.dart # Contador
`

## 3. Flujo de Autenticacion

La autenticacion utiliza **Microsoft Entra ID** con flujo OAuth manejado por el backend:

1. Flutter llama a `/api/auth/me` para verificar sesion
2. Si no hay sesion (401), redirige a `/api/auth/login`
3. Backend redirige a Microsoft para autenticacion
4. Microsoft retorna con codigo de autorizacion
5. Backend intercambia codigo por tokens
6. Backend crea sesion y establece cookie `session_id`
7. Flutter recibe cookie y accede a la aplicacion

### Consideraciones Importantes

1. **BrowserClient con withCredentials**: En Flutter Web, `http.get/post` no envia cookies automaticamente. Se usa `BrowserClient` con `withCredentials = true`.

2. **Un solo MaterialApp**: Se mantiene un unico `MaterialApp` para evitar problemas de reconstruccion del arbol de widgets.

3. **Tipo de ID**: El ID de Microsoft Entra es un UUID (String), no un entero.

## 4. Manejo de Estado con Provider

El estado global se maneja con `ScheduleProvider`:

`dart
class ScheduleProvider extends ChangeNotifier {
  // Materias
  List<SubjectSummary> _allSubjects = [];
  List<Subject> _selectedSubjects = [];
  
  // Horarios generados
  List<List<ClassOption>> _allSchedules = [];
  int _currentScheduleIndex = 0;
  
  // Filtros
  Map<String, dynamic> _filters = {...};
  
  // Estados de UI
  bool _isLoading = false;
  bool _isSearchOpen = false;
  bool _isFilterOpen = false;
}
`

## 5. Servicios

### AuthService
Maneja autenticacion OAuth:
- `checkSession()`: Verifica sesion activa via cookie
- `login()`: Redirige a Microsoft para autenticacion
- `logout()`: Cierra sesion y redirige

### ApiService
Comunicacion con el backend:
- `getAllSubjects()`: Lista de materias disponibles
- `getSubjectDetails(code, name)`: Detalles de una materia
- `generateSchedules(subjects, filters, creditLimit)`: Genera horarios

Ambos servicios usan `BrowserClient` con `withCredentials = true`.

## 6. Modelos de Datos

### User
`dart
class User {
  final String id;    // UUID de Microsoft Entra ID
  final String email;
  final String? nombre;
  final bool authenticated;
}
`

### Subject
`dart
class Subject {
  final String code;
  final String name;
  final int credits;
  final List<ClassOption> classOptions;
}
`

### ClassOption
`dart
class ClassOption {
  final String subjectName;
  final String subjectCode;
  final String type;       // Teorico, Laboratorio, etc.
  final String nrc;
  final int groupId;
  final String professor;
  final String campus;
  final int seatsAvailable;
  final int seatsMaximum;
  final int credits;
  final List<Schedule> schedules;
}
`

## 7. Compilacion y Despliegue

### Desarrollo local:
`ash
flutter run -d chrome
`

### Produccion (Docker):
`ash
docker-compose up --build frontend -d
`

El Dockerfile usa multi-stage build:
1. **Stage 1 (builder)**: Imagen de Flutter para compilar
2. **Stage 2 (runtime)**: Imagen de Nginx para servir archivos

## 8. Refactorizacion Realizada

### Resumen del cambio
El archivo `main.dart` paso de **1677 lineas** a **112 lineas** mediante:

| Componente | Antes | Despues |
|------------|-------|---------|
| main.dart | 1677 lineas | 112 lineas |
| Estado | setState local | Provider global |
| Constantes | Inline | config/constants.dart |
| Tema | Inline | config/theme.dart |
| Widgets | Monolitico | Extraidos en widgets/ |

### Archivos nuevos creados:
- `config/constants.dart` - Colores, breakpoints, URLs
- `config/theme.dart` - Tema de la aplicacion
- `providers/schedule_provider.dart` - Estado global
- `widgets/common/*` - Widgets reutilizables
- `widgets/dialogs/*` - Dialogos modales
- `widgets/layout/*` - Componentes de layout
- `utils/time_utils.dart` - Utilidades de tiempo

### Correcciones de autenticacion:
- Cambiado `int id` a `String id` en modelo User
- Agregado `BrowserClient` con `withCredentials = true`
- Unificado a un solo `MaterialApp`
