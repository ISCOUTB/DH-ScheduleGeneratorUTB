// SchedulesGrid.js - Componente para la grilla de horarios generados

class SchedulesGrid {
    constructor() {
        this.container = DOMUtils.find('#schedules-container');
        this.grid = DOMUtils.find('#schedules-grid');
        this.countElement = DOMUtils.find('#schedules-count');
        this.loadMoreBtn = DOMUtils.find('#load-more-btn');
        this.loadMoreContainer = DOMUtils.find('#load-more-container');
        this.sortBtn = DOMUtils.find('#sort-btn');
        
        this.allSchedules = [];
        this.displayedSchedules = [];
        this.currentPage = 0;
        this.itemsPerPage = CONFIG.APP_CONFIG.SCHEDULES_PER_PAGE;
        this.isLoading = false;
        this.sortCriteria = null;
        
        this.init();
    }

    init() {
        this.bindEvents();
    }

    bindEvents() {
        // Cargar más horarios
        EventUtils.on(this.loadMoreBtn, 'click', () => this.loadMoreSchedules());

        // Ordenar horarios
        EventUtils.on(this.sortBtn, 'click', () => this.showSortModal());

        // Scroll infinito (opcional)
        EventUtils.on(window, 'scroll', EventUtils.throttle(() => {
            const { scrollTop, scrollHeight, clientHeight } = document.documentElement;
            if (scrollTop + clientHeight >= scrollHeight - 100 && !this.isLoading) {
                this.loadMoreSchedules();
            }
        }, 100));
    }

    setSchedules(schedules) {
        console.log('SchedulesGrid.setSchedules called with:', schedules);
        
        // Validar que schedules sea un array
        if (!Array.isArray(schedules)) {
            console.error('setSchedules: schedules is not an array:', schedules);
            this.allSchedules = [];
        } else {
            // Filtrar horarios válidos
            const validSchedules = schedules.filter((schedule, index) => {
                if (!Array.isArray(schedule)) {
                    console.warn(`Schedule ${index} is not an array:`, schedule);
                    return false;
                }
                
                if (schedule.length === 0) {
                    console.warn(`Schedule ${index} is empty`);
                    return false;
                }
                
                return true;
            });
            
            if (validSchedules.length !== schedules.length) {
                console.warn(`Filtered out ${schedules.length - validSchedules.length} invalid schedules`);
            }
            
            this.allSchedules = validSchedules;
        }
        
        this.currentPage = 0;
        this.displayedSchedules = [];
        
        this.updateCount();
        this.clearGrid();
        
        if (this.allSchedules.length === 0) {
            this.showEmptyState();
            this.hide();
        } else {
            this.show();
            // Cargar horarios sin mostrar estado de carga del grid ya que el general está activo
            this.loadMoreSchedules(true);
        }
    }

