// api.js - Servicio para comunicación con la API

class ApiService {
    constructor() {
        this.baseUrl = CONFIG.API_BASE_URL;
        this.headers = {
            'Content-Type': 'application/json',
        };
    }

    /**
     * Realiza una petición HTTP genérica
     * @param {string} url - URL de la petición
     * @param {object} options - Opciones de la petición
     * @returns {Promise} Respuesta de la API
     */
    async request(url, options = {}) {
        try {
            const response = await fetch(url, {
                headers: this.headers,
                ...options
            });

            if (!response.ok) {
                throw new Error(`HTTP Error: ${response.status} - ${response.statusText}`);
            }

            // Verificar si la respuesta tiene contenido JSON
            const contentType = response.headers.get('content-type');
            if (contentType && contentType.includes('application/json')) {
                return await response.json();
            }
            
            return await response.text();
        } catch (error) {
            console.error('API Request Error:', error);
            throw new Error(`Error de conexión: ${error.message}`);
        }
    }

    /**
     * Obtiene la lista de todas las materias disponibles
     * @returns {Promise<Array>} Lista de materias resumidas
     */
    async getAllSubjects() {
        const url = CONFIG.getApiUrl(CONFIG.API_ENDPOINTS.SUBJECTS);
        
        try {
            const subjects = await this.request(url);
            
            // Validar que la respuesta sea un array
            if (!Array.isArray(subjects)) {
                throw new Error('La respuesta no es un array válido');
            }
            
            return subjects.map(subject => ({
                code: subject.code,
                name: subject.name,
                credits: subject.credits
            }));
        } catch (error) {
            console.error('Error getting all subjects:', error);
            throw new Error(CONFIG.getMessage('ERROR_LOADING_SUBJECTS'));
        }
    }

    /**
     * Obtiene los detalles completos de una materia específica
     * @param {string} subjectCode - Código de la materia
     * @returns {Promise<Object>} Detalles completos de la materia
     */
    async getSubjectDetails(subjectCode) {
        console.log('getSubjectDetails llamado para:', subjectCode);
        const url = CONFIG.getApiUrl(CONFIG.API_ENDPOINTS.SUBJECT_DETAILS, `/${subjectCode}`);
        
        try {
            const subject = await this.request(url);
            console.log('Respuesta de getSubjectDetails:', subject);
            
            // Validar estructura de la respuesta
            if (!subject.code || !subject.name) {
                console.error('Estructura de respuesta inválida:', subject);
                throw new Error('Estructura de respuesta inválida');
            }
            
            // Crear objeto de materia con estructura consistente
            const processedSubject = {
                code: subject.code,
                name: subject.name,
                credits: subject.credits || 0,
                classOptions: (subject.classOptions || []).map(option => ({
                    subjectName: option.subjectName,
                    subjectCode: option.subjectCode,
                    type: option.type,
                    schedules: option.schedules ? option.schedules.map(schedule => {
                        // Si el schedule tiene startTime y endTime separados, usarlos directamente
                        if (schedule.startTime && schedule.endTime) {
                            return {
                                day: schedule.day,
                                startTime: schedule.startTime,
                                endTime: schedule.endTime,
                                classroom: schedule.classroom || schedule.room || 'Por definir'
                            };
                        }
                        // Si tiene un campo 'time' con rango, parsearlo
                        else if (schedule.time) {
                            const { startTime, endTime } = TimeUtils.parseTimeRange(schedule.time);
                            return {
                                day: schedule.day,
                                startTime: startTime || 'N/A',
                                endTime: endTime || 'N/A',
                                classroom: schedule.classroom || schedule.room || 'Por definir'
                            };
                        }
                        // Fallback para datos incompletos
                        else {
                            console.warn('Formato de horario no reconocido:', schedule);
                            return {
                                day: schedule.day || 'Lunes',
                                startTime: 'N/A',
                                endTime: 'N/A',
                                classroom: schedule.classroom || schedule.room || 'Por definir'
                            };
                        }
                    }) : [],
                    professor: option.professor,
                    nrc: option.nrc,
                    groupId: option.groupId,
                    credits: option.credits,
                    campus: option.campus
                }))
            };
            
            console.log('Materia procesada:', processedSubject);
            return processedSubject;
        } catch (error) {
            console.error('Error getting subject details:', error);
            throw new Error(`Error al obtener detalles de la materia: ${error.message}`);
        }
    }

