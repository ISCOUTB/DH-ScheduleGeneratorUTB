# Frontend Web - Generador de Horarios UTB

Este es el frontend web desarrollado en HTML, CSS y JavaScript vanilla para el Generador de Horarios de la Universidad Tecnológica de Bolívar.

## 🚀 Características

### Funcionalidades Principales
- **Búsqueda de Materias**: Interfaz intuitiva para buscar y seleccionar materias
- **Generación de Horarios**: Algoritmo que genera horarios optimizados automáticamente
- **Filtros Avanzados**: 
  - Filtros de profesores (incluir/excluir)
  - Horarios no disponibles por día y hora
- **Vista de Horarios**: Grilla visual de horarios generados con paginación
- **Detalle de Horarios**: Modal con vista detallada de cada horario
- **Gestión de Créditos**: Control automático del límite de créditos
- **Tema Claro/Oscuro**: Interfaz adaptable con soporte para tema oscuro

### Características Técnicas
- **Vanilla JavaScript**: Sin dependencias de frameworks
- **Responsive Design**: Adaptable a dispositivos móviles y escritorio
- **Accesibilidad**: Soporte para navegación por teclado y lectores de pantalla
- **Almacenamiento Local**: Persistencia de materias y filtros seleccionados
- **API RESTful**: Comunicación con backend Python/FastAPI

## 📁 Estructura del Proyecto

```
frontend-web/
├── index.html              # Página principal
├── styles/
│   ├── main.css            # Estilos principales y variables CSS
│   ├── components.css      # Estilos de componentes específicos
│   └── responsive.css      # Estilos responsivos y media queries
├── js/
│   ├── config.js           # Configuración de la aplicación
│   ├── api.js              # Servicio de comunicación con API
│   ├── utils.js            # Funciones utilitarias
│   ├── app.js              # Aplicación principal
│   └── components/
│       ├── SearchModal.js      # Modal de búsqueda de materias
│       ├── FiltersModal.js     # Modal de filtros
│       ├── ScheduleDetailModal.js # Modal de detalle de horario
│       ├── SubjectsList.js     # Lista de materias seleccionadas
│       └── SchedulesGrid.js    # Grilla de horarios generados
└── README.md               # Este archivo
```

## 🛠️ Instalación y Uso

### Prerrequisitos
- Backend del proyecto ejecutándose en `http://127.0.0.1:8000`
- Navegador web moderno (Chrome, Firefox, Safari, Edge)

### Instalación
1. No requiere instalación de dependencias
2. Simplemente abre `index.html` en tu navegador web

### Uso con Servidor Local (Recomendado)
Para evitar problemas de CORS, se recomienda servir los archivos desde un servidor HTTP:

```bash
# Usando Python
cd frontend-web
python -m http.server 8080

# Usando Node.js (si tienes http-server instalado)
npx http-server -p 8080

# Usando PHP
php -S localhost:8080
```

Luego accede a `http://localhost:8080`

## 🎯 Guía de Uso

### 1. Búsqueda y Selección de Materias
- Haz clic en el botón "Buscar" o usa el atajo `Ctrl+K`
- Escribe el código o nombre de la materia
- Selecciona la materia de la lista de resultados
- La materia se agregará al panel izquierdo

### 2. Configuración de Filtros
- Haz clic en "Filtros" o usa el atajo `Ctrl+F`
- **Filtros de Profesores**: Incluye o excluye profesores específicos
- **Horarios No Disponibles**: Marca los horarios en los que no puedes asistir
- Aplica los filtros haciendo clic en "Aplicar Filtros"

### 3. Generación de Horarios
- Asegúrate de tener al menos una materia seleccionada
- Haz clic en "Generar Horarios" o usa `Ctrl+Enter`
- Los horarios se mostrarán en una grilla paginada

### 4. Vista de Horarios
- Cada tarjeta muestra un resumen del horario
- Haz clic en cualquier tarjeta para ver el detalle completo
- Usa "Cargar más" para ver horarios adicionales

## ⌨️ Atajos de Teclado

