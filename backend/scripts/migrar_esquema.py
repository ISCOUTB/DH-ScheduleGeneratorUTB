# migrar_esquema.py
"""Migraciones de esquema idempotentes para bases de datos ya creadas.

`init.sql` solo lo ejecuta Postgres cuando el volumen de datos está vacío, así
que un cambio de esquema nunca llega por sí solo a una base existente (la de
producción). Este módulo aplica esos cambios en cada corrida del ETL.

Cada migración debe ser idempotente: comprueba el estado actual y no hace nada
si ya está aplicada.
"""
import psycopg
from config import get_connection


def _tipo_columna(cursor: psycopg.Cursor, tabla: str, columna: str) -> str | None:
    """Tipo de dato actual de una columna, o None si no existe."""
    cursor.execute(
        """
        SELECT data_type FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s AND column_name = %s
        """,
        (tabla, columna),
    )
    fila = cursor.fetchone()
    return fila[0] if fila else None


def _migrar_creditos_decimales(conn: psycopg.Connection) -> None:
    """`Materia.Creditos`: INTEGER -> NUMERIC(4,2).

    Banner publica materias con créditos fraccionarios (ej. 0.5). Con la columna
    en INTEGER, Postgres redondeaba al insertar (0.5 -> 0) y la app mostraba
    esas materias con 0 créditos.
    """
    cursor = conn.cursor()
    try:
        tipo = _tipo_columna(cursor, "materia", "creditos")
        if tipo is None or tipo == "numeric":
            return  # Tabla aún no creada, o migración ya aplicada.

        print(f"Migrando Materia.Creditos ({tipo} -> numeric(4,2))...")
        cursor.execute(
            "ALTER TABLE public.materia ALTER COLUMN creditos TYPE numeric(4,2)"
        )
        conn.commit()
        print("Migración aplicada: los créditos decimales ya no se redondean.")
    finally:
        cursor.close()


def _crear_tabla_curso_personalizado(conn: psycopg.Connection) -> None:
    """Crea `curso_personalizado` si no existe (cursos personalizados por usuario).

    `init.sql` solo corre en bases vacías; en la de producción esta tabla llega
    por esta migración. Idempotente vía `CREATE TABLE IF NOT EXISTS`.
    """
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS public.curso_personalizado (
                id SERIAL PRIMARY KEY,
                usuario_id INTEGER NOT NULL REFERENCES public.usuario(id),
                codigomateria VARCHAR NOT NULL,
                nombremateria VARCHAR NOT NULL,
                etiqueta VARCHAR,
                nrc VARCHAR,
                tipo VARCHAR,
                profesor VARCHAR,
                campus VARCHAR,
                activo BOOLEAN NOT NULL DEFAULT TRUE,
                bloques JSONB NOT NULL,
                created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
                FOREIGN KEY (codigomateria, nombremateria)
                    REFERENCES public.materia(codigomateria, nombre)
            )
            """
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_curso_pers_usuario "
            "ON public.curso_personalizado(usuario_id)"
        )
        conn.commit()
    finally:
        cursor.close()


def _agregar_etiqueta_curso_personalizado(conn: psycopg.Connection) -> None:
    """Agrega la columna `etiqueta` a `curso_personalizado` si falta.

    En tablas ya creadas (prod), `CREATE TABLE IF NOT EXISTS` no altera nada, así
    que la columna nueva llega por este `ADD COLUMN IF NOT EXISTS`. Idempotente.
    """
    cursor = conn.cursor()
    try:
        cursor.execute(
            "ALTER TABLE public.curso_personalizado "
            "ADD COLUMN IF NOT EXISTS etiqueta VARCHAR"
        )
        conn.commit()
    finally:
        cursor.close()


def _agregar_nombre_posicion_favoritos(conn: psycopg.Connection) -> None:
    """Agrega `nombre` y `posicion` a `horario_destacado` si faltan, y backfillea
    `posicion` desde `created_at` para las filas existentes.

    Permite nombrar y reordenar manualmente los destacados con persistencia. Los
    favoritos viejos arrancan con un orden coherente (el de creación) y sin
    nombre (se muestran como "Opción X"). Idempotente.
    """
    cursor = conn.cursor()
    try:
        cursor.execute(
            "ALTER TABLE public.horario_destacado ADD COLUMN IF NOT EXISTS nombre VARCHAR"
        )
        cursor.execute(
            "ALTER TABLE public.horario_destacado ADD COLUMN IF NOT EXISTS posicion INTEGER"
        )
        # Backfill: numera 0..N por usuario+term según fecha de creación, solo las
        # filas que aún no tienen posición.
        cursor.execute(
            """
            UPDATE public.horario_destacado h
            SET posicion = sub.rn
            FROM (
                SELECT id, ROW_NUMBER() OVER (
                    PARTITION BY usuario_id, term ORDER BY created_at, id
                ) - 1 AS rn
                FROM public.horario_destacado
                WHERE posicion IS NULL
            ) sub
            WHERE h.id = sub.id AND h.posicion IS NULL
            """
        )
        conn.commit()
    finally:
        cursor.close()


def aplicar_migraciones() -> None:
    """Aplica todas las migraciones pendientes. Seguro de ejecutar siempre."""
    conn = get_connection()
    try:
        _migrar_creditos_decimales(conn)
        _crear_tabla_curso_personalizado(conn)
        _agregar_etiqueta_curso_personalizado(conn)
        _agregar_nombre_posicion_favoritos(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    aplicar_migraciones()
