// config.js - Configuración de la aplicación

const CONFIG = {
    // URL base de la API
    API_BASE_URL: 'http://127.0.0.1:8000',
    
    // Endpoints de la API
    API_ENDPOINTS: {
        SUBJECTS: '/api/subjects',
        SUBJECT_DETAILS: '/api/subjects',
        GENERATE_SCHEDULES: '/api/schedules/generate'
    },
    
    // Configuración de la aplicación
    APP_CONFIG: {
        CREDIT_LIMIT: 20,
        SCHEDULES_PER_PAGE: 10,
        SEARCH_DEBOUNCE_DELAY: 300,
        MAX_SELECTED_SUBJECTS: 10
    },
    
    // Configuración de colores para las materias
    SUBJECT_COLORS: [
        '#f44336', // Red
        '#2196f3', // Blue
        '#4caf50', // Green
        '#ff9800', // Orange
        '#9c27b0', // Purple
        '#00bcd4', // Cyan
        '#ffc107', // Amber
        '#009688', // Teal
        '#3f51b5', // Indigo
        '#e91e63', // Pink
        '#cddc39', // Lime
        '#ff5722', // Deep Orange
        '#03a9f4', // Light Blue
        '#8bc34a', // Light Green
        '#673ab7'  // Deep Purple
    ],
    
    // Configuración de días de la semana
    DAYS_OF_WEEK: {
        'Lunes': 'monday',
        'Martes': 'tuesday', 
        'Miércoles': 'wednesday',
        'Jueves': 'thursday',
        'Viernes': 'friday',
        'Sábado': 'saturday',
        'Domingo': 'sunday'
    },
    
    // Configuración de franjas horarias
    TIME_SLOTS: [
        '07:00', '08:00', '09:00', '10:00', '11:00', '12:00',
        '13:00', '14:00', '15:00', '16:00', '17:00', '18:00',
        '19:00', '20:00', '21:00'
    ],
    
    // Configuración de tipos de clase
    CLASS_TYPES: {
        'Teoría': 'theory',
        'Laboratorio': 'lab',
        'Práctica': 'practice',
        'Taller': 'workshop'
    },
    
    // Configuración de mensajes
    MESSAGES: {
        LOADING: 'Cargando...',
        GENERATING_SCHEDULES: 'Generando horarios...',
        NO_SCHEDULES_FOUND: 'No se encontraron horarios con los criterios seleccionados',
        ERROR_LOADING_SUBJECTS: 'Error al cargar las materias',
        ERROR_GENERATING_SCHEDULES: 'Error al generar horarios',
        SUBJECT_ALREADY_ADDED: 'Esta materia ya está agregada',
        CREDIT_LIMIT_EXCEEDED: 'No se puede agregar la materia. Se excedería el límite de créditos',
        MAX_SUBJECTS_EXCEEDED: 'Máximo ${max} materias permitidas'
    },
    
    // Configuración de animaciones
    ANIMATIONS: {
        FADE_DURATION: 300,
        SLIDE_DURATION: 250,
        BOUNCE_DURATION: 400
    },
    
    // Configuración de almacenamiento local
    STORAGE_KEYS: {
        SELECTED_SUBJECTS: 'dh_selected_subjects',
        APPLIED_FILTERS: 'dh_applied_filters',
        THEME: 'dh_theme',
        LAST_SCHEDULES: 'dh_last_schedules'
    }
};

// Función para obtener la URL completa de un endpoint
CONFIG.getApiUrl = function(endpoint, params = '') {
    return `${this.API_BASE_URL}${endpoint}${params}`;
};

// Función para obtener un color de materia por índice
CONFIG.getSubjectColor = function(index) {
    return this.SUBJECT_COLORS[index % this.SUBJECT_COLORS.length];
};

// Función para obtener el código de día por nombre
CONFIG.getDayCode = function(dayName) {
    return this.DAYS_OF_WEEK[dayName] || dayName.toLowerCase();
};

// Función para obtener mensaje con parámetros
CONFIG.getMessage = function(key, params = {}) {
    let message = this.MESSAGES[key] || key;
    Object.keys(params).forEach(param => {
        message = message.replace(new RegExp(`\\$\\{${param}\\}`, 'g'), params[param]);
    });
    return message;
};

// Exportar configuración para módulos ES6
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CONFIG;
}
