# Modelo de Datos – DH-ScheduleGeneratorUTB

## Materia

- **Descripción:** Representa una asignatura académica.
- **Atributos:**
  - `CodigoMateria` (PK): Identificador único de la materia.
  - `Créditos`: Número de créditos académicos.
  - `Nombre`: Nombre de la materia.
- **Relaciones:**
  - Una **Materia** puede tener uno o varios **Cursos** asociados (relación 1:n).

---

## Curso

- **Descripción:** Representa una oferta específica de una materia en un periodo, como un grupo o sección.
- **Atributos:**
  - `NRC` (PK): Número de Registro de Curso, identificador único.
  - `Tipo`: Puede ser "Teórico", "Laboratorio" o "Teórico-Práctico".
  - `CodigoMateria` (FK): Referencia a la materia que pertenece.
  - `ProfesorID` (FK): Referencia al profesor que imparte el curso.
  - `NRCTeorico` (FK): Si es un laboratorio, referencia al NRC del curso teórico asociado.
  - `LinkIdentifier`: Identificador para vincular cursos relacionados.
- **Relaciones:**
  - Un **Curso** pertenece a una **Materia**.
  - Un **Curso** es impartido por un **Profesor**.
  - Un **Curso** puede estar ligado a varios cursos o a ninguno (por ejemplo, un curso teórico ligado a varios laboratorios).
  - Un **Curso** puede tener varias **Clases** (relativo a franjas horarias) asociadas (relación 1:n).

---

## Clase

- **Descripción:** Representa una sesión específica de un curso (por ejemplo, un bloque horario en un día específico).
- **Atributos:**
  - `NRC`, `Día`, `Aula`, `HoraInicio` (PK compuesta): Identifican de forma única la clase.
  - `HoraInicio`: Hora de inicio de la clase.
  - `HoraFinal`: Hora de finalización.
  - `Aula`: Aula donde se imparte.
  - `Día`: Día de la semana.
- **Relaciones:**
  - Una **Clase** pertenece a un **Curso** (relación n:1).

---

## Profesor

- **Descripción:** Representa a un docente.
- **Atributos:**
  - `BannerID` (PK): Identificador único del profesor.
  - `Nombre`: Nombre del profesor.
- **Relaciones:**
  - Un **Profesor** puede impartir varios **Cursos** (relación 1:n).
