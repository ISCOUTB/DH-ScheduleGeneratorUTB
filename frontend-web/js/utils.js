// utils.js - Funciones utilitarias

/**
 * Utilidades para manipulación del DOM
 */
const DOMUtils = {
    /**
     * Crea un elemento HTML con atributos y contenido
     * @param {string} tag - Tipo de elemento
     * @param {Object} attributes - Atributos del elemento
     * @param {string|Element} content - Contenido del elemento
     * @returns {Element} Elemento creado
     */
    createElement(tag, attributes = {}, content = '') {
        const element = document.createElement(tag);
        
        Object.keys(attributes).forEach(key => {
            if (key === 'className') {
                element.className = attributes[key];
            } else if (key === 'style' && typeof attributes[key] === 'object') {
                Object.assign(element.style, attributes[key]);
            } else {
                element.setAttribute(key, attributes[key]);
            }
        });

        if (typeof content === 'string') {
            element.innerHTML = content;
        } else if (content instanceof Element) {
            element.appendChild(content);
        } else if (Array.isArray(content)) {
            content.forEach(child => {
                if (typeof child === 'string') {
                    element.innerHTML += child;
                } else if (child instanceof Element) {
                    element.appendChild(child);
                }
            });
        }

        return element;
    },

    /**
     * Encuentra un elemento por selector
     * @param {string} selector - Selector CSS
     * @param {Element} parent - Elemento padre (opcional)
     * @returns {Element|null} Elemento encontrado
     */
    find(selector, parent = document) {
        return parent.querySelector(selector);
    },

    /**
     * Encuentra múltiples elementos por selector
     * @param {string} selector - Selector CSS
     * @param {Element} parent - Elemento padre (opcional)
     * @returns {NodeList} Lista de elementos
     */
    findAll(selector, parent = document) {
        return parent.querySelectorAll(selector);
    },

    /**
     * Añade clases a un elemento
     * @param {Element} element - Elemento
     * @param {string|Array} classes - Clases a añadir
     */
    addClass(element, classes) {
        if (typeof classes === 'string') {
            element.classList.add(classes);
        } else if (Array.isArray(classes)) {
            element.classList.add(...classes);
        }
    },

    /**
     * Remueve clases de un elemento
     * @param {Element} element - Elemento
     * @param {string|Array} classes - Clases a remover
     */
    removeClass(element, classes) {
        if (typeof classes === 'string') {
            element.classList.remove(classes);
        } else if (Array.isArray(classes)) {
            element.classList.remove(...classes);
        }
    },

    /**
     * Alterna clases de un elemento
     * @param {Element} element - Elemento
     * @param {string} className - Clase a alternar
     */
    toggleClass(element, className) {
        element.classList.toggle(className);
    },

    /**
     * Limpia el contenido de un elemento
     * @param {Element} element - Elemento a limpiar
     */
    clear(element) {
        element.innerHTML = '';
    }
};

/**
 * Utilidades para manejo de eventos
 */
const EventUtils = {
    /**
     * Añade un listener de evento
     * @param {Element} element - Elemento
     * @param {string} event - Tipo de evento
     * @param {Function} handler - Manejador del evento
     * @param {Object} options - Opciones del evento
     */
    on(element, event, handler, options = {}) {
        element.addEventListener(event, handler, options);
    },

    /**
     * Remueve un listener de evento
     * @param {Element} element - Elemento
     * @param {string} event - Tipo de evento
     * @param {Function} handler - Manejador del evento
     */
    off(element, event, handler) {
        element.removeEventListener(event, handler);
    },

    /**
     * Dispara un evento personalizado
     * @param {Element} element - Elemento
     * @param {string} eventName - Nombre del evento
     * @param {Object} detail - Datos del evento
     */
    trigger(element, eventName, detail = {}) {
        const event = new CustomEvent(eventName, { detail, bubbles: true });
        element.dispatchEvent(event);
    },

    /**
     * Implementa debouncing para una función
     * @param {Function} func - Función a aplicar debounce
     * @param {number} delay - Delay en milisegundos
     * @returns {Function} Función con debounce
     */
    debounce(func, delay) {
        let timeoutId;
        return function (...args) {
            clearTimeout(timeoutId);
            timeoutId = setTimeout(() => func.apply(this, args), delay);
        };
    },

    /**
     * Implementa throttling para una función
     * @param {Function} func - Función a aplicar throttle
     * @param {number} delay - Delay en milisegundos
     * @returns {Function} Función con throttle
     */
    throttle(func, delay) {
        let lastTime = 0;
        return function (...args) {
            const now = Date.now();
            if (now - lastTime >= delay) {
                lastTime = now;
                func.apply(this, args);
            }
        };
    }
};

/**
 * Utilidades para manejo de datos
 */
