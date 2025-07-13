// SortModal.js - Componente del modal de ordenamiento

class SortModal {
    constructor() {
        // Verificar que el DOM esté listo antes de inicializar
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.initialize());
        } else {
            this.initialize();
        }
    }

    initialize() {
        this.modal = document.getElementById('sort-modal');
        this.closeBtn = document.getElementById('sort-modal-close');
        this.applySortBtn = document.getElementById('apply-sort-btn');
        this.clearSortBtn = document.getElementById('clear-sort-btn');
        
        this.currentSort = null;
        this.onSortChange = null;
        
        if (!this.modal) {
            console.error('SortModal: No se encontró el elemento #sort-modal');
            return;
        }

        // Verificar que todos los botones existan
        if (!this.applySortBtn) {
            console.error('SortModal: No se encontró el botón #apply-sort-btn');
        }
        if (!this.clearSortBtn) {
            console.error('SortModal: No se encontró el botón #clear-sort-btn');
        }
        
        this.init();
    }

    init() {
        this.bindEvents();
        console.log('SortModal inicializado correctamente');
    }

    bindEvents() {
        if (!this.modal) return;

        // Cerrar modal
        if (this.closeBtn) {
            this.closeBtn.addEventListener('click', (e) => {
                e.preventDefault();
                this.close();
            });
        }
        
        this.modal.addEventListener('click', (e) => {
            if (e.target === this.modal) this.close();
        });

        // Tecla Escape para cerrar
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen()) {
                this.close();
            }
        });

        // Aplicar ordenamiento
        if (this.applySortBtn) {
            this.applySortBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                console.log('Botón aplicar ordenamiento clickeado');
                this.applySort();
            });
        }
        
        // Limpiar ordenamiento
        if (this.clearSortBtn) {
            this.clearSortBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                console.log('Botón limpiar ordenamiento clickeado');
                this.clearSort();
            });
        }

        console.log('SortModal: Eventos configurados');
    }

    open() {
        if (!this.modal) {
            console.error('SortModal: Modal no está disponible');
            return;
        }

        // Marcar la opción actual
        if (this.currentSort) {
            const option = document.getElementById(`sort-${this.currentSort}`);
            if (option) {
                option.checked = true;
            }
        }
        
        this.modal.classList.add('active');
        console.log('SortModal: Modal abierto');
    }

    close() {
        if (!this.modal) return;
        
        this.modal.classList.remove('active');
        console.log('SortModal: Modal cerrado');
    }

    isOpen() {
        return this.modal && this.modal.classList.contains('active');
    }

    applySort() {
        const selectedOption = document.querySelector('input[name="sortBy"]:checked');
        if (selectedOption) {
            this.currentSort = selectedOption.value;
            console.log('SortModal: Aplicando ordenamiento:', this.currentSort);
            if (this.onSortChange) {
                this.onSortChange(this.currentSort);
            }
        }
        this.close();
    }

    clearSort() {
        this.currentSort = null;
        
        // Desmarcar todas las opciones
        const sortOptions = document.querySelectorAll('input[name="sortBy"]');
        sortOptions.forEach(option => {
            option.checked = false;
        });
        
        console.log('SortModal: Limpiando ordenamiento');
        if (this.onSortChange) {
            this.onSortChange(null);
        }
        this.close();
    }

    setOnSortChange(callback) {
        this.onSortChange = callback;
    }

    getCurrentSort() {
        return this.currentSort;
    }
}

// Crear instancia global
window.sortModal = new SortModal();
