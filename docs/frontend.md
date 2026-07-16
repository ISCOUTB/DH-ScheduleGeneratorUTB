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

```
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
|   +-- course_status.dart    # Estado de cupos (CourseStatus) y umbrales
|
+-- providers/                # Proveedores de estado (ChangeNotifier)
|   +-- schedule_provider.dart # Estado global de materias, horarios y filtros
|
+-- screens/                  # Pantallas principales
|   +-- home_screen.dart      # Pantalla principal con toda la funcionalidad
|   +-- favorites_screen.dart # Pantalla de horarios destacados (sidebar + grilla)
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
    +-- main_actions_panel.dart      # Acciones principales (buscar, filtrar, destacados)
    +-- schedule_grid_widget.dart    # Grilla visual del horario (paginacion, fillParent, colorResolver)
    +-- schedule_preview_card.dart   # Tarjeta de un horario (preview + estrella), reutilizable
    +-- color_mode_toggle.dart       # Toggle Materia/Estado (compartido)
    +-- schedule_overview_widget.dart # Resumen del horario (modal)
    +-- schedule_sort_widget.dart    # Ordenamiento de horarios
    +-- professor_filter_widget.dart # Filtro por profesor
    +-- nrc_filter_widget.dart       # Filtro por NRC
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
```

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

```dart
class ScheduleProvider extends ChangeNotifier {
  // Materias
  List<SubjectSummary> _allSubjectsList = [];
  List<Subject> _addedSubjects = [];
  
  // Horarios generados
  List<List<ClassOption>> _allSchedules = [];
  List<List<ClassOption>> _baseSchedulesForNrcCalculation = [];
  int? _selectedScheduleIndex;
  
  // Filtros
  Map<String, dynamic> _appliedFilters = {};
  Map<String, dynamic> _apiFiltersForGeneration = {};
  Map<String, dynamic> _currentOptimizations = {
    'optimizeGaps': false,
    'optimizeFreeDays': false,
  };
  
  // Estados de UI
  bool _isLoading = false;
  bool _isSearchOpen = false;
  bool _isFilterOpen = false;
  bool _isOverviewOpen = false;
  bool _isExpandedView = false;
}
```

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
- `generateSchedules(subjects, filters, creditLimit, isMobile)`: Genera horarios; devuelve `GenerateSchedulesResult` (lista + `truncated`)
- `getFavoritesStatus(nrcs)`: Estado de cupos actuales (Fase 2)

Ambos servicios usan `BrowserClient` con `withCredentials = true`.

### Favoritos (en ScheduleProvider)
Gestión de horarios destacados:
- `loadFavorites()` / `loadFavoriteTerms()`: Carga favoritos y términos del usuario desde el backend
- `toggleFavorite(schedule)`: Marca o desmarca un horario como destacado
- `removeFavoriteAt(index)`: Elimina un horario destacado por índice
- `isFavorite(schedule)`: Verifica si un horario ya está marcado (por `signature`)
- **Selector de periodos:** al entrar a la pantalla de destacados se reconsultan **siempre** los términos (`loadFavoriteTerms` → `GET /api/favorites/terms`, que hace `SELECT DISTINCT term`). Usar `availableTerms.isEmpty` como guardián no basta: `HomeScreen` solo llama a `loadFavorites`, que por *fallback* deja `availableTerms` con **solo** el término actual, así que los periodos anteriores no se descubrían y el selector se quedaba con un único periodo. Reconsultar términos no toca la lista de horarios → sin parpadeo.

### Estado visual de cupos (Fase 2)
Colorea la grilla de horarios destacados según los cupos **actuales** de cada curso:
- `models/course_status.dart`: enum `CourseStatus` (safe/caution/atRisk/eliminated), `computeCourseStatus`, `statusForClass` y colores/etiquetas. Umbrales: >50% seguro, 20–50% precaución, <20% en riesgo, 0 eliminado.
- `api_service.getFavoritesStatus(nrcs)`: consulta `GET /api/favorites/status`.
- `ScheduleProvider`: `statusColorMode`, `loadStatusForSchedule()` (solo término actual), `selectedScheduleStatus`.
- `widgets/color_mode_toggle.dart`: toggle compartido "Materia ↔ Estado".
- `ScheduleGridWidget`: parámetro opcional `colorResolver` para colorear por estado sin romper el coloreo por materia.
- El detalle (`ScheduleOverviewWidget`) tiene su propio toggle semi-independiente: hereda el modo al abrir y luego cambia por su cuenta. El texto `Cupos: X de Y` del detalle usa los cupos **en vivo** (de `/status`) cuando hay datos cargados; si no, el valor tal cual (snapshot / generación).
- Solo aplica al término actual; en periodos pasados el toggle queda deshabilitado (la tabla `Curso` solo tiene el periodo vigente). Ver `docs/issues/12-05-2026-rfc-estados-cursos-notificaciones.md`.

#### Cómo se enlaza y cuándo se pide (flujo)
- **Llave = `NRC`.** Cada clase del `schedule_json` tiene su `nrc`. El endpoint recibe NRCs y consulta `Curso` (PK `NRC`) → `{ nrc: {available, total} }`. `statusForClass(clase, mapa)` busca `mapa[clase.nrc]`: presente → calcula estado; ausente → `eliminado`.
- **Petición bajo demanda, por horario** (no al entrar, no masiva). `loadStatusForSchedule(horario)` toma los NRCs de **ese** horario y pide `/status` solo de esos. Se dispara al: activar "Estado", seleccionar otro horario en modo estado, abrir detalles, o cambiar de período. Solo si `selectedTerm == currentTerm`.
- El resultado se guarda en `selectedScheduleStatus`; la grilla (`colorResolver`) y el detalle leen de ahí. Al cambiar de horario se pide de nuevo para sus NRCs.