const DataUtils = {
    /**
     * Normaliza una cadena para búsqueda (sin acentos, minúsculas)
     * @param {string} str - Cadena a normalizar
     * @returns {string} Cadena normalizada
     */
    normalizeString(str) {
        return str
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '');
    },

    /**
     * Filtra una lista por query de búsqueda
     * @param {Array} items - Lista de items
     * @param {string} query - Query de búsqueda
     * @param {Array|Function} searchFields - Campos a buscar o función de búsqueda
     * @returns {Array} Items filtrados
     */
    filterItems(items, query, searchFields) {
        if (!query.trim()) return items;

        const normalizedQuery = this.normalizeString(query);

        return items.filter(item => {
            if (typeof searchFields === 'function') {
                return searchFields(item, normalizedQuery);
            }

            return searchFields.some(field => {
                const value = this.getNestedProperty(item, field);
                return value && this.normalizeString(value.toString()).includes(normalizedQuery);
            });
        });
    },

    /**
     * Obtiene una propiedad anidada de un objeto
     * @param {Object} obj - Objeto
     * @param {string} path - Ruta de la propiedad (ej: 'user.name')
     * @returns {*} Valor de la propiedad
     */
    getNestedProperty(obj, path) {
        return path.split('.').reduce((current, key) => current?.[key], obj);
    },

    /**
     * Clona un objeto profundamente
     * @param {*} obj - Objeto a clonar
     * @returns {*} Objeto clonado
     */
    deepClone(obj) {
        if (obj === null || typeof obj !== 'object') return obj;
        if (obj instanceof Date) return new Date(obj);
        if (obj instanceof Array) return obj.map(item => this.deepClone(item));
        if (obj instanceof Object) {
            const cloned = {};
            Object.keys(obj).forEach(key => {
                cloned[key] = this.deepClone(obj[key]);
            });
            return cloned;
        }
    },

    /**
     * Ordena una lista por múltiples criterios
     * @param {Array} items - Lista a ordenar
     * @param {Array} sortCriteria - Criterios de ordenamiento
     * @returns {Array} Lista ordenada
     */
    multiSort(items, sortCriteria) {
        return items.sort((a, b) => {
            for (const criterion of sortCriteria) {
                const { field, direction = 'asc' } = criterion;
                const aValue = this.getNestedProperty(a, field);
                const bValue = this.getNestedProperty(b, field);

                let comparison = 0;
                if (aValue < bValue) comparison = -1;
                else if (aValue > bValue) comparison = 1;

                if (comparison !== 0) {
                    return direction === 'desc' ? -comparison : comparison;
                }
            }
            return 0;
        });
    }
};

/**
 * Utilidades para manejo de tiempo y fechas
 */
