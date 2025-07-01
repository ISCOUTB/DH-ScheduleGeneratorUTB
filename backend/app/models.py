from pydantic import BaseModel, Field, ConfigDict
from typing import List, Dict, Any

# Nota: Usamos alias para que los modelos Pydantic puedan trabajar con snake_case en Python pero exponer camelCase en el JSON, manteniendo la compatibilidad con tus modelos de Dart.

class Schedule(BaseModel):
    day: str
    time: str

class ClassOption(BaseModel):
    # SOLUCIÓN: Reemplazar la clase Config con model_config
    model_config = ConfigDict(populate_by_name=True)
    
    subject_name: str = Field(..., alias='subjectName')
    subject_code: str = Field(..., alias='subjectCode')
    type: str
    schedules: List[Schedule]
    professor: str
    nrc: str
    group_id: int = Field(..., alias='groupId')
    credits: int

class Subject(BaseModel):
    # SOLUCIÓN: Reemplazar la clase Config con model_config
    model_config = ConfigDict(populate_by_name=True)

    code: str
    name: str
    credits: int
    class_options: List[ClassOption] = Field(..., alias='classOptions')

# Modelo para la petición que recibiremos del frontend
class GenerateScheduleRequest(BaseModel):
    subjects: List[str] # Lista de códigos de materia
    filters: Dict[str, Any]