# Ayuda: dropdown "Recursos" y Preguntas frecuentes

- Fecha: 2026-07-18
- Estado: Implementado
- Alcance: Frontend (AppBar, menú móvil, speed dial, nuevo diálogo)

Mejoras de navegación y ayuda, no relacionadas con el generador en sí. Dos
commits: `7632cd8` (Recursos) y `0c83fcc` (FAQ + speed dial).

## 1. Dropdown "Recursos" (AppBar de escritorio)

Los enlaces externos **Mi UTB / Turnos / Mallas / Electivas** se agruparon en un
solo botón **"Recursos"** que:
- abre al **pasar el mouse** y cierra ~1 s después de salir (hover sobre el menú
  lo mantiene abierto; clic/táctil también togglea);
- usa `Listener`/`OverlayPortal` con un `Timer` para el cierre diferido, y un
  ancho acotado (no se estira a toda la pantalla).

"Reportar Error", el ícono ⓘ (creadores) y lo demás siguen en la barra. En móvil
el menú (`MobileMenu`) no cambia: ya es una lista colapsada.

Archivos: `frontend/lib/widgets/common/resources_menu.dart` (nuevo),
`home_screen.dart`, `common.dart`.

## 2. Preguntas frecuentes (in-app, sin links externos)

Nuevo **`FaqDialog`** (`frontend/lib/widgets/faq_dialog.dart`): acordeón
(`ExpansionTile`) de preguntas/respuestas **dentro de la app**, sin navegar ni
salir. Decisiones:
- **Contenido hardcodeado** en Dart (`_Faq`, lista `const`). Es estable; si algún
  día hay que editarlo sin redeploy, se mueve a un endpoint. *No se usan records*
  (el SDK del proyecto es < 3.0): se usa una clase `_Faq(q, a)`.
- **Alto fijo** (80 % de la pantalla, entre 360 y 560 px): el diálogo **no cambia
  de tamaño** al abrir/cerrar una respuesta; la lista scrollea por dentro.
- **Pie fijo** de contacto (fuera del scroll) para dudas que no estén en la lista.

**Entradas** (las tres abren el mismo diálogo):
- Botón **"Preguntas frecuentes"** (ícono + texto) en el AppBar de escritorio,
  junto a "Reportar Error".
- Ítem en el **menú móvil** (`MobileMenu`).
- Acción en el **speed dial** móvil.

Elección de forma: se optó por el **diálogo con acordeón** (la más simple e
integrada) sobre la pantalla dedicada o el bottom-sheet; se puede reevaluar más
adelante.

## 3. Ajustes del speed dial (móvil)

`frontend/lib/widgets/layout/speed_dial_menu.dart`:
- Se **quitó "Tutorial"** (el tutorial en YouTube sigue accesible desde el otro
  panel de escritorio).
- **"Cursos Personalizados" → "Crear curso"**.
- Se **agregó "Preguntas frecuentes"**.
- Orden visual (arriba → abajo): Buscar, Filtro, Mis Horarios, Crear curso,
  Preguntas frecuentes, Creadores, **Limpiar Todo (último)**.

> Nota: `flutter_speed_dial` emite un warning por usar más de 5 hijos (guía de
> Material). Es solo advertencia; se acepta a cambio de tener todas las acciones.
