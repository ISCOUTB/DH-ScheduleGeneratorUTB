// SubjectsList.js - Componente para la lista de materias seleccionadas

class SubjectsList {
    constructor() {
        this.container = DOMUtils.find('#subjects-list');
        this.emptyState = DOMUtils.find('#empty-subjects');
        this.usedCreditsElement = DOMUtils.find('#used-credits');
        this.creditLimitElement = DOMUtils.find('#credit-limit');
        
        this.subjects = [];
        this.usedCredits = 0;
        this.creditLimit = CONFIG.APP_CONFIG.CREDIT_LIMIT;
        this.onSubjectsChanged = null;
        
        this.init();
    }

    init() {
        this.creditLimitElement.textContent = this.creditLimit;
        // Comentado para que la página empiece siempre de cero
        // this.loadFromStorage();
        this.render();
    }

    addSubject(subject) {
        console.log('SubjectsList.addSubject llamado con:', subject);
        
        if (!subject) {
            console.error('Subject es null o undefined en addSubject');
            this.showMessage('Error: materia no válida', 'error');
            return false;
        }
        
        // Verificar si ya está agregada
        if (this.isSubjectAdded(subject.code)) {
            console.warn('Materia ya agregada:', subject.code);
            this.showMessage(CONFIG.getMessage('SUBJECT_ALREADY_ADDED'), 'warning');
            return false;
        }

        // Verificar límite de créditos
        const subjectCredits = subject.credits || 0;
        if (this.usedCredits + subjectCredits > this.creditLimit) {
            console.warn('Límite de créditos excedido:', this.usedCredits + subjectCredits, '>', this.creditLimit);
            this.showMessage(CONFIG.getMessage('CREDIT_LIMIT_EXCEEDED'), 'error');
            return false;
        }

        // Verificar límite de materias
        if (this.subjects.length >= CONFIG.APP_CONFIG.MAX_SELECTED_SUBJECTS) {
            console.warn('Límite de materias excedido:', this.subjects.length, '>=', CONFIG.APP_CONFIG.MAX_SELECTED_SUBJECTS);
            this.showMessage(
                CONFIG.getMessage('MAX_SUBJECTS_EXCEEDED', { 
                    max: CONFIG.APP_CONFIG.MAX_SELECTED_SUBJECTS 
                }), 
                'error'
            );
            return false;
        }

        // Agregar materia
        console.log('Agregando materia:', subject.code);
        this.subjects.push(subject);
        this.updateCredits();
        this.render();
        // Comentado para que no se guarden las materias
        // this.saveToStorage();
        this.notifyChange();

        console.log('Materia agregada exitosamente. Total materias:', this.subjects.length);
        this.showMessage(`${subject.code} agregada correctamente`, 'success');
        return true;
    }

    removeSubject(subjectCode) {
        const index = this.subjects.findIndex(s => s.code === subjectCode);
        if (index !== -1) {
            const removedSubject = this.subjects.splice(index, 1)[0];
            this.updateCredits();
            this.render();
            // Comentado para que no se guarden las materias
            // this.saveToStorage();
            this.notifyChange();

            this.showMessage(`${removedSubject.code} eliminada`, 'info');
            return true;
        }
        return false;
    }

    isSubjectAdded(subjectCode) {
        return this.subjects.some(s => s.code === subjectCode);
    }

    getSubjects() {
        return [...this.subjects];
    }

    clearAll() {
        this.subjects = [];
        this.updateCredits();
        this.render();
        // Comentado para que no se guarden las materias
        // this.saveToStorage();
        this.notifyChange();
    }

    updateCredits() {
        this.usedCredits = this.subjects.reduce((total, subject) => total + subject.credits, 0);
        this.usedCreditsElement.textContent = this.usedCredits;
        
        // Actualizar color basado en el porcentaje usado
        const percentage = (this.usedCredits / this.creditLimit) * 100;
        const creditsInfo = this.usedCreditsElement.closest('.credits-info');
        
        creditsInfo.classList.remove('warning', 'danger');
        
        if (percentage >= 100) {
            creditsInfo.classList.add('danger');
        } else if (percentage >= 80) {
            creditsInfo.classList.add('warning');
        }
    }

    render() {
        DOMUtils.clear(this.container);

        if (this.subjects.length === 0) {
            this.container.appendChild(this.emptyState);
            return;
        }

        // Ocultar empty state si está visible
        if (this.emptyState.parentNode === this.container) {
            this.container.removeChild(this.emptyState);
        }

        this.subjects.forEach((subject, index) => {
            const subjectCard = this.createSubjectCard(subject, index);
            this.container.appendChild(subjectCard);
        });
    }

