# Créditos decimales: materias de 0.5 aparecían con 0 créditos

- Fecha: 2026-07-14
- Estado: Resuelto
- Tipo: Pérdida de precisión de datos (esquema)
- Alcance: Base de datos, ETL, API, generador, frontend

## 1. Síntoma

Materias con créditos fraccionarios (ej. "Seminario De Desarrollo Personal I", 0.5 créditos en Banner) aparecían en la app con **0 créditos**: no sumaban al contador del panel y no consumían cupo del límite de 20.

## 2. Causa raíz

La columna `Materia.Creditos` era **INTEGER**. Al insertar 0.5, Postgres redondea al tipo de la columna (0.5 → 0) **sin error**, así que el ETL guardaba 0 y todo lo de arriba (API, generador, frontend, donde `credits` era `int`) heredaba el valor truncado.

La cadena completa asumía créditos enteros:

| Capa | Antes | Ahora |
|------|-------|-------|
| BD (`Materia.Creditos`) | `INTEGER` | `NUMERIC(4,2)` |
| ETL (`parser.py`) | valor crudo de Banner | `obtener_creditos()` → `float` |
| Modelos (`models.py`) | `credits: int` | `credits: float` |
| Repositorio | `Decimal` de psycopg | `float(credits)` |
| Generador | poda con enteros | poda con `float` + EPSILON |
| Frontend (Dart) | `final int credits` | `final double credits` |

## 3. Impacto

- Materias de 0.5 créditos mostradas como 0 (2 en la oferta de 2026-2P).
- El contador de créditos del usuario subestimaba su carga.
- **Sin pérdida** de datos irrecuperable: el valor correcto vuelve a entrar con la siguiente corrida del ETL, una vez migrado el tipo de la columna.

## 4. Solución

1. **Esquema:** `Materia.Creditos` → `NUMERIC(4,2)`. Como `init.sql` solo se ejecuta con el volumen de Postgres vacío, se añadió `backend/scripts/migrar_esquema.py` (migraciones idempotentes) que corre al inicio de cada ETL y aplica el `ALTER TABLE` en bases ya creadas.
2. **ETL:** `parser.obtener_creditos()` conserva el decimal que publica Banner (`creditHourHigh` / `creditHourLow`).
3. **Backend:** `credits` es `float` en los modelos; el repositorio convierte el `Decimal` de psycopg (que no se puede sumar con floats) a `float`.
4. **Generador:** la poda por créditos usa `float` con una tolerancia EPSILON, para que una suma que da exactamente el tope (19.5 + 0.5 = 20) no se descarte por error de coma flotante.
5. **Frontend:** `credits` es `double` en los tres modelos; `credit_utils.dart` centraliza el parseo, el redondeo del acumulado y el formato (`0.5`, `3`, sin `.0` sobrante).

### Bug adicional encontrado

`main.py` inyectaba el tope del cliente como `credit_limit`, pero el generador lo lee de `max_credits`: **el límite enviado por el frontend nunca se aplicaba** y siempre caía al default de 20 del generador. Pasaba desapercibido porque el frontend envía exactamente 20. Corregido al mapear la clave correcta.

## 5. Prevención

- Tests en `tests/test_decimal_credits.py`: el parser no trunca 0.5, y el generador acepta 19.5 + 0.5 = 20 pero poda 20 + 0.5.
- (Futuro) Si Banner introduce otros tipos numéricos (ej. cupos decimales), revisar el resto de columnas `INTEGER` que reciben datos crudos.
