# Registro Técnico: Persistencia vs Actualización ETL

- Fecha: 2026-03-29
- Estado: Activo
- Tipo: Riesgo de mantenibilidad y persistencia

## 1. Problema

El proceso ETL académico limpia tablas de oferta en cada actualización para recargar datos desde Banner.

Riesgo histórico:
- Cuando no existe una política explícita de separación de datos, se puede borrar información funcional de la aplicación (usuarios, favoritos, preferencias) al hacer refresh de oferta académica.

## 2. Hallazgos

1. El sistema ya separa en la práctica tablas académicas y tabla de usuarios.
2. La tabla `usuario` existe en schema.
3. El flujo de autenticación usaba sesiones en memoria, y no garantizaba persistencia consistente en DB por login.

## 3. Decisión de diseño

Se adopta política explícita:

1. El ETL solo limpia tablas académicas de oferta:
- `Clase`
- `Curso`
- `Profesor`
- `Materia`

2. Tablas funcionales de aplicación se preservan:
- `usuario`
- `horario_destacado` (cuando se implemente)

3. El login debe sincronizar usuario en DB (`get_or_create_user`) para asegurar persistencia.

## 4. Implementación aplicada

1. Se reforzó auth para crear/obtener usuario en DB durante callback OAuth.
2. Se añadió `dbUserId` en `/api/auth/me` para trazabilidad funcional.
3. Se hizo explícita la política de limpieza académica en scripts de backup/ETL.
4. Se cambió la actualización ETL a modo atómico (una sola transacción):
	- Limpieza académica + inserción ocurren en la misma transacción.
	- Si falla cualquier paso, se ejecuta `rollback` y la oferta previa permanece intacta.

## 5. Implicaciones operativas

1. Las actualizaciones de oferta académica no deben afectar identidad de usuario.
2. Features de persistencia por usuario (ej. horarios destacados) quedan desacopladas del ciclo ETL.
3. El uso de sesiones en memoria sigue siendo limitación para escalado horizontal; se mantiene fuera de alcance inmediato.
4. Un fallo durante ETL ya no deja la aplicación sin registros académicos por borrado parcial.

## 6. Próximos pasos recomendados

1. Implementar migraciones versionadas para cambios de esquema (no depender solo de `init.sql`).
2. Implementar tabla `horario_destacado` con `UNIQUE (usuario_id, term, signature)`.
3. Añadir pruebas automáticas para validar que ETL no toca tablas funcionales.

## 7. Evidencia de verificación operativa

Comprobaciones ejecutadas en entorno Docker activo:

1. Existencia de tabla `usuario`:
- Resultado: existe (`to_regclass = usuario`).

2. Verificación create-or-get en repositorio:
- Se ejecutó `get_or_create_user` dos veces con el mismo `entra_id`.
- Resultado: ambos llamados retornaron el mismo `id` (`same_user=True`).
- Se eliminó el registro de prueba al final (`cleanup=ok`).

3. Estado final tras limpieza de prueba:
- Conteo final en `usuario`: `0` (sin residuos de test).

4. Demostración de rollback sobre datos académicos:
- Se ejecutó en una transacción: `DELETE clase -> curso -> profesor -> materia`.
- Resultado dentro de transacción: `materia = 0`.
- Tras `ROLLBACK`: el conteo volvió al valor original (`materia` recuperado).
