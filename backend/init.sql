-- Crear secuencia para ID de la tabla Clase
CREATE SEQUENCE clase_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Tabla Materia
CREATE TABLE materia (
    codigomateria VARCHAR PRIMARY KEY,
    creditos INTEGER NOT NULL,
    nombre VARCHAR NOT NULL
);

-- Tabla Profesor
CREATE TABLE profesor (
    bannerid VARCHAR PRIMARY KEY,
    nombre VARCHAR NOT NULL
);

-- Tabla Curso
CREATE TABLE curso (
    nrc INTEGER PRIMARY KEY,
    tipo VARCHAR NOT NULL,
    codigomateria VARCHAR NOT NULL,
    profesorid VARCHAR,
    nrcteorico INTEGER,
    groupid INTEGER,
    FOREIGN KEY (codigomateria) REFERENCES materia(codigomateria),
    FOREIGN KEY (profesorid) REFERENCES profesor(bannerid),
    FOREIGN KEY (nrcteorico) REFERENCES curso(nrc)
);

-- Tabla Clase
CREATE TABLE clase (
    nrc INTEGER NOT NULL,
    horainicio TIME NOT NULL,
    horafinal TIME NOT NULL,
    aula VARCHAR,
    dia VARCHAR NOT NULL,
    id INTEGER PRIMARY KEY DEFAULT nextval('clase_id_seq'),
    FOREIGN KEY (nrc) REFERENCES curso(nrc)
);