const TimeUtils = {
    /**
     * Convierte una hora en formato "HH:MM" a minutos
     * @param {string} time - Hora en formato "HH:MM"
     * @returns {number} Minutos desde medianoche
     */
    timeToMinutes(time) {
        if (!time || typeof time !== 'string') {
            console.warn('timeToMinutes: invalid time format:', time);
            return 0;
        }
        
        const parts = time.split(':');
        if (parts.length !== 2) {
            console.warn('timeToMinutes: invalid time format:', time);
            return 0;
        }
        
        const [hours, minutes] = parts.map(Number);
        if (isNaN(hours) || isNaN(minutes)) {
            console.warn('timeToMinutes: invalid time format:', time);
            return 0;
        }
        
        return hours * 60 + minutes;
    },

    /**
     * Convierte un rango de tiempo en formato "HH:MM-HH:MM" o "HH:MM - HH:MM" a startTime y endTime separados
     * @param {string} timeRange - Rango de tiempo en formato "HH:MM-HH:MM"
     * @returns {Object} Objeto con startTime y endTime
     */
    parseTimeRange(timeRange) {
        if (!timeRange || typeof timeRange !== 'string') {
            console.warn('parseTimeRange: invalid time range format:', timeRange);
            return { startTime: null, endTime: null };
        }
        
        // Dividir por '-' y limpiar espacios
        const parts = timeRange.split('-').map(part => part.trim());
        if (parts.length !== 2) {
            console.warn('parseTimeRange: invalid time range format:', timeRange);
            return { startTime: null, endTime: null };
        }
        
        const [startTime, endTime] = parts;
        
        // Validar formato de cada hora
        if (!this.isValidTimeFormat(startTime) || !this.isValidTimeFormat(endTime)) {
            console.warn('parseTimeRange: invalid time format in range:', timeRange);
            return { startTime: null, endTime: null };
        }
        
        return { startTime, endTime };
    },

    /**
     * Valida si una hora está en formato HH:MM válido
     * @param {string} time - Hora a validar
     * @returns {boolean} True si es válida
     */
    isValidTimeFormat(time) {
        if (!time || typeof time !== 'string') return false;
        
        const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/;
        return timeRegex.test(time);
    },

    /**
     * Convierte minutos a formato "HH:MM"
     * @param {number} minutes - Minutos desde medianoche
     * @returns {string} Hora en formato "HH:MM"
     */
    minutesToTime(minutes) {
        const hours = Math.floor(minutes / 60);
        const mins = minutes % 60;
        return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`;
    },

    /**
     * Verifica si dos rangos de tiempo se superponen
     * @param {string} start1 - Hora de inicio del primer rango
     * @param {string} end1 - Hora de fin del primer rango
     * @param {string} start2 - Hora de inicio del segundo rango
     * @param {string} end2 - Hora de fin del segundo rango
     * @returns {boolean} True si se superponen
     */
    timeRangesOverlap(start1, end1, start2, end2) {
        const start1Min = this.timeToMinutes(start1);
        const end1Min = this.timeToMinutes(end1);
        const start2Min = this.timeToMinutes(start2);
        const end2Min = this.timeToMinutes(end2);

        return start1Min < end2Min && start2Min < end1Min;
    },

    /**
     * Calcula la duración entre dos horas
     * @param {string} startTime - Hora de inicio
     * @param {string} endTime - Hora de fin
     * @returns {number} Duración en minutos
     */
    getDuration(startTime, endTime) {
        return this.timeToMinutes(endTime) - this.timeToMinutes(startTime);
    }
};

/**
 * Utilidades para almacenamiento local
 */
const StorageUtils = {
    /**
     * Guarda un valor en localStorage
     * @param {string} key - Clave
     * @param {*} value - Valor a guardar
     */
    set(key, value) {
        try {
            localStorage.setItem(key, JSON.stringify(value));
        } catch (error) {
            console.error('Error saving to localStorage:', error);
        }
    },

    /**
     * Obtiene un valor de localStorage
     * @param {string} key - Clave
     * @param {*} defaultValue - Valor por defecto
     * @returns {*} Valor almacenado o valor por defecto
     */
    get(key, defaultValue = null) {
        try {
            const item = localStorage.getItem(key);
            return item ? JSON.parse(item) : defaultValue;
        } catch (error) {
            console.error('Error reading from localStorage:', error);
            return defaultValue;
        }
    },

    /**
     * Remueve un valor de localStorage
     * @param {string} key - Clave
     */
    remove(key) {
        try {
            localStorage.removeItem(key);
        } catch (error) {
            console.error('Error removing from localStorage:', error);
        }
    },

    /**
     * Limpia todo el localStorage
     */
    clear() {
        try {
            localStorage.clear();
        } catch (error) {
            console.error('Error clearing localStorage:', error);
        }
    }
};

/**
 * Utilidades para validación
 */
const ValidationUtils = {
    /**
     * Valida si un email es válido
     * @param {string} email - Email a validar
     * @returns {boolean} True si es válido
     */
    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    },

    /**
     * Valida si una cadena no está vacía
     * @param {string} str - Cadena a validar
     * @returns {boolean} True si no está vacía
     */
    isNotEmpty(str) {
        return str && str.trim().length > 0;
    },

    /**
     * Valida si un número está en un rango
     * @param {number} num - Número a validar
     * @param {number} min - Valor mínimo
     * @param {number} max - Valor máximo
     * @returns {boolean} True si está en el rango
     */
    isInRange(num, min, max) {
        return num >= min && num <= max;
    }
};

/**
 * Utilidades para animaciones
 */
const AnimationUtils = {
    /**
     * Añade una animación fade in a un elemento
     * @param {Element} element - Elemento
     * @param {number} duration - Duración en ms
     */
    fadeIn(element, duration = CONFIG.ANIMATIONS.FADE_DURATION) {
        element.style.opacity = '0';
        element.style.display = 'block';
        
        const start = performance.now();
        
        const fade = (currentTime) => {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);
            
            element.style.opacity = progress;
            
            if (progress < 1) {
                requestAnimationFrame(fade);
            }
        };
        
        requestAnimationFrame(fade);
    },

    /**
     * Añade una animación fade out a un elemento
     * @param {Element} element - Elemento
     * @param {number} duration - Duración en ms
     * @param {Function} callback - Callback al finalizar
     */
    fadeOut(element, duration = CONFIG.ANIMATIONS.FADE_DURATION, callback = null) {
        const start = performance.now();
        const initialOpacity = parseFloat(getComputedStyle(element).opacity) || 1;
        
        const fade = (currentTime) => {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);
            
            element.style.opacity = initialOpacity * (1 - progress);
            
            if (progress < 1) {
                requestAnimationFrame(fade);
            } else {
                element.style.display = 'none';
                if (callback) callback();
            }
        };
        
        requestAnimationFrame(fade);
    }
};

// Hacer las utilidades disponibles globalmente
window.DOMUtils = DOMUtils;
window.EventUtils = EventUtils;
window.DataUtils = DataUtils;
window.TimeUtils = TimeUtils;
window.StorageUtils = StorageUtils;
window.ValidationUtils = ValidationUtils;
window.AnimationUtils = AnimationUtils;
