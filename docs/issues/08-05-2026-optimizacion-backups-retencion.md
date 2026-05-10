# Registro Técnico: Optimización de Backups y Retención de Datos

- Fecha: 2026-05-08
- Estado: Activo
- Tipo: Estabilidad, Persistencia y Rendimiento

## 1. Problema y Contexto

Se identificaron dos problemas críticos respecto al manejo de los datos y el almacenamiento:
1. **Pérdida de datos en despliegues:** El flujo de CI/CD en GitHub Actions detenía los contenedores usando `docker compose down -v`, lo cual destruía por completo los volúmenes, perdiendo a todos los usuarios previamente registrados.
2. **Backups pesados y efímeros:** La actualización de oferta académica que corre con alta frecuencia (ej. cada 6 a 10 minutos para garantizar frescura de datos) estaba atada a la creación de un snapshot general (`pg_dump`). Estos respaldos se acumulaban en un directorio interno del contenedor sin mapeo físico a la VM, lo que causaba que 1) se perdieran al reiniciar el contenedor y 2) llenaran la persistencia interna del contenedor inútilmente al sacar historial constante de tablas académicas de "usar y tirar".

## 2. Decisiones de Diseño e Implementación

Para garantizar estabilidad a largo plazo (incluso tras meses sin mantenimiento en la VM), se decidió desacoplar cronogramas y enfocar los resguardos:

1. **Corrección de Despliegue (CI/CD):**
   - Se removió la bandera destructiva `-v` del paso `docker compose down` en `.github/workflows/deploy.yml`.
   - Ahora, los despliegues actualizan la imagen y el contenedor sin tocar el disco del volumen `postgres_data`.

2. **Desacoplamiento del ETL y el Backup:**
   - La actualización de Banner (`insertar_en_db.py`) **ya no realiza snapshots** (al correr con esta alta frecuencia, generaba copias excesivas); solo se encarga de la transacción atómica de borrar oferta académica y re-insertar.
   - Se levantó un **nuevo cron job independiente** en `docker-compose.yml` (`0 */4 * * *`) que ejecuta `backup.py` cada 4 horas (6 veces al día).

3. **Snapshots Quirúrgicos:**
   - El backup mediante `pg_dump` ahora está configurado de manera explícita para recolectar **únicamente** las tablas persistentes (`PRESERVED_APP_TABLES`): `usuario`, `sesion_usuario` y `horario_destacado`. 
   - Se excluyen las tablas de clases, cursos, profesores y materias por ser reconstruibles en cualquier momento.

4. **Retención Inteligente (6 Meses) y Mapeo Físico:**
   - Se configuró la retención máxima a `1125 snapshots` en `backup.py` (lo que equivale a aproximadamente ~187 días ejecutándose 6 veces diarias). Una vez superado este límite, se limpia el backup más antiguo.
   - En el `docker-compose.yml`, se añadió el volumen persistente `./data/snapshots:/app/scripts/snapshots` en el `cron-updater`, garantizando que estos archivos ligeros sobrevivan a nivel de la Máquina Virtual y no mueran con el contenedor Docker.

## 3. Proyección de Almacenamiento y Crecimiento

Dado que la VM cuenta con aproximadamente 16 GB libres y el límite está sellado en 1125 archivos(`.sql` en texto plano), se han calculado los escenarios de uso:

*   **Escenario Básico (Solo Usuarios):**
    500 usuarios registrados ocupan unos ~75 KB por backup. 
    *Total proyectado: ~85 MB retenidos localmente.*
*   **Escenario Avanzado (Alta densidad de Horarios Destacados):**
    La base permite múltiples favoritos por usuario (`UNIQUE (usuario_id, term, signature)`). Con **1,000 usuarios almacenando 5 horarios cada uno** (5,000 horarios): 
    *Total proyectado: ~11.2 GB acumulados.*

**Estrategia de Mitigación Futura:**
En caso de presentarse el Escenario Avanzado y agotar el margen holgado de disco actual, la modificación técnica a aplicar NO requerirá sacrificar historial ni prohibir la creación de favoritos, constará únicamente de aplicar compresión `.gz` o `.zip` (ej. activando el flag `-Z 9` directamente en el `pg_dump`). El texto plano se comprime al 90%, reduciendo esos teóricos 11 GB a cerca de un **1 GB** neto en almacenamiento.
