from pydantic import BaseModel, Field, ConfigDict
from typing import List, Dict, Any, Optional

# Nota: Usamos alias para que los modelos Pydantic puedan trabajar con snake_case en Python pero exponer camelCase en el JSON, manteniendo la compatibilidad con los modelos de Dart.

class Schedule(BaseModel):
    day: str
    time: str

class ClassOption(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    
    subject_name: str = Field(..., alias='subjectName')
    subject_code: str = Field(..., alias='subjectCode')
    # Para decir si es una clase teórica o práctica, usamos un campo tipo str.
    type: str
    schedules: List[Schedule]
    professor: str
    
    nrc: str
    group_id: int = Field(..., alias='groupId')
    # Decimal: hay materias de créditos fraccionarios (ej. 0.5) en Banner.
    credits: float
    campus: str
    seats_available: int = Field(..., alias='seatsAvailable')
    seats_maximum: int = Field(..., alias='seatsMaximum')

class Subject(BaseModel):
    # Configuración para que los modelos Pydantic usen camelCase en lugar de snake_case
    # en el JSON generado, pero mantengan snake_case en Python.
    model_config = ConfigDict(populate_by_name=True)

    code: str
    name: str
    credits: float
    class_options: List[ClassOption] = Field(..., alias='classOptions')



# Se crea un modelo para identificar una materia de forma única (código y nombre).
class SubjectIdentifier(BaseModel):
    code: str
    name: str

# 2. Se actualiza el modelo de la petición para que use el nuevo modelo y acepte el límite de créditos.
class GenerateScheduleRequest(BaseModel):
    # Ahora se espera una lista de objetos SubjectIdentifier
    subjects: List[SubjectIdentifier]
    filters: Dict[str, Any]
    # El frontend envía 'creditLimit' (camelCase), se usa un alias para que Pydantic lo entienda como 'credit_limit'.
    # Float porque las materias pueden sumar medios créditos (ej. 19.5).
    credit_limit: float = Field(..., alias='creditLimit')
    # El cliente declara si es móvil; el backend limita los resultados solo en
    # ese caso (evita agotar la memoria del navegador móvil). Default false para
    # compatibilidad con clientes que no lo envíen.
    is_mobile: bool = Field(default=False, alias='isMobile')


class FilterLabel(BaseModel):
    """Filtro señalado por el diagnóstico. El texto lo compone el frontend."""
    # 'selected_nrcs' | 'include_professors' | 'exclude_professors' | 'unavailable_slots'
    type: str
    # Nombre de la materia, o el día para 'unavailable_slots'.
    target: str


class ScheduleDiagnosis(BaseModel):
    """
    Explicación de por qué no se generó ningún horario.

    Ver `docs/issues/17-07-2026-rfc-diagnostico-sin-horarios.md`. `shape` dice
    dónde vive el conflicto y `blame` de quién es la culpa: son ejes
    independientes.
    """
    # 'sin_oferta' | 'materia_sin_opciones' | 'par_incompatible' | 'conjunto_incompatible'
    shape: str
    # 'datos' | 'filtros' | 'estructural'
    blame: str
    # Materias señaladas, según el shape.
    subjects: List[str] = []
    # Pares que no tienen ninguna combinación compatible (solo par_incompatible).
    pairs: List[List[str]] = []
    # Materias tales que, quitándolas, sí habría horarios. Vacío = quitar una
    # sola no alcanza.
    removalOptions: List[str] = []
    # Filtros que, quitados por sí solos, desbloquean. Solo con blame='filtros';
    # vacío ahí significa que es la combinación de filtros, no uno puntual.
    blockingFilters: List[FilterLabel] = []


class GenerateScheduleResponse(BaseModel):
    """Respuesta del generador: horarios + si la lista fue truncada por el cap."""
    schedules: List[List[ClassOption]]
    # True si se aplicó el cap móvil y había más horarios de los devueltos.
    truncated: bool = False
    # Solo cuando `schedules` viene vacío: explica por qué. En el camino feliz es
    # None y no se calcula nada.
    diagnosis: Optional[ScheduleDiagnosis] = None