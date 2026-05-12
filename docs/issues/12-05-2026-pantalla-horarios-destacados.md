# Registro: Implementación de Pantalla de Horarios Destacados

- Fecha: 2026-05-12
- Estado: Implementado y funcional
- Autor: Equipo Frontend
- RFC base: `docs/issues/29-03-2026-rfc-horarios-destacados.md`
- Alcance: Frontend (nueva pantalla, widgets modificados, navegación)

## 1. Contexto

La RFC de Horarios Destacados definió el backend (tabla `horario_destacado`, endpoints CRUD) y un frontend mínimo (botón estrella). Esta fase implementa la **pantalla dedicada de visualización** de horarios destacados, incluyendo un panel lateral con previsualizaciones, navegación completa y detalles de cada horario guardado.

El diseño se basó en un prototipo funcional desarrollado por un miembro del equipo en un proyecto Flutter separado (`interfaz_horarios_destacados/`), adaptado a la arquitectura y estilo visual de la aplicación principal.

## 2. Qué se Implementó

### 2.1 Nueva Pantalla: `FavoritesScreen`

**Archivo:** `frontend/lib/screens/favorites_screen.dart`

Pantalla completa para visualizar horarios destacados con dos layouts:

**Desktop (≥ breakpoint):**
- Panel lateral izquierdo (sidebar, 220px) con tarjetas de previsualización miniatura de cada horario.
- Toggle global en el sidebar que alterna entre vista de grilla miniatura y vista de información (huecos, días libres, materias) con animación `AnimatedCrossFade`.
- Área principal con título "Opción A/B/C..." y grilla completa del horario seleccionado.
- La grilla llena todo el espacio disponible dentro de un contenedor con borde redondeado.
- Al hacer clic en la grilla, se abre el modal de detalles (`ScheduleOverviewWidget`) con fondo negro (`ModalBarrier`), idéntico al comportamiento de la pantalla principal.

**Mobile (< breakpoint):**
- Grilla estándar con etiquetas de letras (A, B, C) en lugar de números (#1, #2, #3).
- Al tocar un horario, se abre el mismo modal de detalles.

**Navegación:**
- Reutiliza el **mismo AppBar** de la aplicación principal (logo UTB, enlaces de navegación, badge de usuario).
- Logo UTB clickeable para volver al generador.
- En mobile: botón de retroceso en AppBar.
- Botón "Volver" con hover animation en el sidebar (desktop).

### 2.2 Modificaciones a `ScheduleGridWidget`

**Archivo:** `frontend/lib/widgets/schedule_grid_widget.dart`

Nuevos parámetros añadidos al widget existente:

| Parámetro | Tipo | Default | Propósito |
|-----------|------|---------|-----------|
| `useLetterLabels` | `bool` | `false` | Muestra A, B, C en vez de #1, #2, #3 |
| `fillParent` | `bool` | `false` | Renderiza un solo horario llenando el padre (sin GridView) |
| `fillParentLabel` | `String?` | `null` | Etiqueta personalizada para modo fillParent |

**Modo `fillParent`:** Cuando está activo y hay 1 horario, renderiza `buildSchedulePreview` directamente sin `GridView.builder`, evitando las restricciones de `childAspectRatio` que impedían llenar el espacio disponible.

**Método `buildSchedulePreview`:** Se le añadió parámetro opcional `labelOverride` para mostrar etiquetas personalizadas en la esquina superior izquierda de la grilla.

### 2.3 Botón de Acceso a Destacados

**Archivo:** `frontend/lib/widgets/main_actions_panel.dart`

- El botón "Tutorial" fue reemplazado por **"Destacados"** con ícono de estrella y color dorado (`#E6A817`).
- Nuevo callback `onFavorites` para navegar a `FavoritesScreen`.

**Archivo:** `frontend/lib/screens/home_screen.dart`

- Se removió el ícono de estrella del AppBar (acceso solo desde el botón de acciones y SpeedDial).
- `_navigateToFavorites` pasa `currentUser` y `onLogout` a `FavoritesScreen` para que pueda renderizar el AppBar completo.

### 2.4 Acceso desde Mobile (SpeedDial)

**Archivo:** `frontend/lib/widgets/layout/speed_dial_menu.dart`

- Se añadió opción "Horarios Destacados" al menú flotante con ícono de estrella.

## 3. Lógica de Selección y Eliminación

La gestión del índice seleccionado sigue estas reglas:

| Acción | Comportamiento |
|--------|---------------|
| Eliminar horario **anterior** al seleccionado | `_selectedIndex--` (mantiene el mismo horario visible) |
| Eliminar **el horario seleccionado** | Mantiene índice, clamp al último si es necesario |
| Eliminar horario **posterior** al seleccionado | Sin cambio |
| Índice fuera de rango (safety clamp) | Va al **último** disponible, nunca al primero |

## 4. Cálculos de Estadísticas

La pantalla calcula para cada horario:

- **Huecos:** Bloques vacíos entre clases del mismo día. Se agrupan clases por día, se ordenan por hora de inicio, y se cuentan gaps donde `fin_clase_i < inicio_clase_i+1`.
- **Días libres:** Días de lunes a sábado sin ninguna clase programada.
- **Materias:** Cantidad de materias únicas (`subjectName`) en el horario.

## 5. Archivos Modificados

| Archivo | Cambio |
|---------|--------|
| `screens/favorites_screen.dart` | **[NUEVO]** Pantalla completa de favoritos |
| `widgets/schedule_grid_widget.dart` | Parámetros `useLetterLabels`, `fillParent`, `fillParentLabel`, `labelOverride` |
| `widgets/main_actions_panel.dart` | Botón Tutorial → Destacados |
| `screens/home_screen.dart` | Navegación, removida estrella de AppBar |
| `widgets/layout/speed_dial_menu.dart` | Opción de favoritos en menú mobile |

## 6. Decisiones de Diseño

1. **Reutilización del AppBar:** Se replica el AppBar de `HomeScreen` en `FavoritesScreen` para mantener consistencia visual. No se extrajo a un widget compartido para evitar cambios en la pantalla principal en esta iteración.

2. **`fillParent` vs widget nuevo:** Se optó por añadir un modo al `ScheduleGridWidget` existente en lugar de crear un widget separado, para reutilizar toda la lógica de renderizado (`buildSchedulePreview`, colores, layout).

3. **Toggle global vs individual:** El toggle de vista grilla/info del sidebar es global (afecta todas las tarjetas). Esto facilita la comparación entre horarios cuando se quiere ver stats de todos a la vez.

4. **Labels con letras:** Se usan letras (A-Z) en vez de números para diferenciar visualmente los horarios destacados de los horarios generados. Soporta hasta 26 horarios (límite actual del backend: 20).

## 7. Pendientes / Feature futura

- **Estado de cursos (Seguro/Precaución/En riesgo/Eliminado):** Colorear bloques de la grilla según cupos disponibles. Requiere definir umbrales y obtener datos de cupos en tiempo real.
- **Notificaciones por correo:** Alertar al usuario cuando un curso de un horario destacado cambie de estado. Requiere backend job periódico.
- **Widget compartido de AppBar:** Extraer el AppBar a un widget reutilizable si se añaden más pantallas.
