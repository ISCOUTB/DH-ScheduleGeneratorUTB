// SearchModal.js - Componente del modal de búsqueda de materias

class SearchModal {
    constructor() {
        this.modal = DOMUtils.find('#search-modal');
        this.closeBtn = DOMUtils.find('#search-modal-close');
        this.searchInput = DOMUtils.find('#modal-search-input');
        this.resultsContainer = DOMUtils.find('#search-results');
        
        this.allSubjects = [];
        this.filteredSubjects = [];
        this.isLoading = false;
        this.onSubjectSelected = null;
        
        this.init();
    }

    init() {
        this.bindEvents();
        this.loadSubjects();
    }

    bindEvents() {
        // Cerrar modal
        EventUtils.on(this.closeBtn, 'click', () => this.close());
        EventUtils.on(this.modal, 'click', (e) => {
            if (e.target === this.modal) this.close();
        });

        // Búsqueda con debounce
        const debouncedSearch = EventUtils.debounce(
            (e) => this.handleSearch(e.target.value),
            CONFIG.APP_CONFIG.SEARCH_DEBOUNCE_DELAY
        );
        EventUtils.on(this.searchInput, 'input', debouncedSearch);

        // Navegación con teclado
        EventUtils.on(this.searchInput, 'keydown', (e) => this.handleKeyNavigation(e));
        EventUtils.on(document, 'keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen()) {
                this.close();
            }
        });
    }

    async loadSubjects() {
        if (this.allSubjects.length > 0) return;

        this.showLoadingState();
        
        try {
            this.allSubjects = await apiService.getAllSubjects();
            this.filteredSubjects = [...this.allSubjects];
            this.renderResults();
        } catch (error) {
            console.error('Error loading subjects:', error);
            this.showErrorState(error.message);
        }
    }

    handleSearch(query) {
        if (!query.trim()) {
            this.filteredSubjects = [...this.allSubjects];
        } else {
            this.filteredSubjects = DataUtils.filterItems(
                this.allSubjects,
                query,
                ['code', 'name']
            );
        }
        this.renderResults();
    }

    handleKeyNavigation(e) {
        const results = DOMUtils.findAll('.search-result-item:not(.disabled)', this.resultsContainer);
        const currentSelected = DOMUtils.find('.search-result-item.selected', this.resultsContainer);
        
        let newIndex = -1;
        
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (currentSelected) {
                const currentIndex = Array.from(results).indexOf(currentSelected);
                newIndex = Math.min(currentIndex + 1, results.length - 1);
            } else {
                newIndex = 0;
            }
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (currentSelected) {
                const currentIndex = Array.from(results).indexOf(currentSelected);
                newIndex = Math.max(currentIndex - 1, 0);
            } else {
                newIndex = results.length - 1;
            }
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (currentSelected && !currentSelected.classList.contains('disabled')) {
                const subjectCode = currentSelected.dataset.subjectCode;
                const subject = this.allSubjects.find(s => s.code === subjectCode);
                if (subject) this.selectSubject(subject);
            }
        }

        if (newIndex >= 0 && results[newIndex]) {
            // Remover selección anterior
            if (currentSelected) {
                DOMUtils.removeClass(currentSelected, 'selected');
            }
            
            // Añadir nueva selección
            DOMUtils.addClass(results[newIndex], 'selected');
            
            // Scroll al elemento si es necesario
            results[newIndex].scrollIntoView({
                block: 'nearest',
                behavior: 'smooth'
            });
        }
    }

    renderResults() {
        DOMUtils.clear(this.resultsContainer);

        if (this.filteredSubjects.length === 0) {
            this.showNoResultsState();
            return;
        }

        this.filteredSubjects.forEach(subject => {
            const resultItem = this.createResultItem(subject);
            this.resultsContainer.appendChild(resultItem);
        });
    }

    createResultItem(subject) {
        const isAlreadyAdded = window.app && window.app.isSubjectAdded(subject.code);
        
        const item = DOMUtils.createElement('div', {
            className: `search-result-item ${isAlreadyAdded ? 'disabled' : ''}`,
            'data-subject-code': subject.code
        });

        const header = DOMUtils.createElement('div', {
            className: 'search-result-header'
        });

        const code = DOMUtils.createElement('span', {
            className: 'search-result-code'
        }, subject.code);

        const credits = DOMUtils.createElement('span', {
            className: 'search-result-credits'
        }, `${subject.credits} créditos`);

        const name = DOMUtils.createElement('div', {
            className: 'search-result-name'
        }, subject.name);

        header.appendChild(code);
        header.appendChild(credits);
        item.appendChild(header);
        item.appendChild(name);

        if (isAlreadyAdded) {
            const addedLabel = DOMUtils.createElement('small', {
                style: { color: 'var(--text-tertiary)', fontStyle: 'italic' }
            }, 'Ya agregada');
            item.appendChild(addedLabel);
        }

        // Eventos
        if (!isAlreadyAdded) {
            EventUtils.on(item, 'click', () => this.selectSubject(subject));
            EventUtils.on(item, 'mouseenter', () => {
                const selected = DOMUtils.find('.search-result-item.selected', this.resultsContainer);
                if (selected) DOMUtils.removeClass(selected, 'selected');
                DOMUtils.addClass(item, 'selected');
            });
        }

        return item;
    }

    async selectSubject(subject) {
        console.log('selectSubject llamado con:', subject);
        
        if (!subject) {
            console.error('Subject es null o undefined en selectSubject');
            return;
        }
        
        if (this.onSubjectSelected) {
            try {
                // Obtener detalles completos de la materia
                console.log('Obteniendo detalles de la materia:', subject.code);
                const fullSubject = await apiService.getSubjectDetails(subject.code);
                console.log('Detalles obtenidos:', fullSubject);
                
                this.onSubjectSelected(fullSubject);
                this.close();
            } catch (error) {
                console.error('Error obteniendo detalles de la materia:', error);
                
                // Fallback: usar la materia básica si no se pueden obtener detalles
                console.log('Usando materia básica como fallback');
                const basicSubject = {
                    code: subject.code,
                    name: subject.name,
                    credits: subject.credits || 0,
                    classOptions: []
                };
                
                this.onSubjectSelected(basicSubject);
                this.close();
                this.showErrorMessage('Se agregó la materia con información básica. Algunos detalles pueden no estar disponibles.');
            }
        } else {
            console.warn('onSubjectSelected callback no está definido');
        }
    }

    showLoadingState() {
        this.resultsContainer.innerHTML = `
            <div class="loading-state">
                <i class="fas fa-spinner fa-spin"></i>
                <p>${CONFIG.getMessage('LOADING')}</p>
            </div>
        `;
    }

    showErrorState(message) {
        this.resultsContainer.innerHTML = `
            <div class="error-state">
                <i class="fas fa-exclamation-triangle"></i>
                <h3>Error</h3>
                <p>${message}</p>
                <button class="btn btn-primary" onclick="searchModal.loadSubjects()">
                    <i class="fas fa-redo"></i>
                    Reintentar
                </button>
            </div>
        `;
    }

    showNoResultsState() {
        this.resultsContainer.innerHTML = `
            <div class="no-results">
                <i class="fas fa-search"></i>
                <h3>No se encontraron resultados</h3>
                <p>Intenta con otros términos de búsqueda</p>
            </div>
        `;
    }

    showErrorMessage(message) {
        // Crear toast o notification
        const toast = DOMUtils.createElement('div', {
            className: 'toast error',
            style: {
                position: 'fixed',
                top: '20px',
                right: '20px',
                background: 'var(--error-color)',
                color: 'white',
                padding: 'var(--spacing-md)',
                borderRadius: 'var(--radius-md)',
                zIndex: '2000'
            }
        }, message);

        document.body.appendChild(toast);

        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 3000);
    }

    open() {
        DOMUtils.addClass(this.modal, 'active');
        this.searchInput.focus();
        this.searchInput.value = '';
        
        // Actualizar resultados para reflejar materias ya agregadas
        if (this.allSubjects.length > 0) {
            this.renderResults();
        }
    }

    close() {
        DOMUtils.removeClass(this.modal, 'active');
        this.searchInput.value = '';
        
        // Limpiar selección
        const selected = DOMUtils.find('.search-result-item.selected', this.resultsContainer);
        if (selected) DOMUtils.removeClass(selected, 'selected');
    }

    isOpen() {
        return this.modal.classList.contains('active');
    }

    setSubjectSelectedCallback(callback) {
        this.onSubjectSelected = callback;
    }

    refresh() {
        // Refrescar la lista para mostrar cambios en materias agregadas
        if (this.isOpen() && this.allSubjects.length > 0) {
            this.renderResults();
        }
    }
}

// Crear instancia global
window.searchModal = new SearchModal();
