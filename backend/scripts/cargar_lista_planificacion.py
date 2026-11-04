# cargar_lista_planificacion.py
"""Carga la lista de materias del período siguiente (planificación, HU #380 de la app).

Lee el JSON que genera `exportar_lista.py` (lista revisada en el Planificador UTB):
`{"term": "202710", "termLabel": "2027-1", "listVersion": "...", "subjects": [
{"code", "name", "bannerName", "nameTruncated", "subject", "credits", "levels",
"programs", "equivalentCodes"}]}`.

- Revisa la lista antes de tocar la base: los créditos de cada materia son un
  número entre 0 y 99,99, o null; si no, no se carga nada.
- Crea el período, o le actualiza la etiqueta y la versión. El estado y la
  ventana de edición no se tocan aquí; un período nuevo queda abierto.
- Crea o actualiza cada materia y la deja activa. Las que ya no vienen quedan
  inactivas: nunca se borran, porque puede haber planes que las tienen.
- Reemplaza las equivalencias del período por las del JSON (a un solo salto).

Todo en una transacción: si algo falla, la lista queda como estaba. Se corre a
mano una vez por período; no va en el cron de cada 10 minutos.

Uso (desde backend/): python scripts/cargar_lista_planificacion.py lista_materias_202710.json
"""
import json
import re
import sys
from dataclasses import dataclass
from typing import Any, Dict, List, Tuple

from psycopg.types.json import Jsonb


@dataclass(frozen=True)
class Lista:
    periodo: str
    etiqueta: str
    version: str
    materias: List[Dict[str, Any]]
    # Pares (código, código) en orden alfabético, cada uno una vez.
    equivalencias: List[Tuple[str, str]]


def _texto(valor: Any) -> str:
    return str(valor).strip() if valor is not None else ""


# Lo que cabe en `materia_planificable.creditos` (NUMERIC(4,2)).
MAX_CREDITOS = 99.99


def _creditos(valor: Any, codigo: str) -> float | None:
    """Los créditos de la materia: un número JSON (no booleano) entre 0 y 99,99,
    o null si no se conocen. Cualquier otra cosa es un `ValueError` que nombra
    la materia: una lista con créditos mal puestos no se carga."""
    if valor is None:
        return None
    if isinstance(valor, bool) or not isinstance(valor, (int, float)) or not 0 <= valor <= MAX_CREDITOS:
        raise ValueError(
            f"La materia {codigo} trae créditos inválidos ({valor!r}): "
            f"deben ser un número entre 0 y 99,99, o null"
        )
    return float(valor)


def leer_lista(datos: Any) -> Lista:
    """La lista de `datos` (el JSON ya leído). `ValueError` si no es una lista válida."""
    if not isinstance(datos, dict):
        raise ValueError("La lista no es un objeto JSON")
    periodo = _texto(datos.get("term"))
    if not re.fullmatch(r"\d{6}", periodo):
        raise ValueError("La lista no trae un período válido (ej. 202710)")
    etiqueta = _texto(datos.get("termLabel")) or f"{periodo[:4]}-{periodo[4]}"
    version = _texto(datos.get("listVersion"))
    if not version:
        raise ValueError("La lista no trae su versión (listVersion)")
    crudas = datos.get("subjects")
    if not isinstance(crudas, list) or not crudas:
        raise ValueError("La lista no trae materias")

    materias: List[Dict[str, Any]] = []
    vistos: set[str] = set()
    for cruda in crudas:
        if not isinstance(cruda, dict):
            raise ValueError("Una de las materias no es un objeto")
        codigo = _texto(cruda.get("code"))
        nombre = _texto(cruda.get("name"))
        if not codigo:
            raise ValueError("Una materia no trae código")
        if not nombre:
            raise ValueError(f"La materia {codigo} no trae nombre")
        if codigo in vistos:
            raise ValueError(f"El código {codigo} está repetido")
        vistos.add(codigo)
        materias.append({
            "codigo": codigo,
            "nombre": nombre,
            "nombre_banner": _texto(cruda.get("bannerName")) or None,
            "area": _texto(cruda.get("subject")) or None,
            "creditos": _creditos(cruda.get("credits"), codigo),
            "niveles": [_texto(n) for n in cruda.get("levels") or [] if _texto(n)],
            "programas": [_texto(p) for p in cruda.get("programs") or [] if _texto(p)],
            "nombre_cortado": bool(cruda.get("nameTruncated")),
            "equivalentes": [_texto(e) for e in cruda.get("equivalentCodes") or []],
        })

    pares = sorted({
        tuple(sorted((m["codigo"], e)))
        for m in materias
        for e in m["equivalentes"]
        if e in vistos and e != m["codigo"]
    })
    return Lista(periodo, etiqueta, version, materias, pares)


