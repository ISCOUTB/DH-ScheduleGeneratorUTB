// app.js - Aplicación principal

class ScheduleGeneratorApp {
    constructor() {
        this.selectedSubjects = [];
        this.appliedFilters = { professors: {}, timeFilters: {} };
        this.apiFilters = {};
        this.allSchedules = [];
        this.isGenerating = false;
        
        this.init();
    }

    async init() {
        console.log('Inicializando aplicación...');
        
        // Verificar conectividad con la API
        const apiHealthy = await this.checkApiHealth();
        if (!apiHealthy) {
            console.error('API no está disponible');
            this.showApiErrorMessage();
            return;
        }

        this.bindEvents();
        
        const componentsInitialized = this.initializeComponents();
        if (!componentsInitialized) {
            console.error('Error inicializando componentes');
            return;
        }
        
        this.loadSavedState();
        
        console.log('Aplicación inicializada correctamente');
        
        // Agregar estado de debugging global
        window.appDebug = {
            app: this,
            schedulesGrid: window.schedulesGrid,
            apiService: window.apiService,
            getState: () => this.getState(),
            testWithMockData: () => this.testWithMockData(),
            testSubjectSelection: () => this.testSubjectSelection(),
            showDebug: () => this.showDebugInfo(),
            hideDebug: () => this.hideDebugInfo()
        };
        
        console.log('Debug utilities available in window.appDebug');
    }

    async checkApiHealth() {
        try {
            return await apiService.checkApiHealth();
        } catch (error) {
            console.error('API health check failed:', error);
            return false;
        }
    }

    bindEvents() {
        // Eventos del panel izquierdo
        const searchBtn = DOMUtils.find('#search-btn');
        const filtersBtn = DOMUtils.find('#filters-btn');

        EventUtils.on(searchBtn, 'click', () => this.openSearchModal());
        EventUtils.on(filtersBtn, 'click', () => this.openFiltersModal());

        // Evento del botón de tutorial
        const tutorialBtn = DOMUtils.find('#tutorial-btn');
        if (tutorialBtn) {
            EventUtils.on(tutorialBtn, 'click', () => this.showTutorial());
        }

        // Eventos del input de búsqueda rápida
        const quickSearchInput = DOMUtils.find('#subject-search');
        EventUtils.on(quickSearchInput, 'focus', () => this.openSearchModal());
        EventUtils.on(quickSearchInput, 'click', () => this.openSearchModal());

        // Eventos de teclado globales
        EventUtils.on(document, 'keydown', (e) => this.handleGlobalKeyboard(e));

        // Eventos de componentes
        EventUtils.on(document, 'subjectsChanged', (e) => this.onSubjectsChanged(e.detail));
        
        // Configurar evento del botón de ordenar después de que el DOM esté listo
        setTimeout(() => {
            this.setupSortButton();
        }, 100);
    }

    setupSortButton() {
        const sortBtn = document.getElementById('sort-btn');
        if (sortBtn) {
            // Remover listeners previos para evitar duplicados
            const newSortBtn = sortBtn.cloneNode(true);
            sortBtn.parentNode.replaceChild(newSortBtn, sortBtn);
            
            // Agregar el nuevo listener
            newSortBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                console.log('Botón de ordenar clickeado');
                this.openSortModal();
            });
            