    createSubjectCard(subject, index) {
        const card = DOMUtils.createElement('div', {
            className: 'subject-card',
            style: {
                borderLeft: `4px solid ${CONFIG.getSubjectColor(index)}`
            }
        });

        const header = DOMUtils.createElement('div', {
            className: 'subject-card-header'
        });

        const code = DOMUtils.createElement('span', {
            className: 'subject-code'
        }, subject.code);

        const removeBtn = DOMUtils.createElement('button', {
            className: 'subject-remove',
            title: 'Eliminar materia'
        }, '<i class="fas fa-times"></i>');

        header.appendChild(code);
        header.appendChild(removeBtn);

        const name = DOMUtils.createElement('div', {
            className: 'subject-name'
        }, subject.name);

        const info = DOMUtils.createElement('div', {
            className: 'subject-info'
        });

        const credits = DOMUtils.createElement('span', {
            className: 'subject-credits'
        }, `${subject.credits} créditos`);

        const classCount = DOMUtils.createElement('span', {
            className: 'subject-class-count',
            style: {
                marginLeft: 'var(--spacing-sm)',
                color: 'var(--text-tertiary)'
            }
        }, `${subject.classOptions?.length || 0} opciones`);

        info.appendChild(credits);
        info.appendChild(classCount);

        // Eventos
        EventUtils.on(removeBtn, 'click', (e) => {
            e.stopPropagation();
            this.removeSubject(subject.code);
        });

        card.appendChild(header);
        card.appendChild(name);
        card.appendChild(info);

        return card;
    }

    showMessage(message, type = 'info') {
        // Crear notification toast
        const toast = DOMUtils.createElement('div', {
            className: `toast ${type}`,
            style: {
                position: 'fixed',
                top: '20px',
                right: '20px',
                padding: 'var(--spacing-md)',
                borderRadius: 'var(--radius-md)',
                zIndex: '2000',
                maxWidth: '300px',
                boxShadow: 'var(--shadow-lg)',
                animation: 'slideInDown 0.3s ease-out'
            }
        });

        // Estilo según tipo
        const typeStyles = {
            success: {
                backgroundColor: 'var(--success-color)',
                color: 'white'
            },
            error: {
                backgroundColor: 'var(--error-color)',
                color: 'white'
            },
            warning: {
                backgroundColor: 'var(--warning-color)',
                color: 'white'
            },
            info: {
                backgroundColor: 'var(--info-color)',
                color: 'white'
            }
        };

        Object.assign(toast.style, typeStyles[type] || typeStyles.info);

        toast.textContent = message;

        document.body.appendChild(toast);

        // Auto-remove después de 3 segundos
        setTimeout(() => {
            if (toast.parentNode) {
                AnimationUtils.fadeOut(toast, 300, () => {
                    if (toast.parentNode) {
                        toast.parentNode.removeChild(toast);
                    }
                });
            }
        }, 3000);
    }

    saveToStorage() {
        StorageUtils.set(CONFIG.STORAGE_KEYS.SELECTED_SUBJECTS, this.subjects);
    }

    loadFromStorage() {
        const savedSubjects = StorageUtils.get(CONFIG.STORAGE_KEYS.SELECTED_SUBJECTS, []);
        this.subjects = savedSubjects;
        this.updateCredits();
    }

    notifyChange() {
        console.log('SubjectsList.notifyChange llamado. Materias actuales:', this.subjects.length);
        
        if (this.onSubjectsChanged) {
            console.log('Llamando callback onSubjectsChanged');
            this.onSubjectsChanged(this.subjects);
        } else {
            console.warn('onSubjectsChanged callback no está definido');
        }

        // Disparar evento personalizado
        console.log('Disparando evento subjectsChanged');
        EventUtils.trigger(document, 'subjectsChanged', {
            subjects: this.subjects,
            usedCredits: this.usedCredits
        });
    }

    setSubjectsChangedCallback(callback) {
        this.onSubjectsChanged = callback;
    }

    canAddMoreSubjects() {
        return this.subjects.length < CONFIG.APP_CONFIG.MAX_SELECTED_SUBJECTS;
    }

    getRemainingCredits() {
        return this.creditLimit - this.usedCredits;
    }

    getUsedCredits() {
        return this.usedCredits;
    }

    setCreditLimit(limit) {
        this.creditLimit = limit;
        this.creditLimitElement.textContent = limit;
        this.updateCredits();
    }
}

// Crear instancia global
window.subjectsList = new SubjectsList();