    loadMoreSchedules(skipLoadingState = false) {
        console.log('=== SchedulesGrid.loadMoreSchedules ===');
        console.log('isLoading:', this.isLoading);
        console.log('displayedSchedules.length:', this.displayedSchedules.length);
        console.log('allSchedules.length:', this.allSchedules.length);
        console.log('skipLoadingState:', skipLoadingState);
        
        if (this.isLoading || this.displayedSchedules.length >= this.allSchedules.length) {
            console.log('Saliendo de loadMoreSchedules - ya cargando o no hay más horarios');
            return;
        }

        this.isLoading = true;
        if (!skipLoadingState) {
            this.showLoadingState();
        }
        console.log('Comenzando carga de más horarios...');

        // Simular un pequeño delay para mejor UX, pero no cuando se está cargando inicialmente
        const delay = skipLoadingState ? 0 : 300;
        setTimeout(() => {
            const startIndex = this.currentPage * this.itemsPerPage;
            const endIndex = Math.min(startIndex + this.itemsPerPage, this.allSchedules.length);
            
            console.log(`Cargando horarios del ${startIndex} al ${endIndex}`);
            
            const newSchedules = this.allSchedules.slice(startIndex, endIndex);
            console.log('Nuevos horarios a cargar:', newSchedules);
            
            newSchedules.forEach((schedule, index) => {
                try {
                    console.log(`Creando card para horario ${startIndex + index}:`, schedule);
                    const scheduleCard = this.createScheduleCard(schedule, startIndex + index);
                    this.grid.appendChild(scheduleCard);
                    
                    // Animación de entrada con fallback
                    setTimeout(() => {
                        try {
                            if (typeof AnimationUtils !== 'undefined' && AnimationUtils.fadeIn) {
                                AnimationUtils.fadeIn(scheduleCard);
                            } else {
                                // Fallback: simplemente hacer visible el elemento
                                scheduleCard.style.opacity = '1';
                                scheduleCard.style.transform = 'translateY(0)';
                            }
                        } catch (animError) {
                            console.warn('Error en animación, usando fallback:', animError);
                            scheduleCard.style.opacity = '1';
                            scheduleCard.style.transform = 'translateY(0)';
                        }
                    }, index * 50);
                } catch (error) {
                    console.error(`Error creando card para horario ${startIndex + index}:`, error);
                }
            });

            this.displayedSchedules.push(...newSchedules);
            this.currentPage++;
            
            console.log('Horarios mostrados actualizado:', this.displayedSchedules.length);
            
            this.updateLoadMoreButton();
            if (!skipLoadingState) {
                this.hideLoadingState();
            }
            this.isLoading = false;
            
            console.log('=== Fin loadMoreSchedules ===');
        }, delay);
    }

