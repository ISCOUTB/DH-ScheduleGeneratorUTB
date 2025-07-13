// FiltersModal.js - Componente del modal de filtros

class FiltersModal {
    constructor() {
        this.modal = DOMUtils.find('#filters-modal');
        this.closeBtn = DOMUtils.find('#filters-modal-close');
        this.applyBtn = DOMUtils.find('#apply-filters-btn');
        this.clearBtn = DOMUtils.find('#clear-filters-btn');
        this.professorFiltersContainer = DOMUtils.find('#professor-filters');
        
        this.currentFilters = {
            professors: {},
            timeFilters: {}
        };
        this.addedSubjects = [];
        this.onFiltersApplied = null;
        
        this.init();
    }

    init() {
        this.bindEvents();
        this.initTimeSlots();
    }

    bindEvents() {
        // Cerrar modal
        EventUtils.on(this.closeBtn, 'click', () => this.close());
        EventUtils.on(this.modal, 'click', (e) => {
            if (e.target === this.modal) this.close();
        });

        // Aplicar filtros
        EventUtils.on(this.applyBtn, 'click', () => this.applyFilters());

        // Limpiar filtros
        EventUtils.on(this.clearBtn, 'click', () => this.clearAllFilters());

        // Tecla Escape para cerrar
        EventUtils.on(document, 'keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen()) {
                this.close();
            }
        });
    }

    initTimeSlots() {
        const daysContainer = DOMUtils.find('.days-grid');
        
        Object.entries(CONFIG.DAYS_OF_WEEK).forEach(([dayName, dayCode]) => {
            const dayColumn = DOMUtils.find(`[data-day="${dayCode}"]`, daysContainer);
            if (!dayColumn) return;

            DOMUtils.clear(dayColumn);
            
            CONFIG.TIME_SLOTS.forEach(timeSlot => {
                const slot = DOMUtils.createElement('div', {
                    className: 'time-slot',
                    'data-time': timeSlot,
                    'data-day': dayCode
                }, timeSlot);

                EventUtils.on(slot, 'click', () => this.toggleTimeSlot(dayCode, timeSlot, slot));
                
                dayColumn.appendChild(slot);
            });
        });
    }

    toggleTimeSlot(day, time, element) {
        if (!this.currentFilters.timeFilters[day]) {
            this.currentFilters.timeFilters[day] = [];
        }

        const timeIndex = this.currentFilters.timeFilters[day].indexOf(time);
        
        if (timeIndex === -1) {
            // Agregar tiempo no disponible
            this.currentFilters.timeFilters[day].push(time);
            DOMUtils.addClass(element, 'selected');
        } else {
            // Remover tiempo no disponible
            this.currentFilters.timeFilters[day].splice(timeIndex, 1);
            DOMUtils.removeClass(element, 'selected');
            
            // Limpiar array si está vacío
            if (this.currentFilters.timeFilters[day].length === 0) {
                delete this.currentFilters.timeFilters[day];
            }
        }
    }

    renderProfessorFilters() {
        DOMUtils.clear(this.professorFiltersContainer);

        if (this.addedSubjects.length === 0) {
            const emptyState = DOMUtils.createElement('div', {
                className: 'empty-state'
            }, `
                <i class="fas fa-chalkboard-teacher"></i>
                <p>No hay materias seleccionadas</p>
                <small>Agrega materias para configurar filtros de profesores</small>
            `);
            this.professorFiltersContainer.appendChild(emptyState);
            return;
        }

        this.addedSubjects.forEach(subject => {
            const filterSection = this.createProfessorFilter(subject);
            this.professorFiltersContainer.appendChild(filterSection);
        });
    }

    createProfessorFilter(subject) {
        const filterContainer = DOMUtils.createElement('div', {
            className: 'professor-filter'
        });

        // Header con título de materia
        const header = DOMUtils.createElement('div', {
            className: 'professor-filter-header'
        });

        const title = DOMUtils.createElement('div', {
            className: 'professor-filter-title'
        }, `${subject.code} - ${subject.name}`);

        const toggle = DOMUtils.createElement('button', {
            className: 'professor-filter-toggle'
        }, '<i class="fas fa-chevron-down"></i>');

        header.appendChild(title);
        header.appendChild(toggle);

        // Lista de profesores
        const professorList = DOMUtils.createElement('div', {
            className: 'professor-list'
        });

        // Obtener profesores únicos
        const professors = [...new Set(subject.classOptions.map(option => option.professor))];

        professors.forEach(professor => {
            const professorItem = this.createProfessorItem(subject.code, professor);
            professorList.appendChild(professorItem);
        });

        // Toggle expandir/contraer
        EventUtils.on(toggle, 'click', () => {
            const isExpanded = professorList.style.display !== 'none';
            professorList.style.display = isExpanded ? 'none' : 'block';
            
            const icon = DOMUtils.find('i', toggle);
            icon.className = isExpanded ? 'fas fa-chevron-right' : 'fas fa-chevron-down';
        });

        filterContainer.appendChild(header);
        filterContainer.appendChild(professorList);

        return filterContainer;
    }

    createProfessorItem(subjectCode, professor) {
        const item = DOMUtils.createElement('div', {
            className: 'professor-item'
        });

        const name = DOMUtils.createElement('div', {
            className: 'professor-name'
        }, professor);

        const actions = DOMUtils.createElement('div', {
            className: 'professor-actions'
        });

        // Botón incluir
        const includeBtn = DOMUtils.createElement('button', {
            className: 'professor-action include',
            'data-action': 'include'
        }, 'Incluir');

        // Botón excluir
        const excludeBtn = DOMUtils.createElement('button', {
            className: 'professor-action exclude',
            'data-action': 'exclude'
        }, 'Excluir');

        // Estado actual
        const currentFilter = this.currentFilters.professors[subjectCode]?.[professor];
        if (currentFilter === 'include') {
            DOMUtils.addClass(includeBtn, 'active');
        } else if (currentFilter === 'exclude') {
            DOMUtils.addClass(excludeBtn, 'active');
        }

        // Eventos
        EventUtils.on(includeBtn, 'click', () => {
            this.setProfessorFilter(subjectCode, professor, 'include');
            this.updateProfessorButtons(includeBtn, excludeBtn, 'include');
        });

        EventUtils.on(excludeBtn, 'click', () => {
            this.setProfessorFilter(subjectCode, professor, 'exclude');
            this.updateProfessorButtons(includeBtn, excludeBtn, 'exclude');
        });

        actions.appendChild(includeBtn);
        actions.appendChild(excludeBtn);
        item.appendChild(name);
        item.appendChild(actions);

        return item;
    }

    setProfessorFilter(subjectCode, professor, action) {
        if (!this.currentFilters.professors[subjectCode]) {
            this.currentFilters.professors[subjectCode] = {};
        }

        const currentAction = this.currentFilters.professors[subjectCode][professor];
        
        if (currentAction === action) {
            // Si ya está seleccionado, lo deseleccionamos
            delete this.currentFilters.professors[subjectCode][professor];
            
            // Limpiar objeto si está vacío
            if (Object.keys(this.currentFilters.professors[subjectCode]).length === 0) {
                delete this.currentFilters.professors[subjectCode];
            }
        } else {
            // Establecer nueva acción
            this.currentFilters.professors[subjectCode][professor] = action;
        }
    }

    updateProfessorButtons(includeBtn, excludeBtn, selectedAction) {
        // Limpiar estados anteriores
        DOMUtils.removeClass(includeBtn, 'active');
        DOMUtils.removeClass(excludeBtn, 'active');

        // Aplicar nuevo estado si es diferente al actual
        const currentActive = includeBtn.classList.contains('active') ? 'include' : 
                             excludeBtn.classList.contains('active') ? 'exclude' : null;

        if (currentActive !== selectedAction) {
            if (selectedAction === 'include') {
                DOMUtils.addClass(includeBtn, 'active');
            } else if (selectedAction === 'exclude') {
                DOMUtils.addClass(excludeBtn, 'active');
            }
        }
    }

    loadTimeFilters() {
        // Limpiar selecciones anteriores
        DOMUtils.findAll('.time-slot.selected').forEach(slot => {
            DOMUtils.removeClass(slot, 'selected');
        });

        // Aplicar filtros guardados
        Object.entries(this.currentFilters.timeFilters).forEach(([day, times]) => {
            times.forEach(time => {
                const slot = DOMUtils.find(`[data-day="${day}"][data-time="${time}"]`);
                if (slot) {
                    DOMUtils.addClass(slot, 'selected');
                }
            });
        });
    }

    applyFilters() {
        if (this.onFiltersApplied) {
            // Preparar filtros para la UI
            const stateFilters = DataUtils.deepClone(this.currentFilters);
            
            // Preparar filtros para la API
            const apiFilters = this.prepareApiFilters();
            
            this.onFiltersApplied(stateFilters, apiFilters);
        }
        this.close();
    }

    prepareApiFilters() {
        const apiFilters = {};

        // Filtros de profesores
        if (Object.keys(this.currentFilters.professors).length > 0) {
            apiFilters.professors = {};
            
            Object.entries(this.currentFilters.professors).forEach(([subjectCode, professorFilters]) => {
                Object.entries(professorFilters).forEach(([professor, action]) => {
                    if (!apiFilters.professors[subjectCode]) {
                        apiFilters.professors[subjectCode] = { include: [], exclude: [] };
                    }
                    apiFilters.professors[subjectCode][action].push(professor);
                });
            });
        }

        // Filtros de tiempo (horarios no disponibles)
        if (Object.keys(this.currentFilters.timeFilters).length > 0) {
            apiFilters.unavailable_times = {};
            
            Object.entries(this.currentFilters.timeFilters).forEach(([day, times]) => {
                if (times.length > 0) {
                    // Convertir día a formato esperado por la API
                    const apiDay = this.dayToApiFormat(day);
                    apiFilters.unavailable_times[apiDay] = times;
                }
            });
        }

        return apiFilters;
    }

    dayToApiFormat(day) {
        // Mapear días a formato esperado por la API
        const dayMapping = {
            'monday': 'Lunes',
            'tuesday': 'Martes',
            'wednesday': 'Miércoles',
            'thursday': 'Jueves',
            'friday': 'Viernes',
            'saturday': 'Sábado',
            'sunday': 'Domingo'
        };
        return dayMapping[day] || day;
    }

    clearAllFilters() {
        // Limpiar filtros de profesores
        this.currentFilters.professors = {};
        
        // Limpiar filtros de tiempo
        this.currentFilters.timeFilters = {};
        
        // Actualizar UI
        this.renderProfessorFilters();
        this.loadTimeFilters();
    }

    open(subjects = []) {
        this.addedSubjects = subjects;
        this.renderProfessorFilters();
        this.loadTimeFilters();
        DOMUtils.addClass(this.modal, 'active');
    }

    close() {
        DOMUtils.removeClass(this.modal, 'active');
    }

    isOpen() {
        return this.modal.classList.contains('active');
    }

    setFilters(filters) {
        this.currentFilters = DataUtils.deepClone(filters);
    }

    getFilters() {
        return DataUtils.deepClone(this.currentFilters);
    }

    setFiltersAppliedCallback(callback) {
        this.onFiltersApplied = callback;
    }

    hasActiveFilters() {
        return Object.keys(this.currentFilters.professors).length > 0 ||
               Object.keys(this.currentFilters.timeFilters).length > 0;
    }
}

// Crear instancia global
window.filtersModal = new FiltersModal();