            console.log('Botón de ordenar configurado correctamente');
        } else {
            console.warn('Botón de ordenar no encontrado');
        }
    }

    initializeComponents() {
        console.log('Inicializando componentes...');
        
        // Verificar que todos los componentes estén disponibles
        const requiredComponents = [
            { name: 'searchModal', obj: window.searchModal },
            { name: 'filtersModal', obj: window.filtersModal },
            { name: 'sortModal', obj: window.sortModal },
            { name: 'subjectsList', obj: window.subjectsList },
            { name: 'schedulesGrid', obj: window.schedulesGrid },
            { name: 'scheduleDetailModal', obj: window.scheduleDetailModal }
        ];
        
        const missingComponents = requiredComponents.filter(comp => !comp.obj);
        
        if (missingComponents.length > 0) {
            console.error('Componentes faltantes:', missingComponents.map(c => c.name));
            this.showApiErrorMessage();
            return false;
        }
        
        try {
            // Configurar callbacks de los modales
            if (searchModal && typeof searchModal.setSubjectSelectedCallback === 'function') {
                searchModal.setSubjectSelectedCallback((subject) => this.onSubjectSelected(subject));
            } else {
                console.warn('searchModal no tiene el método setSubjectSelectedCallback');
            }
            
            if (filtersModal && typeof filtersModal.setFiltersAppliedCallback === 'function') {
                filtersModal.setFiltersAppliedCallback((stateFilters, apiFilters) => {
                    this.onFiltersApplied(stateFilters, apiFilters);
                });
            } else {
                console.warn('filtersModal no tiene el método setFiltersAppliedCallback');
            }

            // Configurar callback de la lista de materias
            if (subjectsList && typeof subjectsList.setSubjectsChangedCallback === 'function') {
                subjectsList.setSubjectsChangedCallback((subjects) => this.onSubjectsListChanged(subjects));
            } else {
                console.warn('subjectsList no tiene el método setSubjectsChangedCallback');
            }

            // Configurar modal de ordenamiento
            this.setupSortModal();
            
            console.log('Componentes inicializados correctamente');
            return true;
        } catch (error) {
            console.error('Error inicializando componentes:', error);
            return false;
        }
    }

    loadSavedState() {
        // Limpiar datos previos para empezar de cero
        this.selectedSubjects = [];
        this.appliedFilters = { professors: {}, timeFilters: {} };
        this.apiFilters = {};
        this.allSchedules = [];
    }

    onSubjectSelected(subject) {
        console.log('onSubjectSelected llamado con:', subject);
        
        if (!subject) {
            console.error('Subject es null o undefined');
            return;
        }
        
        try {
            const success = subjectsList.addSubject(subject);
            if (success) {
                console.log('Materia agregada exitosamente:', subject.code);
                // Actualizar modal de búsqueda para reflejar cambios
                if (searchModal && searchModal.refresh) {
                    searchModal.refresh();
                }
                this.updateDebugInfo();
            } else {
                console.warn('No se pudo agregar la materia:', subject.code);
            }
        } catch (error) {
            console.error('Error agregando materia:', error);
        }
    }

    onSubjectsChanged(detail) {
        this.selectedSubjects = detail.subjects;
        this.updateDebugInfo();
        
        // Limpiar horarios anteriores si hay cambios en las materias
        if (this.allSchedules.length > 0) {
            this.clearSchedules();
        }
    }

    onSubjectsListChanged(subjects) {
        console.log('onSubjectsListChanged llamado con:', subjects);
        this.selectedSubjects = subjects || [];
        console.log('selectedSubjects actualizados a:', this.selectedSubjects);
        this.updateDebugInfo();
        
        // Generar horarios automáticamente si hay materias seleccionadas
        if (this.selectedSubjects.length > 0) {
            // Delay pequeño para evitar llamadas múltiples muy rápidas
            clearTimeout(this.autoGenerateTimeout);
            this.autoGenerateTimeout = setTimeout(() => {
                this.generateSchedules();
            }, 500);
        } else {
            // Si no hay materias, limpiar horarios
            this.clearSchedules();
        }
    }

    onFiltersApplied(stateFilters, apiFilters) {
        this.appliedFilters = stateFilters;
        this.apiFilters = apiFilters;
        
        // Guardar filtros en localStorage
        StorageUtils.set(CONFIG.STORAGE_KEYS.APPLIED_FILTERS, stateFilters);
        
        // Actualizar indicador visual de filtros activos
        this.updateFiltersButton();
        
        // Regenerar horarios automáticamente cuando se apliquen filtros
        if (this.selectedSubjects.length > 0) {
            this.generateSchedules();
        }

        console.log('Filtros aplicados:', { stateFilters, apiFilters });
    }

    async generateSchedules() {
        console.log('=== INICIANDO GENERACIÓN DE HORARIOS ===');
        
        if (this.selectedSubjects.length === 0) {
            console.warn('No hay materias seleccionadas');
            this.showMessage('Selecciona al menos una materia para generar horarios', 'warning');
            return;
        }

        if (this.isGenerating) {
            console.warn('Ya se está generando horarios');
            return;
        }

        this.isGenerating = true;
        console.log('Estado de generación establecido a true');
        
        this.showLoadingState();
        
        console.log('Materias seleccionadas:', this.selectedSubjects);
        console.log('Filtros aplicados:', this.apiFilters);

        try {
            console.log('Llamando a apiService.generateSchedules...');
            
            const schedules = await apiService.generateSchedules(
                this.selectedSubjects,
                this.apiFilters,
                CONFIG.APP_CONFIG.CREDIT_LIMIT
            );

            console.log('Respuesta del API:', schedules);
            console.log(`Se recibieron ${schedules ? schedules.length : 0} horarios`);

            // Validar y filtrar horarios que puedan tener datos incompletos
            const validSchedules = Array.isArray(schedules) ? schedules.filter(schedule => {
                if (!Array.isArray(schedule)) {
                    console.warn('Horario no válido (no es array):', schedule);
                    return false;
                }
                
                // Verificar que cada clase tenga al menos información básica
                return schedule.every(classOption => {
                    const hasBasicInfo = (
                        (classOption.subjectName || classOption.subject_name) ||
                        (classOption.subjectCode || classOption.subject_code)
                    ) && classOption.schedules && Array.isArray(classOption.schedules);
                    
                    if (!hasBasicInfo) {
                        console.warn('Clase con información incompleta:', classOption);
                    }
                    
                    return hasBasicInfo;
                });
            }) : [];

            if (validSchedules.length !== (schedules ? schedules.length : 0)) {
                console.warn(`Se filtraron ${(schedules ? schedules.length : 0) - validSchedules.length} horarios con datos incompletos`);
            }

            console.log('Horarios válidos:', validSchedules);
            console.log('Estableciendo horarios en SchedulesGrid...');

            this.allSchedules = validSchedules;
            schedulesGrid.setSchedules(validSchedules);

            if (validSchedules.length === 0) {
                console.log('No se encontraron horarios válidos');
                this.showMessage('No se encontraron horarios válidos con los criterios seleccionados', 'info');
            } else {
                console.log(`Se generaron ${validSchedules.length} horarios válidos`);
                this.showMessage(`Se generaron ${validSchedules.length} horarios válidos`, 'success');
                this.hideWelcomeState();
            }

            // Comentado para que la página siempre empiece de cero
            // StorageUtils.set(CONFIG.STORAGE_KEYS.LAST_SCHEDULES, {
            //     schedules: validSchedules,
            //     subjects: this.selectedSubjects.map(s => s.code),
            //     timestamp: Date.now()
            // });

        } catch (error) {
            console.error('Error generating schedules:', error);
            console.error('Stack trace:', error.stack);
            this.showMessage(error.message || 'Error al generar horarios', 'error');
        } finally {
            console.log('Finalizando generación de horarios...');
            this.isGenerating = false;
            this.hideLoadingState();
            this.updateDebugInfo();
            console.log('=== FIN GENERACIÓN DE HORARIOS ===');
        }
    }

    openSearchModal() {
        searchModal.open();
    }

    openFiltersModal() {
        filtersModal.open(this.selectedSubjects);
    }

    showTutorial() {
        // Mostrar mensaje de funcionalidad en desarrollo
        this.showMessage('Funcionalidad en desarrollo', 'info');
    }

    openSortModal() {
        console.log('Intentando abrir modal de ordenamiento...');
        
        if (!window.sortModal) {
            console.error('window.sortModal no está disponible');
            return;
        }
        
        // Verificar que hay horarios para ordenar
        if (!this.allSchedules || this.allSchedules.length === 0) {
            console.warn('No hay horarios para ordenar');
            return;
        }
        
        console.log('Abriendo modal de ordenamiento...');
        window.sortModal.open();
    }

    setupSortModal() {
        if (window.sortModal) {
            window.sortModal.setOnSortChange((sortType) => {
                this.applySorting(sortType);
            });
        }
    }

    applySorting(sortType) {
        if (!this.allSchedules || this.allSchedules.length === 0) {
            return;
        }

        let sortedSchedules = [...this.allSchedules];

        if (!sortType) {
            // Sin ordenar - mantener orden original
            schedulesGrid.setSchedules(sortedSchedules);
            return;
        }

        console.log('Aplicando ordenamiento:', sortType);

        switch (sortType) {
            case 'morning':
                sortedSchedules.sort((a, b) => {
                    const morningScoreA = this.calculateMorningScore(a);
                    const morningScoreB = this.calculateMorningScore(b);
                    return morningScoreB - morningScoreA; // Mayor score primero
                });
                break;

            case 'afternoon':
                sortedSchedules.sort((a, b) => {
                    const afternoonScoreA = this.calculateAfternoonScore(a);
                    const afternoonScoreB = this.calculateAfternoonScore(b);
                    return afternoonScoreB - afternoonScoreA; // Mayor score primero
                });
                break;

            case 'lessGaps':
                sortedSchedules.sort((a, b) => {
                    const gapsA = this.calculateAverageGaps(a);
                    const gapsB = this.calculateAverageGaps(b);
                    return gapsA - gapsB; // Menor gaps primero
                });
                break;

            case 'moreGaps':
                sortedSchedules.sort((a, b) => {
                    const gapsA = this.calculateAverageGaps(a);
                    const gapsB = this.calculateAverageGaps(b);
                    return gapsB - gapsA; // Mayor gaps primero
                });
                break;

            case 'freeDays':
                sortedSchedules.sort((a, b) => {
                    const freeDaysA = this.calculateFreeDays(a);
                    const freeDaysB = this.calculateFreeDays(b);
                    return freeDaysB - freeDaysA; // Más días libres primero
                });
                break;
        }

        console.log('Horarios ordenados por:', sortType);
        schedulesGrid.setSchedules(sortedSchedules);
    }

    calculateTotalCredits(schedule) {
        return schedule.reduce((sum, option) => {
            const credits = option.credits || option.creditos || 0;
            return sum + (typeof credits === 'number' ? credits : parseInt(credits) || 0);
        }, 0);
    }

    calculateAverageGaps(schedule) {
        const daySchedules = {};
        
        // Agrupar clases por día
        schedule.forEach(option => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(s => {
                    const day = s.day || s.dia;
                    if (!daySchedules[day]) daySchedules[day] = [];
                    
                    const startTime = s.startTime || s.start_time || s.hora_inicio;
                    const endTime = s.endTime || s.end_time || s.hora_fin;
                    
                    if (startTime && endTime) {
                        daySchedules[day].push({
                            start: TimeUtils.timeToMinutes(startTime),
                            end: TimeUtils.timeToMinutes(endTime)
                        });
                    }
                });
            }
        });

        let totalGaps = 0;
        let gapCount = 0;

        // Calcular gaps por día
        Object.values(daySchedules).forEach(dayClasses => {
            if (dayClasses.length < 2) return;
            
            // Ordenar por hora de inicio
            dayClasses.sort((a, b) => a.start - b.start);
            
            // Calcular gaps entre clases consecutivas
            for (let i = 0; i < dayClasses.length - 1; i++) {
                const gap = dayClasses[i + 1].start - dayClasses[i].end;
                if (gap > 0) {
                    totalGaps += gap;
                    gapCount++;
                }
            }
        });

        return gapCount > 0 ? totalGaps / gapCount : 0;
    }

    calculateDaysWithClasses(schedule) {
        const daysSet = new Set();
        schedule.forEach(option => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(s => {
                    const day = s.day || s.dia;
                    if (day) daysSet.add(day);
                });
            }
        });
        return daysSet.size;
    }

    calculateFreeDays(schedule) {
        const totalDays = 6; // Lunes a Sábado
        const daysWithClasses = this.calculateDaysWithClasses(schedule);
        return totalDays - daysWithClasses;
    }

    calculateMorningScore(schedule) {
        let morningClasses = 0;
        let totalClasses = 0;
        
        schedule.forEach(option => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(s => {
                    totalClasses++;
                    const startTime = s.startTime || s.start_time || s.hora_inicio;
                    if (startTime) {
                        const hour = parseInt(startTime.split(':')[0]);
                        if (hour < 12) morningClasses++;
                    }
                });
            }
        });
        
        return totalClasses > 0 ? morningClasses / totalClasses : 0;
    }

    calculateAfternoonScore(schedule) {
        let afternoonClasses = 0;
        let totalClasses = 0;
        
        schedule.forEach(option => {
            if (option.schedules && Array.isArray(option.schedules)) {
                option.schedules.forEach(s => {
                    totalClasses++;
                    const startTime = s.startTime || s.start_time || s.hora_inicio;
                    if (startTime) {
                        const hour = parseInt(startTime.split(':')[0]);
                        if (hour >= 12) afternoonClasses++;
                    }
                });
            }
        });
        
        return totalClasses > 0 ? afternoonClasses / totalClasses : 0;
    }

    updateFiltersButton() {
        const filtersBtn = DOMUtils.find('#filters-btn');
        const hasFilters = filtersModal.hasActiveFilters();
        
        if (hasFilters) {
            DOMUtils.addClass(filtersBtn, 'active');
            filtersBtn.innerHTML = `
                <i class="fas fa-filter"></i>
                Filtros (activos)
            `;
        } else {
            DOMUtils.removeClass(filtersBtn, 'active');
            filtersBtn.innerHTML = `
                <i class="fas fa-filter"></i>
                Filtros
            `;
        }
    }

    // Funciones de debugging
    updateDebugInfo() {
        const debugInfo = DOMUtils.find('#debug-info');
        if (debugInfo) {
            DOMUtils.find('#debug-subjects', debugInfo).textContent = this.selectedSubjects.length;
            DOMUtils.find('#debug-schedules', debugInfo).textContent = this.allSchedules.length;
            DOMUtils.find('#debug-state', debugInfo).textContent = this.isGenerating ? 'Generando' : 'Listo';
            DOMUtils.find('#debug-api', debugInfo).textContent = window.apiService ? 'Conectado' : 'Desconectado';
        }
    }

    showDebugInfo() {
        const debugInfo = DOMUtils.find('#debug-info');
        if (debugInfo) {
            debugInfo.style.display = 'block';
            this.updateDebugInfo();
        }
    }

    hideDebugInfo() {
        const debugInfo = DOMUtils.find('#debug-info');
        if (debugInfo) {
            debugInfo.style.display = 'none';
        }
    }

    showLoadingState() {
        const loadingOverlay = DOMUtils.find('#loading-overlay');
        DOMUtils.addClass(loadingOverlay, 'active');
    }

    hideLoadingState() {
        const loadingOverlay = DOMUtils.find('#loading-overlay');
        DOMUtils.removeClass(loadingOverlay, 'active');
    }

    hideWelcomeState() {
        const welcomeState = DOMUtils.find('#welcome-state');
        if (welcomeState.style.display !== 'none') {
            AnimationUtils.fadeOut(welcomeState, 300, () => {
                welcomeState.style.display = 'none';
            });
        }
    }

    showWelcomeState() {
        const welcomeState = DOMUtils.find('#welcome-state');
        welcomeState.style.display = 'block';
        AnimationUtils.fadeIn(welcomeState);
    }

    clearSchedules() {
        this.allSchedules = [];
        schedulesGrid.setSchedules([]);
        this.showWelcomeState();
    }

    showMessage(message, type = 'info') {
        subjectsList.showMessage(message, type);
    }

    showApiErrorMessage() {
        const welcomeState = DOMUtils.find('#welcome-state');
        welcomeState.innerHTML = `
            <div class="error-state">
                <i class="fas fa-exclamation-triangle"></i>
                <h2>Error de Conexión</h2>
                <p>No se pudo conectar con el servidor. Verifica que el backend esté ejecutándose.</p>
                <button class="btn btn-primary" onclick="location.reload()">
                    <i class="fas fa-redo"></i>
                    Reintentar
                </button>
            </div>
        `;
    }

    handleGlobalKeyboard(e) {
        // Atajos de teclado globales
        if (e.ctrlKey || e.metaKey) {
            switch (e.key) {
                case 'k':
                    e.preventDefault();
                    this.openSearchModal();
                    break;
                case 'f':
                    e.preventDefault();
                    this.openFiltersModal();
                    break;
                case 'Enter':
                    if (this.selectedSubjects.length > 0 && !this.isGenerating) {
                        e.preventDefault();
                        this.generateSchedules();
                    }
                    break;
                case 'd':
                    e.preventDefault();
                    this.toggleDebugInfo();
                    break;
            }
        }
    }

    toggleDebugInfo() {
        const debugInfo = DOMUtils.find('#debug-info');
        if (debugInfo) {
            if (debugInfo.style.display === 'none') {
                this.showDebugInfo();
            } else {
                this.hideDebugInfo();
            }
        }
    }

    // Función de test para debugging
    async testWithMockData() {
        console.log('Ejecutando test con datos simulados...');
        
        // Simular horarios de prueba
        const mockSchedules = [
            [
                {
                    subjectName: "Matemáticas I",
                    subjectCode: "MAT101",
                    type: "Teoría",
                    schedules: [
                        {
                            day: "Lunes",
                            startTime: "08:00",
                            endTime: "10:00",
                            classroom: "A101"
                        },
                        {
                            day: "Miércoles", 
                            startTime: "08:00",
                            endTime: "10:00",
                            classroom: "A101"
                        }
                    ],
                    professor: "Dr. Juan Pérez",
                    credits: 3,
                    nrc: "12345"
                },
                {
                    subjectName: "Física I",
                    subjectCode: "FIS101", 
                    type: "Teoría",
                    schedules: [
                        {
                            day: "Martes",
                            startTime: "10:00",
                            endTime: "12:00",
                            classroom: "B201"
                        },
                        {
                            day: "Jueves",
                            startTime: "10:00", 
                            endTime: "12:00",
                            classroom: "B201"
                        }
                    ],
                    professor: "Dra. María García",
                    credits: 3,
                    nrc: "12346"
                }
            ]
        ];
        
        console.log('Estableciendo horarios simulados:', mockSchedules);
        
        this.allSchedules = mockSchedules;
        schedulesGrid.setSchedules(mockSchedules);
        this.hideWelcomeState();
        this.updateDebugInfo();
        
        console.log('Test completado. Verifica la grid de horarios.');
    }

    // Función de test para verificar selección de materias
    async testSubjectSelection() {
        console.log('=== INICIANDO TEST DE SELECCIÓN DE MATERIAS ===');
        
        try {
            // Simular materia de test
            const testSubject = {
                code: 'TEST101',
                name: 'Materia de Prueba',
                credits: 3,
                classOptions: []
            };
            
            console.log('Probando selección de materia:', testSubject);
            
            // Llamar directamente al método de selección
            this.onSubjectSelected(testSubject);
            
            console.log('Estado después de la selección:');
            console.log('- Materias seleccionadas:', this.selectedSubjects.length);
            console.log('- Materias en subjectsList:', subjectsList.subjects.length);
            
        } catch (error) {
            console.error('Error en test de selección:', error);
        }
        
        console.log('=== FIN TEST DE SELECCIÓN DE MATERIAS ===');
    }

    // Métodos públicos para interacción externa
    isSubjectAdded(subjectCode) {
        return subjectsList.isSubjectAdded(subjectCode);
    }

    tryDifferentFilters() {
        this.openFiltersModal();
    }

    // Métodos de estado para debugging
    getState() {
        return {
            selectedSubjects: this.selectedSubjects,
            appliedFilters: this.appliedFilters,
            schedulesCount: this.allSchedules.length,
            isGenerating: this.isGenerating
        };
    }

    // Método para exportar horarios (funcionalidad futura)
    exportSchedules(format = 'json') {
        if (this.allSchedules.length === 0) {
            this.showMessage('No hay horarios para exportar', 'warning');
            return;
        }

        const data = {
            schedules: this.allSchedules,
            subjects: this.selectedSubjects,
            filters: this.appliedFilters,
            generated: new Date().toISOString()
        };

        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = `horarios_utb_${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        this.showMessage('Horarios exportados correctamente', 'success');
    }
}

// Inicializar aplicación cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    window.app = new ScheduleGeneratorApp();
});

// Manejar errores globales
window.addEventListener('error', (e) => {
    console.error('Error global capturado:', e.error);
});

window.addEventListener('unhandledrejection', (e) => {
    console.error('Promise rechazada no manejada:', e.reason);
});