### Exportación a PDF y Excel (`services/schedule_export.dart`)
`buildSchedulePdf()` y `buildScheduleExcel()` generan los archivos que descarga el detalle del horario. Ambos parten del mismo layout (`_buildLayout`), que decide **qué dibujar**:
- Rango horario fijo **07:00–20:00** (igual que la grilla de la app), ampliado hacia afuera solo si hay alguna clase fuera de ese rango, para no recortarla.
- Días: Lunes–Viernes siempre; sábado y domingo solo si tienen clase.
- Un bloque por franja, con las clases solapadas agrupadas (antes se perdía una de las dos).

Cada archivo reproduce la grilla semanal con el color de la materia, una **leyenda** (chip por materia con su color y créditos, con el mismo estilo del bloque para que el color se reconozca entre leyenda, grilla y tabla) y una tabla con el detalle de cada clase (NRC, profesor, campus, créditos, horario) y el total de créditos. El fondo de los bloques usa el color de la materia aclarado (`_tint`, opacidad ~0.36) para que el texto en negro se lea también al imprimir.
- **PDF:** A4 apaisada. La grilla se dibuja con `pw.Stack` + `pw.Positioned` (bloques del alto de su duración, como en la app); el detalle va en su propia página (`pw.NewPage()`) para que el título no quede huérfano al pie de la grilla. Ojo: el paquete `pdf` no admite `borderRadius` con bordes no uniformes; el bold es un asset aparte (`Roboto-Bold.ttf`) que degrada a la regular si no está empaquetado.
- **Excel:** hoja `Horario` (grilla, con los bloques como celdas **fusionadas** verticalmente) + hoja `Detalle`. Ojo: `Sheet.merge()` descarta contenido y estilo de las celdas del rango, así que hay que **fusionar primero y escribir después** (`updateCell` reconoce la fusión y escribe en la celda ancla).

### Comportamiento responsivo / UX
- **Generación en móvil:** la grilla pagina por páginas (`paginateOnMobile` en `ScheduleGridWidget`) con barra `Página X de Y`; al cambiar de página vuelve al inicio de los horarios (`Scrollable.ensureVisible`). El backend limita los resultados solo en móvil (cap `MAX_SCHEDULES`); el contador muestra "N+" si se truncó.
- **Generación en escritorio:** aquí la grilla es la que scrollea (`isScrollable`, controlador interno de `ScheduleGridWidget`) y pagina con `PaginationControl`. Al cambiar de página, `didUpdateWidget` resetea el scroll al inicio (`jumpTo(0)`); sin esto la página siguiente aparecía desplazada al punto donde quedó la anterior (a diferencia de móvil, donde el reset lo hace el padre sobre el ListView externo).
- **Navegación en el detalle (generación, escritorio):** dentro del detalle (modal con fondo oscuro) hay flechas ◀ ▶ superpuestas y teclas ← → para pasar entre los horarios de la **misma página** (no cruza de página ni hace wrap). En el provider: `selectPrevInPage` / `selectNextInPage`, acotadas a `[_pageStartIndex, _pageEndIndex)`, y los flags `canSelectPrevInPage` / `canSelectNextInPage` (deshabilitan las flechas en los extremos). El detalle se reconstruye con `Key: ValueKey(selectedScheduleIndex)` para recalcular su estado (numeración de materias, etc.). Un `Focus` ancestro captura ← → aunque el foco esté en un botón interno (el evento sube antes del traversal direccional). Solo generación y solo escritorio; en destacados el detalle no lleva esta navegación.
- **Navegación en destacados (escritorio):** con las teclas ↑ ↓ se pasa entre los horarios destacados **cuando NO se está en el detalle** (mueve `_selectedIndex` en `FavoritesScreen`, clamp a la lista). Un `Focus` ancestro captura las teclas; con el detalle abierto las ignora. No hay flechas en pantalla en destacados.
- **Tarjeta de horario:** extraída a `widgets/schedule_preview_card.dart` (`SchedulePreview`, `SchedulePreviewCard`, `ScheduleFavoriteStar`), reutilizada por la grilla.
- **Modales (buscar/filtrar/detalle):** en escritorio se cierran al hacer clic fuera (sobre el fondo oscuro); en móvil solo con sus botones. El menú hamburguesa (móvil) se cierra al tocar fuera.
- **Pantalla de destacados (móvil):** appbar con perfil + hamburguesa; la flecha de "volver al generador" vive en la barra de período.
- **Búsqueda:** filtra por palabras (tokens), ignorando espacios extra; cada palabra debe coincidir (AND).

## 6. Modelos de Datos

### User
```dart
class User {
  final String id;    // UUID de Microsoft Entra ID
  final String email;
  final String? nombre;
  final bool authenticated;
}
```

### Subject
```dart
class Subject {
  final String code;
  final String name;
  final double credits;   // Decimal: hay materias de 0.5 creditos
  final List<ClassOption> classOptions;
}
```

### ClassOption
```dart
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
  final double credits;    // Decimal: hay materias de 0.5 creditos
  final List<Schedule> schedules;
}
```

## 7. Compilacion y Despliegue

### Desarrollo local:
```bash
flutter run -d chrome
```

### Produccion (Docker):
```bash
docker-compose up --build frontend -d
```

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