    createScheduleCard(schedule, index) {
        console.log(`Creando schedule card ${index}:`, schedule);
        
        // Validación básica del horario
        if (!Array.isArray(schedule)) {
            console.error('Schedule no es un array:', schedule);
            throw new Error(`Schedule ${index} no es un array válido`);
        }
        
        if (schedule.length === 0) {
            console.warn(`Schedule ${index} está vacío`);
        }

        const card = DOMUtils.createElement('div', {
            className: 'schedule-card',
            'data-schedule-index': index
        });

        try {
            // Header con índice
            const header = DOMUtils.createElement('div', {
                className: 'schedule-card-header'
            });

            const indexElement = DOMUtils.createElement('span', {
                className: 'schedule-index'
            }, `#${index + 1}`);

            header.appendChild(indexElement);

            // Preview del horario
            const preview = this.createSchedulePreview(schedule);

            // Estadísticas del horario
            const stats = this.createScheduleStats(schedule);

            // Eventos
            EventUtils.on(card, 'click', () => {
                try {
                    if (typeof scheduleDetailModal !== 'undefined' && scheduleDetailModal.open) {
                        scheduleDetailModal.open(schedule, index);
                    } else {
                        console.warn('scheduleDetailModal no está disponible');
                    }
                } catch (error) {
                    console.error('Error abriendo modal de detalle:', error);
                }
            });

            EventUtils.on(card, 'keydown', (e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    try {
                        if (typeof scheduleDetailModal !== 'undefined' && scheduleDetailModal.open) {
                            scheduleDetailModal.open(schedule, index);
                        }
                    } catch (error) {
                        console.error('Error abriendo modal de detalle con teclado:', error);
                    }
                }
            });

            // Hacer el card focusable para accesibilidad
            card.setAttribute('tabindex', '0');
            card.setAttribute('role', 'button');
            card.setAttribute('aria-label', `Ver detalles del horario ${index + 1}`);

            card.appendChild(header);
            card.appendChild(preview);
            card.appendChild(stats);

            console.log(`Schedule card ${index} creado exitosamente`);
            return card;
            
        } catch (error) {
            console.error(`Error creando contenido de schedule card ${index}:`, error);
            
            // Crear una card de error como fallback
            const errorCard = DOMUtils.createElement('div', {
                className: 'schedule-card error-card'
            });
            
            errorCard.innerHTML = `
                <div class="schedule-card-header">
                    <span class="schedule-index">#${index + 1}</span>
                </div>
                <div class="error-message">
                    <i class="fas fa-exclamation-triangle"></i>
                    <p>Error al cargar este horario</p>
                </div>
            `;
            
            return errorCard;
        }
    }

    createSchedulePreview(schedule) {
        const preview = DOMUtils.createElement('div', {
            className: 'schedule-preview-grid'
        });

        // Crear una grilla visual mini del horario
        const grid = this.createPreviewGrid(schedule);
        preview.appendChild(grid);

        return preview;
    }

    createPreviewGrid(schedule) {
        const container = DOMUtils.createElement('div', {
            className: 'preview-schedule-grid'
        });

        // Crear mapa de clases
        const classMap = this.createPreviewClassMap(schedule);

        // Header con días de la semana
        const header = DOMUtils.createElement('div', {
            className: 'preview-grid-header'
        });

        // Celda vacía para las horas
        const emptyCell = DOMUtils.createElement('div', {
            className: 'preview-grid-header-cell empty'
        });
        header.appendChild(emptyCell);

        // Días de la semana (abreviados)
        const days = ['L', 'M', 'X', 'J', 'V', 'S'];
        const fullDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
        
        days.forEach(day => {
            const dayCell = DOMUtils.createElement('div', {
                className: 'preview-grid-header-cell'
            }, day);
            header.appendChild(dayCell);
        });

        // Body de la grilla
        const body = DOMUtils.createElement('div', {
            className: 'preview-grid-body'
        });

        // Franjas horarias completas de 1 hora desde las 07:00 hasta las 20:00
        const timeSlots = [
            '07:00', '08:00', '09:00', '10:00', '11:00', '12:00', '13:00',
            '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'
        ];
        
        timeSlots.forEach(timeSlot => {
            // Celda de hora
            const timeCell = DOMUtils.createElement('div', {
                className: 'preview-grid-time'
            }, timeSlot);
            body.appendChild(timeCell);

            // Celdas para cada día
            fullDays.forEach(dayName => {
                const cell = DOMUtils.createElement('div', {
                    className: 'preview-grid-cell'
                });

                // Verificar si hay clase en este horario
                const classInfo = this.findClassAtTimeHour(classMap, dayName, timeSlot);
                if (classInfo) {
                    cell.classList.add('has-class');
                    cell.style.backgroundColor = CONFIG.getSubjectColor(classInfo.colorIndex);
                    
                    // Mostrar NRC en la celda
                    const nrcElement = DOMUtils.createElement('div', {
                        className: 'preview-grid-nrc'
                    }, classInfo.nrc || 'N/A');
                    
                    cell.appendChild(nrcElement);
                }

                body.appendChild(cell);
            });
        });

        container.appendChild(header);
        container.appendChild(body);

        return container;
    }

    createPreviewClassMap(schedule) {
        const classMap = {};

        schedule.forEach((option, index) => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(sched => {
                    const normalizedDay = this.normalizeDayName(sched.day);
                    if (!classMap[normalizedDay]) {
                        classMap[normalizedDay] = [];
                    }
                    
                    classMap[normalizedDay].push({
                        ...option,
                        schedule: sched,
                        colorIndex: index % CONFIG.SUBJECT_COLORS.length,
                        startTime: sched.startTime || sched.start_time || sched.hora_inicio,
                        endTime: sched.endTime || sched.end_time || sched.hora_fin
                    });
                });
            }
        });

        return classMap;
    }

    findClassAtTimeHour(classMap, day, timeHour) {
        const classes = classMap[day];
        if (!classes || classes.length === 0) return null;
        
        // Convertir la hora específica a minutos
        const hourMinutes = TimeUtils.timeToMinutes(timeHour);
        
        // Verificar si alguna clase incluye esta hora
        for (const classItem of classes) {
            if (!classItem.startTime || !classItem.endTime || 
                classItem.startTime === 'N/A' || classItem.endTime === 'N/A') {
                continue;
            }
            
            const classStart = TimeUtils.timeToMinutes(classItem.startTime);
            const classEnd = TimeUtils.timeToMinutes(classItem.endTime);
            
            // Verificar si la hora específica está dentro del rango de la clase
            if (hourMinutes >= classStart && hourMinutes < classEnd) {
                return classItem;
            }
        }
        
        return null;
    }

    findClassInTimeSlot(classMap, day, timeSlot) {
        const classes = classMap[day];
        if (!classes || classes.length === 0) return null;
        
        // Convertir la franja horaria a minutos
        const [startHour, endHour] = timeSlot.split('-').map(h => parseInt(h));
        const slotStart = startHour * 60;
        const slotEnd = endHour * 60;
        
        // Verificar si alguna clase se superpone con esta franja
        for (const classItem of classes) {
            if (!classItem.startTime || !classItem.endTime || 
                classItem.startTime === 'N/A' || classItem.endTime === 'N/A') {
                continue;
            }
            
            const classStart = TimeUtils.timeToMinutes(classItem.startTime);
            const classEnd = TimeUtils.timeToMinutes(classItem.endTime);
            
            // Verificar superposición
            if (classStart < slotEnd && classEnd > slotStart) {
                return classItem;
            }
        }
        
        return null;
    }

    createMiniScheduleGrid(schedule) {
        const container = DOMUtils.createElement('div', {
            className: 'mini-schedule-grid'
        });

        // Días de la semana (abreviados)
        const days = ['L', 'M', 'X', 'J', 'V', 'S'];
        const fullDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
        
        // Header con días
        const header = DOMUtils.createElement('div', {
            className: 'mini-grid-header'
        });
        
        days.forEach(day => {
            const dayCell = DOMUtils.createElement('div', {
                className: 'mini-grid-day'
            }, day);
            header.appendChild(dayCell);
        });
        
        // Crear mapa de clases por día y hora
        const classMap = this.createMiniClassMap(schedule);
        
        // Definir franjas horarias simplificadas para la vista mini
        const timeSlots = ['7-9', '9-11', '11-13', '13-15', '15-17', '17-19', '19-21'];
        
        // Body de la grilla
        const body = DOMUtils.createElement('div', {
            className: 'mini-grid-body'
        });
        
        timeSlots.forEach(timeSlot => {
            const row = DOMUtils.createElement('div', {
                className: 'mini-grid-row'
            });
            
            fullDays.forEach((fullDay, dayIndex) => {
                const cell = DOMUtils.createElement('div', {
                    className: 'mini-grid-cell'
                });
                
                // Verificar si hay clase en este día y franja horaria
                const hasClass = this.hasClassInTimeSlot(classMap, fullDay, timeSlot);
                if (hasClass) {
                    cell.classList.add('has-class');
                    cell.style.backgroundColor = CONFIG.getSubjectColor(hasClass.colorIndex);
                }
                
                row.appendChild(cell);
            });
            
            body.appendChild(row);
        });
        
        container.appendChild(header);
        container.appendChild(body);
        
        return container;
    }

    createMiniClassMap(schedule) {
        const classMap = {};
        
        schedule.forEach((option, index) => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(scheduleItem => {
                    // Normalizar el día
                    const day = this.normalizeDayName(scheduleItem.day);
                    
                    if (!classMap[day]) {
                        classMap[day] = [];
                    }
                    
                    classMap[day].push({
                        startTime: scheduleItem.startTime,
                        endTime: scheduleItem.endTime,
                        colorIndex: index % CONFIG.SUBJECT_COLORS.length,
                        nrc: option.nrc
                    });
                });
            }
        });
        
        return classMap;
    }

    normalizeDayName(day) {
        const dayMapping = {
            'monday': 'Lunes',
            'tuesday': 'Martes', 
            'wednesday': 'Miércoles',
            'thursday': 'Jueves',
            'friday': 'Viernes',
            'saturday': 'Sábado',
            'sunday': 'Domingo',
            'lunes': 'Lunes',
            'martes': 'Martes',
            'miércoles': 'Miércoles',
            'miercoles': 'Miércoles',
            'jueves': 'Jueves',
            'viernes': 'Viernes',
            'sábado': 'Sábado',
            'sabado': 'Sábado',
            'domingo': 'Domingo'
        };
        
        return dayMapping[day?.toLowerCase()] || day;
    }

    hasClassInTimeSlot(classMap, day, timeSlot) {
        const classes = classMap[day];
        if (!classes || classes.length === 0) return false;
        
        // Convertir la franja horaria a minutos
        const [startHour, endHour] = timeSlot.split('-').map(h => parseInt(h));
        const slotStart = startHour * 60;
        const slotEnd = endHour * 60;
        
        // Verificar si alguna clase se superpone con esta franja
        for (const classItem of classes) {
            if (!classItem.startTime || !classItem.endTime || 
                classItem.startTime === 'N/A' || classItem.endTime === 'N/A') {
                continue;
            }
            
            const classStart = TimeUtils.timeToMinutes(classItem.startTime);
            const classEnd = TimeUtils.timeToMinutes(classItem.endTime);
            
            // Verificar superposición
            if (classStart < slotEnd && classEnd > slotStart) {
                return classItem;
            }
        }
        
        return false;
    }

    createPreviewClassElement(classInfo, colorIndex) {
        const element = DOMUtils.createElement('div', {
            className: 'schedule-class',
            style: {
                borderLeft: `3px solid ${CONFIG.getSubjectColor(colorIndex)}`
            }
        });

        // Obtener información del horario
        const schedule = classInfo.schedule;
        let startTime = null;
        let endTime = null;
        
        if (schedule) {
            startTime = schedule.startTime || schedule.start_time || schedule.hora_inicio;
            endTime = schedule.endTime || schedule.end_time || schedule.hora_fin;
        }
        
        // Validar que las horas sean válidas
        if (!startTime || !endTime || startTime === 'N/A' || endTime === 'N/A') {
            startTime = null;
            endTime = null;
        }
        
        // Mostrar horario si está disponible
        if (startTime && endTime) {
            const timeText = `${startTime} - ${endTime}`;
            const timeElement = DOMUtils.createElement('div', {
                className: 'schedule-class-time'
            }, timeText);
            element.appendChild(timeElement);
        }

        // Mostrar el NRC
        const nrc = classInfo.nrc || 'Sin NRC';
        const nrcElement = DOMUtils.createElement('div', {
            className: 'schedule-class-nrc'
        }, nrc);

        element.appendChild(nrcElement);

        return element;
    }

    createScheduleStats(schedule) {
        const stats = DOMUtils.createElement('div', {
            className: 'schedule-stats'
        });

        // Calcular estadísticas de manera más robusta
        const totalCredits = schedule.reduce((sum, option) => {
            const credits = option.credits || option.creditos || 0;
            return sum + (typeof credits === 'number' ? credits : parseInt(credits) || 0);
        }, 0);
        
        const gaps = this.calculateTimeGaps(schedule);
        const avgGap = gaps.length > 0 ? Math.round(gaps.reduce((sum, gap) => sum + gap, 0) / gaps.length) : 0;
        
        const daysWithClasses = new Set();
        schedule.forEach(option => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(s => {
                    if (s.day) {
                        daysWithClasses.add(s.day);
                    }
                });
            }
        });

        const statsData = [
            { icon: 'fas fa-graduation-cap', label: 'Créditos', value: totalCredits || 0 },
            { icon: 'fas fa-clock', label: 'Gap prom.', value: `${avgGap}min` },
            { icon: 'fas fa-calendar-day', label: 'Días', value: daysWithClasses.size || 0 }
        ];

        statsData.forEach(stat => {
            const statElement = DOMUtils.createElement('div', {
                className: 'schedule-stat'
            });

            const icon = DOMUtils.createElement('i', {
                className: stat.icon
            });

            const text = DOMUtils.createElement('span', {}, 
                `${stat.label}: ${stat.value}`
            );

            statElement.appendChild(icon);
            statElement.appendChild(text);
            stats.appendChild(statElement);
        });

        return stats;
    }

    groupSchedulesByDay(schedule) {
        const dayGroups = {};

        // Agrupar clases por día
        schedule.forEach(option => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(scheduleItem => {
                    const day = scheduleItem.day;
                    if (!dayGroups[day]) {
                        dayGroups[day] = [];
                    }
                    
                    // Crear una entrada que mantenga tanto la información de la materia como el horario específico
                    dayGroups[day].push({
                        ...option,
                        schedules: [scheduleItem] // Solo este horario específico para este día
                    });
                });
            }
        });

        // Ordenar días de la semana
        const orderedDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        const ordered = {};
        
        orderedDays.forEach(day => {
            if (dayGroups[day] && dayGroups[day].length > 0) {
                ordered[day] = dayGroups[day];
            }
        });

        return ordered;
    }

    calculateTimeGaps(schedule) {
        const gaps = [];
        const daySchedules = {};

        // Agrupar horarios por día
        schedule.forEach(option => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(s => {
                    if (!daySchedules[s.day]) {
                        daySchedules[s.day] = [];
                    }
                    
                    // Verificar que startTime y endTime existan y sean válidos con diferentes variaciones
                    const startTime = s.startTime || s.start_time || s.hora_inicio;
                    const endTime = s.endTime || s.end_time || s.hora_fin;
                    
                    if (startTime && endTime) {
                        daySchedules[s.day].push({
                            start: TimeUtils.timeToMinutes(startTime),
                            end: TimeUtils.timeToMinutes(endTime)
                        });
                    }
                });
            }
        });

        // Calcular gaps para cada día
        Object.values(daySchedules).forEach(dayClasses => {
            if (dayClasses.length < 2) return;

            // Ordenar por hora de inicio
            dayClasses.sort((a, b) => a.start - b.start);

            // Calcular gaps entre clases consecutivas
            for (let i = 0; i < dayClasses.length - 1; i++) {
                const gap = dayClasses[i + 1].start - dayClasses[i].end;
                if (gap > 0) {
                    gaps.push(gap);
                }
            }
        });

        return gaps;
    }

    getDayAbbreviation(day) {
        const abbreviations = {
            'Lunes': 'Lun',
            'Martes': 'Mar',
            'Miércoles': 'Mié',
            'Jueves': 'Jue',
            'Viernes': 'Vie',
            'Sábado': 'Sáb',
            'Domingo': 'Dom'
        };
        return abbreviations[day] || day.substr(0, 3);
    }

    updateCount() {
        this.countElement.textContent = this.allSchedules.length;
    }

    updateLoadMoreButton() {
        const hasMore = this.displayedSchedules.length < this.allSchedules.length;
        
        if (hasMore) {
            DOMUtils.removeClass(this.loadMoreContainer, 'hidden');
            const remaining = this.allSchedules.length - this.displayedSchedules.length;
            this.loadMoreBtn.innerHTML = `
                <i class="fas fa-plus"></i>
                Cargar ${Math.min(remaining, this.itemsPerPage)} horarios más
            `;
        } else {
            DOMUtils.addClass(this.loadMoreContainer, 'hidden');
        }
    }

    showLoadingState() {
        if (this.displayedSchedules.length === 0) {
            // Mostrar loading en toda la grilla
            this.grid.innerHTML = `
                <div class="loading-state" style="grid-column: 1 / -1;">
                    <i class="fas fa-spinner fa-spin"></i>
                    <p>Cargando horarios...</p>
                </div>
            `;
        } else {
            // Mostrar loading en el botón
            this.loadMoreBtn.innerHTML = `
                <i class="fas fa-spinner fa-spin"></i>
                Cargando...
            `;
            this.loadMoreBtn.disabled = true;
        }
    }

    hideLoadingState() {
        this.loadMoreBtn.disabled = false;
    }

    showEmptyState() {
        this.grid.innerHTML = `
            <div class="no-results" style="grid-column: 1 / -1;">
                <i class="fas fa-calendar-times"></i>
                <h3>No se encontraron horarios</h3>
                <p>No hay horarios válidos con las materias y filtros seleccionados</p>
                <div style="margin-top: var(--spacing-lg);">
                    <button class="btn btn-primary" onclick="app.tryDifferentFilters()">
                        <i class="fas fa-filter"></i>
                        Ajustar Filtros
                    </button>
                </div>
            </div>
        `;
    }

    clearGrid() {
        DOMUtils.clear(this.grid);
    }

    show() {
        this.container.style.display = 'block';
    }

    hide() {
        this.container.style.display = 'none';
    }

    showSortModal() {
        // Implementación simple de ordenamiento
        const sortOptions = [
            { label: 'Menos gaps entre clases', value: 'gaps_asc' },
            { label: 'Más gaps entre clases', value: 'gaps_desc' },
            { label: 'Menos días con clases', value: 'days_asc' },
            { label: 'Más días con clases', value: 'days_desc' },
            { label: 'Menos créditos', value: 'credits_asc' },
            { label: 'Más créditos', value: 'credits_desc' }
        ];

        // Por simplicidad, usar prompt (en una implementación real se usaría un modal)
        const choice = prompt(
            'Seleccionar criterio de ordenamiento:\n' +
            sortOptions.map((opt, i) => `${i + 1}. ${opt.label}`).join('\n')
        );

        const choiceIndex = parseInt(choice) - 1;
        if (choiceIndex >= 0 && choiceIndex < sortOptions.length) {
            this.sortSchedules(sortOptions[choiceIndex].value);
        }
    }

    sortSchedules(criteria) {
        if (!this.allSchedules || this.allSchedules.length === 0) {
            console.warn('No hay horarios para ordenar');
            return;
        }

        const sortedSchedules = [...this.allSchedules];

        sortedSchedules.sort((a, b) => {
            let valueA, valueB;

            try {
                switch (criteria) {
                    case 'gaps_asc':
                    case 'gaps_desc':
                        valueA = this.calculateTimeGaps(a).reduce((sum, gap) => sum + gap, 0);
                        valueB = this.calculateTimeGaps(b).reduce((sum, gap) => sum + gap, 0);
                        break;
                    case 'days_asc':
                    case 'days_desc':
                        valueA = new Set(a.filter(opt => opt.schedules).flatMap(opt => opt.schedules.map(s => s.day))).size;
                        valueB = new Set(b.filter(opt => opt.schedules).flatMap(opt => opt.schedules.map(s => s.day))).size;
                        break;
                    case 'credits_asc':
                    case 'credits_desc':
                        valueA = a.reduce((sum, opt) => sum + (opt.credits || opt.creditos || 0), 0);
                        valueB = b.reduce((sum, opt) => sum + (opt.credits || opt.creditos || 0), 0);
                        break;
                    default:
                        return 0;
                }

                const comparison = valueA - valueB;
                return criteria.endsWith('_desc') ? -comparison : comparison;
            } catch (error) {
                console.error('Error al ordenar horarios:', error);
                return 0;
            }
        });

        // Actualizar allSchedules y mostrar
        this.allSchedules = sortedSchedules;
        this.displayedSchedules = [];
        this.currentPage = 0;
        this.updateCount();
        this.clearGrid();
        this.loadMoreSchedules(true);
    }

    refresh() {
        if (this.allSchedules.length > 0) {
            this.displayedSchedules = [];
            this.currentPage = 0;
            this.updateCount();
            this.clearGrid();
            this.loadMoreSchedules(true);
        }
    }

    getDisplayedCount() {
        return this.displayedSchedules.length;
    }

    getTotalCount() {
        return this.allSchedules.length;
    }

    // Método para debugging de horarios
    debugSchedule(schedule) {
        console.group('Debug Schedule:');
        console.log('Schedule data:', schedule);
        
        if (Array.isArray(schedule)) {
            schedule.forEach((classOption, index) => {
                console.group(`Class ${index}:`);
                console.log('Subject Code:', classOption.subjectCode || classOption.subject_code);
                console.log('Subject Name:', classOption.subjectName || classOption.subject_name);
                console.log('Type:', classOption.type || classOption.tipo);
                console.log('Professor:', classOption.professor || classOption.teacher_name || classOption.profesor);
                console.log('Credits:', classOption.credits || classOption.creditos);
                
                if (classOption.schedules && Array.isArray(classOption.schedules)) {
                    console.log('Schedule count:', classOption.schedules.length);
                    classOption.schedules.forEach((s, i) => {
                        console.log(`  Schedule ${i}:`, {
                            day: s.day,
                            startTime: s.startTime || s.start_time || s.hora_inicio,
                            endTime: s.endTime || s.end_time || s.hora_fin,
                            classroom: s.classroom || s.aula || s.salon
                        });
                    });
                } else {
                    console.warn('No schedules found for this class');
                }
                console.groupEnd();
            });
        } else {
            console.error('Schedule is not an array:', typeof schedule);
        }
        console.groupEnd();
    }
}

// Crear instancia global
window.schedulesGrid = new SchedulesGrid();
