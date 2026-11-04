# Registro Técnico: Planificación del próximo período (UTB App)

- Fecha: 2026-11-04
- Estado: Implementado en `feature/planificacion-materias` · despliegue **pendiente**
- Tipo: Funcionalidad / Base de datos
- Alcance: Backend (`routes/planning_routes.py`, `db/repository.py`, `scripts/`), base de datos (tablas y vistas nuevas), UTB App

## 1. Contexto

La app móvil institucional (UTB App) permite que el estudiante arme, antes de que se publique la oferta, la lista de materias que piensa ver el próximo período y cuente cómo prefiere su horario (HU #380 de `utb-mob-utbapp`). Por decisión del 29 de octubre de 2026, esos datos se guardan en este backend, el mismo que la app ya usa para el generador.

La oferta de 2027-1 aún no existe, así que las materias que se pueden elegir salen de una lista construida con consultas de solo lectura al ORDS de Banner, que se carga con un script (sección 2.3). Esta lista es independiente de la oferta (`materia`) y no la modifica.

## 2. Qué se agrega

### 2.1 Tablas y vistas

| Objeto | Qué guarda |
|---|---|
| `periodo_planificacion` | El período que se planifica (`202710`), su etiqueta, la versión de la lista, el estado (`borrador`, `abierto`, `cerrado`) y la ventana de edición (`abre`, `cierra`) |
| `materia_planificable` | Las materias de la lista: código, nombre, área, créditos, niveles, programas y si está activa. Una materia que sale de la lista no se borra: queda inactiva |
| `equivalencia_materia` | Pares de códigos que son la misma materia (código viejo y nuevo de las mallas 2026) |
| `plan_estudiante` | Un plan por estudiante y período, con sus preferencias de horario (`jornadas`, `dias_libres`, `motivos`) y cuándo las respondió |
| `plan_materia` | Las materias de cada plan, en su orden |
| Vista `demanda_planificacion` | Cuántos estudiantes planean ver cada materia; no muestra conteos de menos de 10 |
| Vista `preferencias_planificacion` | Cuántos estudiantes eligieron cada jornada, día libre y motivo; no muestra conteos de menos de 10 |

Todas las fechas son `TIMESTAMP WITH TIME ZONE`. El detalle de columnas está en `docs/modelo_datos.md`.

### 2.2 Rutas

| Ruta | Sesión | Qué hace |
|---|---|---|
| `GET /api/planning/current` | No | El período que se planifica (abierto y dentro de su ventana); 404 si no hay |
| `GET /api/planning/{term}/subjects` | No | La lista activa del período; 404 si no existe o es borrador |
| `GET /api/planning/{term}/plan` | Sí | El plan del estudiante; vacío si no tiene |
| `PUT /api/planning/{term}/plan` | Sí | Reemplaza el plan con `{"codes": [...]}`, en ese orden |
| `GET /api/planning/{term}/preferences` | Sí | Las preferencias del estudiante |
| `PUT /api/planning/{term}/preferences` | Sí | Reemplaza las preferencias con `{"dayParts", "preferredFreeDays", "reasons"}` |

La sesión es la misma de los destacados (`require_user`: cookie de la web o Bearer de la app, ver `13-10-2026-auth-token-app-movil.md`). El estudiante sale siempre de la sesión, nunca del cuerpo ni de la consulta. Los contratos completos están en `docs/backend.md`.

Los `PUT` validan y guardan en una sola transacción, con la fila del plan bloqueada: período abierto y dentro de su ventana (409), sin repetidos (400), códigos de la lista (422), sin dos códigos de la misma materia, como el viejo y el de la malla 2026 (422, desde el 4 de noviembre de 2026), máximo 20 créditos (422) y, en las preferencias, solo valores conocidos y sin combinar «Me da igual» o «Prefiero no decir» con otra opción (422).

### 2.3 Cargador de la lista

`backend/scripts/cargar_lista_planificacion.py` lee el JSON que exporta el Planificador UTB (`lista_materias_202710.json`):

- Revisa la lista antes de tocar la base: si una materia trae créditos inválidos, no carga nada.
- Crea el período, o le actualiza la etiqueta y la versión. Un período nuevo queda abierto y sin ventana.
- Crea o actualiza las materias, deja inactivas las que ya no vienen y reemplaza las equivalencias.
- Todo en una transacción. Se corre a mano una vez por período: no va en el cron.

### Implementación

- `backend/init.sql` (bases nuevas) y `backend/scripts/migrar_esquema.py` (bases existentes): las mismas tablas y vistas. La migración también pone al día una base que tenga la primera versión de estas tablas.
- `backend/app/routes/planning_routes.py` y `backend/app/db/repository.py`: rutas y consultas.
- `backend/scripts/backup.py`: las cinco tablas entran en los respaldos (`PRESERVED_APP_TABLES`).
- Pruebas: `tests/test_planificacion_esquema.py`, `tests/test_cargar_lista_planificacion.py`, `tests/test_planning_routes.py` y `tests/test_planificacion_preferencias.py`. Necesitan un PostgreSQL de prueba en `DH_TEST_DATABASE_URL`; sin la variable, se omiten.

## 3. Privacidad

- El plan y las preferencias solo los ve su dueño. Borrar la cuenta (`usuario`) borra sus planes.
- Las estadísticas salen solo de las vistas agregadas, que no muestran grupos de menos de 10 estudiantes. No hay ruta que las exponga.
- Pendiente (Producto y DTIC): aviso y consentimiento para usar las planificaciones en estadísticas (Ley 1581 de 2012).

## 4. Despliegue

### 4.1 Qué pasa al hacer merge a `master`

1. `deploy.yml` copia el proyecto a la VM y corre `docker compose down` y `docker compose up --build -d`. La web y la API quedan fuera de línea mientras se reconstruyen las imágenes: conviene hacerlo en un horario de poco uso.
2. Al levantar, `initial-data` corre `actualizar_datos.py`, que llama a `aplicar_migraciones()` y crea las tablas y vistas de la planificación. La migración es idempotente, solo agrega objetos y no toca los datos existentes. Se probó sobre una base con el esquema de `master` y datos, y sobre una base con la primera versión de estas tablas.
3. No hay variables de ambiente ni dependencias nuevas: el `.env` de la VM no cambia.
4. Ni la web ni la versión publicada de la app usan las rutas nuevas. La app solo las usa en su modo de prueba (`QA_PLANNING`), así que el despliegue no cambia nada para los estudiantes.

### 4.2 Paso manual: cargar la lista

Hasta cargar la lista, `GET /api/planning/current` responde 404 y la app no puede guardar planes. En la VM, con el JSON copiado a `~/lista_materias_202710.json`:

```bash
cd ~/app
docker compose run --rm \
  -v ~/lista_materias_202710.json:/app/lista_materias_202710.json \
  initial-data python scripts/cargar_lista_planificacion.py lista_materias_202710.json
```

Verificación: `GET https://horario.lab.utb.edu.co/api/planning/current` responde 200 con `"term": "202710"`. Volver a cargar la misma versión no cambia nada.

### 4.3 Ventana de edición

Un período nuevo queda abierto y sin fechas: se puede editar hasta que alguien lo cierre. Cuando se publique la oferta de ese período, la planificación se cierra (los `PUT` responden 409 y los planes se conservan):

```sql
UPDATE public.periodo_planificacion
SET estado = 'cerrado', updated_at = NOW()
WHERE periodo = '202710';
```

También se puede fijar `abre` y `cierra` para que se abra y se cierre solo.

### 4.4 Reversión

Revertir el merge en `master` vuelve a desplegar la versión anterior. Las tablas y vistas nuevas quedan en la base sin uso y no afectan al generador. Borrarlas elimina los planes guardados: solo con un respaldo previo y si se decide.

## 5. Pendiente

- Quién corre el cargador en la VM (sección 4.2).
- Cómo se detecta que se publicó la oferta, para cerrar la planificación (Registro Académico y DTIC).
- Aviso y consentimiento para las estadísticas (sección 3).
- Instancia propia de este backend para la app (deuda técnica #379 de `utb-mob-utbapp`).
