# Fix: el rescatador solo traía la primera sección ligada

- Fecha: 2026-07-18
- Estado: Corregido
- Alcance: ETL (`backend/scripts/rescatador.py`)

## Contexto: qué es "rescatar" un curso

El scraper principal (`descargar_json.py`) baja toda la oferta del periodo paginada. Los cursos **ligados** (una sección que exige otra co-requisito, p. ej. teoría + laboratorio) a veces llegan sin su par en ese dump. `rescatador.py` lee del log los NRC que quedaron huérfanos y pide su(s) par(es) al endpoint de Banner:

```
GET .../ssb/searchResults/fetchLinkedSections?term={TERM}&courseReferenceNumber={NRC}
```

La respuesta trae `linkedData`: una **lista de grupos**, y cada grupo una **lista de secciones**. Un curso puede tener **varias** secciones ligadas alternativas (p. ej. dos grupos de laboratorio que sirven al mismo teórico).

## El bug

`rescatar_curso_ligado` devolvía **solo la primera**:

```python
linked_data = data.get("linkedData")
if linked_data and linked_data[0]:
    return linked_data[0][0]   # grupo 0, sección 0 — descarta el resto
```

Si `linkedData` tenía más de un grupo/sección, todas menos una se **descartaban** y esos NRC nunca entraban a la oferta en la BD.

### Evidencia (NRC 2583)

`fetchLinkedSections` para el NRC 2583 devolvió **dos grupos**:

```
grupo[0] = [2650]
grupo[1] = [2651]
```

El código devolvía solo `2650` (grupo 0, sección 0) y botaba `2651` (grupo 1). Por eso **el NRC 2651 no existía en la base de datos**.

## El fix

Aplanar todos los grupos y secciones y devolver **todas** (dedupe por NRC):

- `rescatar_curso_ligado` → `rescatar_cursos_ligados`, retorna `List[Dict]` con todas las secciones ligadas.
- `procesar_rescate` recorre la lista y agrega cada NRC nuevo que no esté ya en la oferta.

```python
linked_data = data.get("linkedData") or []
vistos = set()
for grupo in linked_data:
    for seccion in grupo:
        crn = seccion.get("courseReferenceNumber")
        if crn and crn not in vistos:
            vistos.add(crn)
            rescatados.append(seccion)
```

Verificado contra la respuesta real: antes `2650`; ahora `['2650', '2651']`.

## Despliegue

Es código ETL: corre en los servicios del `scripts.Dockerfile` (`cron-updater`, `initial-data`). El efecto se ve en la **próxima corrida del scraper**, y esos contenedores/imágenes deben **reconstruirse con el código actual** (ver la trampa del seeder en `17-07-2026-rfc-cursos-personalizados.md` §11, "Nota de despliegue").
