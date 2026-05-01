# Logica de Negocio para Union de Cursos (Banner)

Este documento registra la logica de negocio actualmente usada para unir cursos teoricos y laboratorios durante el procesamiento de datos de Banner.

Objetivo:
- Dejar explicitas las reglas que hoy funcionan en produccion.
- Evitar que futuros cambios rompan casos validos (ej. practicas solo laboratorio).
- Facilitar mejoras futuras en el algoritmo de union.

Importante:
- Esta logica refleja el comportamiento operativo observado en Banner y validado por negocio.
- Si alguien encuentra una forma mejor de unir cursos, se puede reemplazar, pero debe mantener compatibilidad funcional con estos casos.

## Contexto

Antes se hacia scraping de HTML con navegador. Hoy la extraccion usa respuestas JSON de endpoints de Banner.

Campos relevantes de la respuesta:
- `courseReferenceNumber` (NRC)
- `subjectCourse`
- `scheduleTypeDescription`
- `sequenceNumber`
- `linkIdentifier`
- `isSectionLinked`
- `openSection`

## Reglas de negocio confirmadas

1. La mayoria de laboratorios van ligados a un teorico.
2. Puede haber laboratorios solos en casos especiales (principalmente practicas).
3. En secciones ligadas:
   - El teorico suele tener `sequenceNumber` de una letra (ej. `G`).
   - Ese teorico suele tener `linkIdentifier` con la misma letra (ej. `G`).
   - Los laboratorios asociados suelen venir con `sequenceNumber` `G1`, `G2`, ..., `Gn`.
   - Normalmente el teorico aparece antes que sus laboratorios en la respuesta.
4. Existen cursos `teorico-practico`, pero hoy se tolera tratarlos como laboratorio para el armado de horarios.
5. El servidor de Banner ya devuelve esencialmente secciones abiertas (`openSection = true`), por lo que el flujo normal no depende de filtrar cerradas.
6. Se maneja un profesor por NRC en el modelo actual.

## Reglas de implementacion actuales

Estas reglas estan implementadas principalmente en:
- `backend/scripts/parser.py`
- `backend/app/db/repository.py`
- `backend/app/services/schedule_generator.py`

### 1) Normalizacion de tipo de curso

En el parser:
- Si `scheduleTypeDescription == TEORICO` => tipo `Teorico`
- Cualquier otro tipo => `Laboratorio`

Consecuencia:
- `teorico-practico` queda tratado como `Laboratorio`.

### 2) Union por grupos (GroupID)

Para cada entrada:
- Teorico:
  - Define su propio grupo base usando `subjectCourse` + NRC.
- Laboratorio ligado (`linkIdentifier` presente):
  - Busca teorico compatible de la misma materia usando prefijo de `sequenceNumber`.
  - Si encuentra teorico, comparte su grupo.
  - Si no encuentra teorico, se registra error y se descarta ese laboratorio.
- Laboratorio no ligado:
  - Se acepta como curso independiente (grupo propio).

### 3) Combinaciones validas para generar horarios

En `repository.py`, por cada grupo:
- Si hay teoricos y laboratorios: combina pares `Teorico + Laboratorio`.
- Si solo hay teoricos: genera opcion de teorico solo.
- Si solo hay laboratorios: genera opcion de laboratorio solo.

Nota:
- Esta tercera rama (`solo laboratorios`) corrige el bug historico de practicas que no aparecian en horarios.

### 4) Filtros NRC y expansion

En `schedule_generator.py`:
- Si el usuario selecciona NRC de teorico, se pueden expandir automaticamente laboratorios del mismo grupo.
- Si selecciona solo lab, se mantiene solo ese lab (sin expansion automatica extra).

## Casos especiales y decisiones

1. Laboratorio ligado sin teorico:
- Se considera inconsistencia de datos de origen.
- Se registra en log.
- Se descarta en parseo inicial.
- Luego el proceso de rescate intenta recuperar pares usando `fetchLinkedSections`.

2. Teorico ligado sin laboratorios:
- Se registra como anomalia para revision.
- No necesariamente se elimina el teorico del dataset final.

3. Practicas (solo laboratorio):
- Deben mantenerse como validas.
- No deben forzarse a tener teorico para participar en combinaciones.

## Supuestos operativos actuales

- El orden de resultados de Banner suele facilitar que el teorico aparezca antes que sus labs.
- La relacion teorico-lab por prefijo de `sequenceNumber` funciona para la mayoria de casos observados.
- `linkIdentifier` es la senal principal de seccion ligada.

Si Banner cambia estructura o convenciones de secuencia, esta logica puede requerir ajuste.

## Riesgos conocidos

1. Tratar `teorico-practico` como `Laboratorio` simplifica, pero pierde semantica.
2. La union por prefijo de secuencia depende de convenciones del origen.
3. Descartar laboratorio ligado sin teorico evita ruido en horarios, pero puede ocultar cursos validos si el origen llega incompleto.

## Guia para futuras mejoras

Si se propone una nueva estrategia de union, debe pasar estas condiciones minimas:

1. No romper practicas solo laboratorio.
2. Mantener union correcta teorico-lab cuando la seccion esta ligada.
3. Tolerar datos incompletos de Banner sin romper el pipeline completo.
4. Mantener trazabilidad de errores (logs claros de por que algo fue descartado).

## Criterio de aceptacion funcional

Se considera correcta la union cuando:
- Un par teorico-lab ligado entra como opcion conjunta de horario.
- Una practica solo laboratorio entra como opcion valida de horario.
- No se generan cruces internos artificiales por unir NRC incorrectos.
- Los errores de datos quedan registrados para auditoria tecnica.