    /**
     * Genera horarios basados en las materias y filtros seleccionados
     * @param {Array} subjects - Lista de materias seleccionadas
     * @param {Object} filters - Filtros aplicados
     * @param {number} creditLimit - Límite de créditos
     * @returns {Promise<Array>} Lista de horarios generados
     */
    async generateSchedules(subjects, filters = {}, creditLimit = CONFIG.APP_CONFIG.CREDIT_LIMIT) {
        const url = CONFIG.getApiUrl(CONFIG.API_ENDPOINTS.GENERATE_SCHEDULES);
        
        try {
            // Preparar payload para la API
            const payload = {
                subjects: subjects.map(subject => subject.code),
                filters: {
                    ...filters,
                    max_credits: creditLimit
                }
            };

            console.log('Generating schedules with payload:', payload);

            const schedules = await this.request(url, {
                method: 'POST',
                body: JSON.stringify(payload)
            });

            // Validar que la respuesta sea un array
            if (!Array.isArray(schedules)) {
                throw new Error('La respuesta no es un array válido');
            }

            // Procesar y validar cada horario
            return schedules.map((schedule, index) => {
                if (!Array.isArray(schedule)) {
                    throw new Error(`Horario ${index} no es válido`);
                }

                return schedule.map(classOption => ({
                    subjectName: classOption.subjectName || classOption.subject_name || classOption.nombre,
                    subjectCode: classOption.subjectCode || classOption.subject_code || classOption.codigo,
                    type: classOption.type || classOption.tipo,
                    schedules: classOption.schedules?.map(s => {
                        // Si el schedule tiene startTime y endTime separados, usarlos directamente
                        if (s.startTime && s.endTime) {
                            return {
                                day: s.day || s.dia,
                                startTime: s.startTime,
                                endTime: s.endTime,
                                classroom: s.classroom || s.aula || s.salon || 'Por definir'
                            };
                        }
                        // Si tiene un campo 'time' con rango, parsearlo
                        else if (s.time) {
                            const { startTime, endTime } = TimeUtils.parseTimeRange(s.time);
                            return {
                                day: s.day || s.dia,
                                startTime: startTime || 'N/A',
                                endTime: endTime || 'N/A',
                                classroom: s.classroom || s.aula || s.salon || 'Por definir'
                            };
                        }
                        // Fallback usando nombres alternativos
                        else {
                            return {
                                day: s.day || s.dia,
                                startTime: s.start_time || s.hora_inicio || 'N/A',
                                endTime: s.end_time || s.hora_fin || 'N/A',
                                classroom: s.classroom || s.aula || s.salon || 'Por definir'
                            };
                        }
                    }) || [],
                    professor: classOption.professor || classOption.teacher_name || classOption.profesor,
                    nrc: classOption.nrc,
                    groupId: classOption.groupId || classOption.group_id || classOption.grupo_id,
                    credits: classOption.credits || classOption.creditos || 0,
                    campus: classOption.campus
                }));
            });
        } catch (error) {
            console.error('Error generating schedules:', error);
            throw new Error(CONFIG.getMessage('ERROR_GENERATING_SCHEDULES'));
        }
    }

    /**
     * Verifica la conectividad con la API
     * @returns {Promise<boolean>} True si la API está disponible
     */
    async checkApiHealth() {
        try {
            const url = CONFIG.getApiUrl(CONFIG.API_ENDPOINTS.SUBJECTS);
            await this.request(url);
            return true;
        } catch (error) {
            console.error('API Health Check Failed:', error);
            return false;
        }
    }

    /**
     * Cancela todas las peticiones pendientes
     */
    cancelAllRequests() {
        // En una implementación más avanzada, aquí se cancelarían
        // las peticiones usando AbortController
        console.log('Cancelling all pending requests...');
    }
}

// Crear instancia global del servicio API
window.apiService = new ApiService();
