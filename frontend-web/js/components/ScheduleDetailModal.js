// ScheduleDetailModal.js - Componente del modal de detalle de horario

class ScheduleDetailModal {
    constructor() {
        this.modal = DOMUtils.find('#schedule-detail-modal');
        this.closeBtn = DOMUtils.find('#schedule-detail-close');
        this.contentContainer = DOMUtils.find('#schedule-detail-content');
        
        this.currentSchedule = null;
        this.scheduleIndex = null;
        
        this.init();
    }

    init() {
        this.bindEvents();
    }

    bindEvents() {
        // Cerrar modal
        EventUtils.on(this.closeBtn, 'click', () => this.close());
        EventUtils.on(this.modal, 'click', (e) => {
            if (e.target === this.modal) this.close();
        });

        // Tecla Escape para cerrar
        EventUtils.on(document, 'keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen()) {
                this.close();
            }
        });
    }

    open(schedule, index) {
        this.currentSchedule = schedule;
        this.scheduleIndex = index;
        this.render();
        DOMUtils.addClass(this.modal, 'active');
    }

    close() {
        DOMUtils.removeClass(this.modal, 'active');
        this.currentSchedule = null;
        this.scheduleIndex = null;
    }

    isOpen() {
        return this.modal.classList.contains('active');
    }

    render() {
        if (!this.currentSchedule) return;

        DOMUtils.clear(this.contentContainer);

        const detailContainer = DOMUtils.createElement('div', {
            className: 'schedule-detail'
        });

        // Panel izquierdo - Información de materias
        const infoPanel = this.createInfoPanel();
        
        // Panel derecho - Grilla de horario
        const gridPanel = this.createGridPanel();

        detailContainer.appendChild(infoPanel);
        detailContainer.appendChild(gridPanel);
        this.contentContainer.appendChild(detailContainer);
    }

    createInfoPanel() {
        const panel = DOMUtils.createElement('div', {
            className: 'schedule-detail-info'
        });

        const title = DOMUtils.createElement('h4', {}, 
            `Horario #${this.scheduleIndex + 1}`
        );

        const subjectsContainer = DOMUtils.createElement('div', {
            className: 'detail-subjects'
        });

        // Agrupar materias por código para evitar duplicados
        const subjectsMap = new Map();
        this.currentSchedule.forEach(classOption => {
            if (!subjectsMap.has(classOption.subjectCode)) {
                subjectsMap.set(classOption.subjectCode, []);
            }
            subjectsMap.get(classOption.subjectCode).push(classOption);
        });

        // Crear cards para cada materia con colores consistentes
        let subjectIndex = 0;
        subjectsMap.forEach((classOptions, subjectCode) => {
            const colorIndex = subjectIndex % CONFIG.SUBJECT_COLORS.length;
            const subjectCard = this.createSubjectCard(classOptions, colorIndex);
            subjectsContainer.appendChild(subjectCard);
            subjectIndex++;
        });

        // Estadísticas del horario
        const stats = this.createScheduleStats();

        panel.appendChild(title);
        panel.appendChild(subjectsContainer);
        panel.appendChild(stats);

        return panel;
    }

    createSubjectCard(classOptions, colorIndex) {
        const firstOption = classOptions[0];
        const subjectColor = CONFIG.getSubjectColor(colorIndex);
        
        const card = DOMUtils.createElement('div', {
            className: 'detail-subject',
            style: {
                backgroundColor: subjectColor + '20', // 20 hace el color más transparente
                border: `2px solid ${subjectColor}`,
                borderRadius: 'var(--radius-sm)',
                padding: 'var(--spacing-md)',
                marginBottom: 'var(--spacing-md)'
            }
        });

        const header = DOMUtils.createElement('div', {
            className: 'detail-subject-header',
            style: {
                backgroundColor: subjectColor,
                color: 'white',
                padding: 'var(--spacing-sm)',
                borderRadius: 'var(--radius-xs)',
                marginBottom: 'var(--spacing-sm)',
                fontWeight: 'bold'
            }
        });

        const code = DOMUtils.createElement('span', {
            className: 'detail-subject-code',
            style: {
                color: 'white',
                fontWeight: 'bold',
                fontSize: 'var(--font-size-lg)'
            }
        }, firstOption.subjectCode);

        const name = DOMUtils.createElement('div', {
            className: 'detail-subject-name',
            style: {
                color: 'white',
                fontSize: 'var(--font-size-sm)',
                marginTop: 'var(--spacing-xs)'
            }
        }, firstOption.subjectName);

        header.appendChild(code);
        header.appendChild(name);

        // Información de cada opción de clase (teoría, laboratorio, etc.)
        const optionsContainer = DOMUtils.createElement('div', {
            className: 'detail-subject-options'
        });

        classOptions.forEach(option => {
            const optionCard = DOMUtils.createElement('div', {
                className: 'detail-subject-option',
                style: {
                    backgroundColor: 'rgba(255, 255, 255, 0.9)',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--radius-xs)',
                    marginBottom: 'var(--spacing-sm)',
                    border: '1px solid rgba(0, 0, 0, 0.1)'
                }
            });

            const typeAndGroup = DOMUtils.createElement('div', {
                style: {
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    marginBottom: 'var(--spacing-xs)'
                }
            });

            const type = DOMUtils.createElement('span', {
                className: 'detail-subject-type'
            }, option.type);

            const nrc = DOMUtils.createElement('span', {
                style: {
                    fontSize: 'var(--font-size-xs)',
                    color: 'var(--text-secondary)'
                }
            }, `NRC: ${option.nrc}`);

            typeAndGroup.appendChild(type);
            typeAndGroup.appendChild(nrc);

            const professor = DOMUtils.createElement('div', {
                style: {
                    fontSize: 'var(--font-size-sm)',
                    color: 'var(--text-primary)',
                    marginBottom: 'var(--spacing-xs)'
                }
            }, `Prof: ${option.professor}`);

            const schedules = DOMUtils.createElement('div', {
                style: {
                    fontSize: 'var(--font-size-xs)',
                    color: 'var(--text-secondary)'
                }
            });

            option.schedules.forEach(schedule => {
                const startTime = schedule.startTime || 'N/A';
                const endTime = schedule.endTime || 'N/A';
                const classroom = schedule.classroom || 'Por definir';
                
                let scheduleText;
                if (startTime === 'N/A' || endTime === 'N/A') {
                    scheduleText = `${schedule.day}: Horario por definir (${classroom})`;
                } else {
                    scheduleText = `${schedule.day}: ${startTime} - ${endTime} (${classroom})`;
                }
                
                const scheduleDiv = DOMUtils.createElement('div', {}, scheduleText);
                schedules.appendChild(scheduleDiv);
            });

            optionCard.appendChild(typeAndGroup);
            optionCard.appendChild(professor);
            optionCard.appendChild(schedules);
            optionsContainer.appendChild(optionCard);
        });

        card.appendChild(header);
        card.appendChild(optionsContainer);

        return card;
    }

    createScheduleStats() {
        const stats = DOMUtils.createElement('div', {
            className: 'schedule-stats',
            style: {
                marginTop: 'var(--spacing-lg)',
                padding: 'var(--spacing-md)',
                backgroundColor: 'var(--bg-secondary)',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--border-light)'
            }
        });

        const title = DOMUtils.createElement('h5', {
            style: {
                marginBottom: 'var(--spacing-md)',
                fontSize: 'var(--font-size-base)',
                fontWeight: '600'
            }
        }, 'Estadísticas');

        // Calcular estadísticas
        const totalCredits = this.currentSchedule.reduce((sum, option) => sum + option.credits, 0);
        const uniqueSubjects = new Set(this.currentSchedule.map(option => option.subjectCode)).size;
        const totalClasses = this.currentSchedule.length;

        // Calcular gaps entre clases
        const gaps = this.calculateTimeGaps();
        const avgGap = gaps.length > 0 ? gaps.reduce((sum, gap) => sum + gap, 0) / gaps.length : 0;

        // Días con clases
        const daysWithClasses = new Set();
        this.currentSchedule.forEach(option => {
            option.schedules.forEach(schedule => {
                daysWithClasses.add(schedule.day);
            });
        });

        const statsGrid = DOMUtils.createElement('div', {
            style: {
                display: 'grid',
                gridTemplateColumns: '1fr 1fr',
                gap: 'var(--spacing-md)',
                fontSize: 'var(--font-size-sm)'
            }
        });

        const statsData = [
            { label: 'Créditos totales', value: totalCredits },
            { label: 'Materias', value: uniqueSubjects },
            { label: 'Clases totales', value: totalClasses },
            { label: 'Días con clases', value: daysWithClasses.size },
            { label: 'Gap promedio', value: `${Math.round(avgGap)} min` },
            { label: 'Días libres', value: 7 - daysWithClasses.size }
        ];

        statsData.forEach(stat => {
            const statItem = DOMUtils.createElement('div', {
                style: {
                    display: 'flex',
                    justifyContent: 'space-between',
                    padding: 'var(--spacing-xs) 0'
                }
            });

            const label = DOMUtils.createElement('span', {
                style: { color: 'var(--text-secondary)' }
            }, stat.label);

            const value = DOMUtils.createElement('span', {
                style: { 
                    fontWeight: '600',
                    color: 'var(--text-primary)'
                }
            }, stat.value);

            statItem.appendChild(label);
            statItem.appendChild(value);
            statsGrid.appendChild(statItem);
        });

        stats.appendChild(title);
        stats.appendChild(statsGrid);

        return stats;
    }

    calculateTimeGaps() {
        const gaps = [];
        const daySchedules = {};

        // Agrupar horarios por día
        this.currentSchedule.forEach(option => {
            option.schedules.forEach(schedule => {
                // Solo procesar horarios válidos
                if (schedule.startTime && schedule.endTime && 
                    schedule.startTime !== 'N/A' && schedule.endTime !== 'N/A') {
                    
                    if (!daySchedules[schedule.day]) {
                        daySchedules[schedule.day] = [];
                    }
                    daySchedules[schedule.day].push({
                        start: TimeUtils.timeToMinutes(schedule.startTime),
                        end: TimeUtils.timeToMinutes(schedule.endTime)
                    });
                }
            });
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

    createGridPanel() {
        const panel = DOMUtils.createElement('div', {
            className: 'detail-schedule-grid'
        });

        const title = DOMUtils.createElement('h4', {}, 'Vista de Horario');

        const gridContainer = this.createScheduleGrid();

        panel.appendChild(title);
        panel.appendChild(gridContainer);

        return panel;
    }

    createScheduleGrid() {
        const container = DOMUtils.createElement('div', {
            className: 'schedule-grid-container'
        });

        // Header con días de la semana
        const header = DOMUtils.createElement('div', {
            className: 'schedule-grid-header'
        });

        const days = ['Hora', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
        days.forEach(day => {
            const cell = DOMUtils.createElement('div', {
                className: 'schedule-grid-header-cell'
            }, day);
            header.appendChild(cell);
        });

        // Body con horarios
        const body = DOMUtils.createElement('div', {
            className: 'schedule-grid-body'
        });

        // Crear mapa de clases por día y hora
        const classMap = this.createClassMap();

        // Generar filas por hora
        CONFIG.TIME_SLOTS.forEach(timeSlot => {
            // Celda de hora
            const timeCell = DOMUtils.createElement('div', {
                className: 'schedule-grid-time'
            }, timeSlot);
            body.appendChild(timeCell);

            // Celdas para cada día (en español)
            const spanishDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
            spanishDays.forEach(dayName => {
                const cell = DOMUtils.createElement('div', {
                    className: 'schedule-grid-cell'
                });

                // Verificar si hay clase en este horario
                const classInfo = this.findClassAtTime(classMap, dayName, timeSlot);
                if (classInfo) {
                    const classElement = this.createClassElement(classInfo);
                    cell.appendChild(classElement);
                }

                body.appendChild(cell);
            });
        });

        container.appendChild(header);
        container.appendChild(body);

        return container;
    }

    createClassMap() {
        const classMap = {};

        this.currentSchedule.forEach((option, index) => {
            option.schedules.forEach(schedule => {
                // Normalizar el día a español si viene en inglés o en formato diferente
                const normalizedDay = this.normalizeDayName(schedule.day);
                
                // Validar que las horas sean válidas
                const startTime = schedule.startTime;
                const endTime = schedule.endTime;
                
                if (!startTime || !endTime || startTime === 'N/A' || endTime === 'N/A') {
                    console.warn('Horario con horas inválidas:', schedule);
                    return;
                }
                
                const key = `${normalizedDay}-${startTime}`;
                if (!classMap[key]) {
                    classMap[key] = [];
                }
                classMap[key].push({
                    ...option,
                    schedule: schedule,
                    colorIndex: index % CONFIG.SUBJECT_COLORS.length
                });
            });
        });

        return classMap;
    }

    normalizeDayName(day) {
        // Mapeo de días en diferentes formatos a español
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
            'domingo': 'Domingo',
            'mon': 'Lunes',
            'tue': 'Martes',
            'wed': 'Miércoles',
            'thu': 'Jueves',
            'fri': 'Viernes',
            'sat': 'Sábado',
            'sun': 'Domingo'
        };
        
        return dayMapping[day?.toLowerCase()] || day;
    }

    findClassAtTime(classMap, day, time) {
        // Primero intentar coincidencia exacta
        const exactKey = `${day}-${time}`;
        if (classMap[exactKey]) {
            return classMap[exactKey][0]; // Tomar la primera si hay múltiples
        }
        
        // Si no hay coincidencia exacta, buscar clases que incluyan esta hora
        const timeMinutes = TimeUtils.timeToMinutes(time);
        
        for (const [key, classes] of Object.entries(classMap)) {
            const [classDay, classStartTime] = key.split('-');
            if (classDay === day) {
                const classInfo = classes[0];
                if (classInfo && classInfo.schedule) {
                    const startMinutes = TimeUtils.timeToMinutes(classInfo.schedule.startTime);
                    const endMinutes = TimeUtils.timeToMinutes(classInfo.schedule.endTime);
                    
                    // Verificar si la hora actual está dentro del rango de la clase
                    if (timeMinutes >= startMinutes && timeMinutes < endMinutes) {
                        return classInfo;
                    }
                }
            }
        }
        
        return null;
    }

    createClassElement(classInfo) {
        const element = DOMUtils.createElement('div', {
            className: 'schedule-grid-class',
            style: {
                backgroundColor: CONFIG.getSubjectColor(classInfo.colorIndex),
                textAlign: 'center',
                padding: '4px',
                fontSize: '0.9em',
                fontWeight: 'bold',
                color: 'white',
                borderRadius: '4px'
            }
        });

        // Solo mostrar el NRC
        const nrc = classInfo.nrc || 'Sin NRC';
        
        const nrcElement = DOMUtils.createElement('div', {
            className: 'schedule-grid-class-nrc'
        }, nrc);

        element.appendChild(nrcElement);

        return element;
    }
}

// Crear instancia global
window.scheduleDetailModal = new ScheduleDetailModal();