def _guardar_periodo(cur, lista: Lista) -> int:
    cur.execute(
        """
        INSERT INTO public.periodo_planificacion (periodo, etiqueta, version_lista)
        VALUES (%s, %s, %s)
        ON CONFLICT (periodo) DO UPDATE
            SET etiqueta = EXCLUDED.etiqueta,
                version_lista = EXCLUDED.version_lista,
                updated_at = NOW()
        RETURNING id
        """,
        (lista.periodo, lista.etiqueta, lista.version),
    )
    return cur.fetchone()[0]


def _guardar_materias(cur, periodo_id: int, materias: List[Dict[str, Any]]) -> Tuple[Dict[str, int], int]:
    """Crea o actualiza cada materia (activa). Devuelve {código: id} y cuántas son nuevas."""
    ids: Dict[str, int] = {}
    nuevas = 0
    for m in materias:
        cur.execute(
            """
            INSERT INTO public.materia_planificable
                (periodo_id, codigo, nombre, nombre_banner, area, creditos,
                 niveles, programas, nombre_cortado, activa)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE)
            ON CONFLICT (periodo_id, codigo) DO UPDATE
                SET nombre = EXCLUDED.nombre,
                    nombre_banner = EXCLUDED.nombre_banner,
                    area = EXCLUDED.area,
                    creditos = EXCLUDED.creditos,
                    niveles = EXCLUDED.niveles,
                    programas = EXCLUDED.programas,
                    nombre_cortado = EXCLUDED.nombre_cortado,
                    activa = TRUE
            RETURNING id, (xmax = 0) AS nueva
            """,
            (
                periodo_id, m["codigo"], m["nombre"], m["nombre_banner"], m["area"],
                m["creditos"], Jsonb(m["niveles"]), Jsonb(m["programas"]), m["nombre_cortado"],
            ),
        )
        materia_id, nueva = cur.fetchone()
        ids[m["codigo"]] = materia_id
        nuevas += 1 if nueva else 0
    return ids, nuevas


def _inactivar_ausentes(cur, periodo_id: int, codigos: List[str]) -> int:
    """Deja inactivas las materias del período que ya no vienen en la lista."""
    cur.execute(
        """
        UPDATE public.materia_planificable SET activa = FALSE
        WHERE periodo_id = %s AND activa AND NOT (codigo = ANY(%s))
        """,
        (periodo_id, codigos),
    )
    return cur.rowcount


def _reemplazar_equivalencias(cur, periodo_id: int, ids: Dict[str, int], pares: List[Tuple[str, str]]) -> int:
    cur.execute("DELETE FROM public.equivalencia_materia WHERE periodo_id = %s", (periodo_id,))
    for a, b in pares:
        menor, mayor = sorted((ids[a], ids[b]))
        cur.execute(
            """
            INSERT INTO public.equivalencia_materia (periodo_id, materia_a_id, materia_b_id)
            VALUES (%s, %s, %s) ON CONFLICT DO NOTHING
            """,
            (periodo_id, menor, mayor),
        )
    return len(pares)


def cargar(conn, lista: Lista) -> Dict[str, Any]:
    """Guarda `lista` en una sola transacción y devuelve un resumen de lo hecho."""
    with conn.transaction():
        cur = conn.cursor()
        try:
            periodo_id = _guardar_periodo(cur, lista)
            ids, nuevas = _guardar_materias(cur, periodo_id, lista.materias)
            inactivadas = _inactivar_ausentes(cur, periodo_id, list(ids))
            equivalencias = _reemplazar_equivalencias(cur, periodo_id, ids, lista.equivalencias)
        finally:
            cur.close()
    return {
        "periodo": lista.periodo,
        "materias": len(ids),
        "nuevas": nuevas,
        "inactivadas": inactivadas,
        "equivalencias": equivalencias,
    }


def main(argv: List[str]) -> int:
    if len(argv) != 2:
        print("Uso: python scripts/cargar_lista_planificacion.py <lista.json>")
        return 2
    try:
        with open(argv[1], encoding="utf-8") as archivo:
            lista = leer_lista(json.load(archivo))
    except (OSError, ValueError) as e:
        print(f"No se cargó la lista: {e}")
        return 1

    from config import get_connection  # solo al correrlo: las pruebas no necesitan .env

    conn = get_connection()
    try:
        resumen = cargar(conn, lista)
    finally:
        conn.close()
    print(
        f"Período {resumen['periodo']}: {resumen['materias']} materias "
        f"({resumen['nuevas']} nuevas, {resumen['inactivadas']} inactivadas), "
        f"{resumen['equivalencias']} pares de equivalentes."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