- `Ctrl+K`: Abrir búsqueda de materias
- `Ctrl+F`: Abrir filtros
- `Ctrl+Enter`: Generar horarios
- `Escape`: Cerrar modales
- `Enter/Espacio`: Activar elementos seleccionados
- `↑/↓`: Navegar en listas

## 🎨 Personalización

### Variables CSS
El archivo `main.css` define variables CSS que puedes modificar:

```css
:root {
  --primary-color: #3f51b5;
  --success-color: #1abc7b;
  --spacing-md: 1rem;
  /* ... más variables */
}
```

### Configuración JavaScript
El archivo `config.js` contiene configuraciones modificables:

```javascript
const CONFIG = {
  API_BASE_URL: 'http://127.0.0.1:8000',
  APP_CONFIG: {
    CREDIT_LIMIT: 20,
    SCHEDULES_PER_PAGE: 10
  }
  // ... más configuraciones
};
```

## 🌐 Compatibilidad

### Navegadores Soportados
- Chrome 60+
- Firefox 60+
- Safari 12+
- Edge 79+

### Características Utilizadas
- ES6+ JavaScript
- CSS Grid y Flexbox
- CSS Custom Properties (Variables)
- Fetch API
- LocalStorage
- CSS Media Queries

## 🔧 Desarrollo

### Estructura de Componentes
Cada componente JavaScript sigue un patrón similar:
- Constructor que inicializa elementos DOM y estado
- Método `init()` para configuración inicial
- Método `bindEvents()` para event listeners
- Métodos públicos para interacción con otros componentes

### Gestión de Estado
- **Local**: Cada componente maneja su propio estado
- **Global**: La aplicación principal (`app.js`) coordina entre componentes
- **Persistente**: LocalStorage para datos que deben persistir

### Comunicación con API
El servicio `ApiService` maneja toda la comunicación con el backend:
- Manejo de errores centralizado
- Validación de respuestas
- Transformación de datos

## 🚨 Solución de Problemas

### Error de Conexión con API
- Verifica que el backend esté ejecutándose
- Revisa la URL en `config.js`
- Verifica configuración de CORS en el backend

### Materias no se cargan
- Abre las herramientas de desarrollador (F12)
- Verifica errores en la consola
- Revisa la pestaña Network para errores de HTTP

### Filtros no se aplican
- Verifica que tengas materias seleccionadas
- Los filtros de profesores solo funcionan con materias agregadas
- Revisa que los filtros estén guardados correctamente

## 📱 Responsive Design

La aplicación es completamente responsive con breakpoints:
- **Desktop**: > 1024px
- **Tablet**: 768px - 1024px  
- **Mobile**: < 768px

En dispositivos móviles:
- El panel lateral se convierte en un diseño vertical
- Los modales ocupan toda la pantalla
- La grilla de horarios se adapta a una columna

## ♿ Accesibilidad

- Navegación completa por teclado
- Elementos focusables claramente marcados
- Textos alternativos para iconos
- Contraste adecuado de colores
- Soporte para lectores de pantalla
- Skip links para navegación rápida

## 🔄 Comparación con Frontend Flutter

| Característica | Flutter | Web Vanilla |
|---------------|---------|-------------|
| **Búsqueda de Materias** | ✅ | ✅ |
| **Filtros de Profesores** | ✅ | ✅ |
| **Filtros de Tiempo** | ✅ | ✅ |
| **Generación de Horarios** | ✅ | ✅ |
| **Vista de Grilla** | ✅ | ✅ |
| **Detalle de Horarios** | ✅ | ✅ |
| **Tema Oscuro** | ✅ | ✅ |
| **Responsive** | ✅ | ✅ |
| **Almacenamiento Local** | ✅ | ✅ |
| **Atajos de Teclado** | ❌ | ✅ |
| **Accesibilidad Mejorada** | ❌ | ✅ |

## 📝 Licencia

Este proyecto está bajo la misma licencia que el proyecto principal.

## 🤝 Contribuciones

Para contribuir al frontend web:
1. Sigue las convenciones de código establecidas
2. Mantén la consistencia con el diseño existente
3. Asegúrate de que sea responsive
4. Prueba en múltiples navegadores
5. Documenta cualquier nueva funcionalidad
