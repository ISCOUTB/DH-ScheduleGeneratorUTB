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


def aplicar_migraciones() -> None:
    """Aplica todas las migraciones pendientes. Seguro de ejecutar siempre."""
    conn = get_connection()
    try:
        _migrar_creditos_decimales(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    aplicar_migraciones()
