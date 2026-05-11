# Registro Técnico: Registro de Inicios de Sesión por Usuario

- Fecha: 2026-05-10
- Estado: Activo
- Tipo: Observabilidad y Auditoría

## 1. Contexto

La tabla `usuario` solo almacenaba `created_at` (fecha de primer registro). No existía forma de saber cuántas veces un usuario accedía a la aplicación, ni cuándo fue su último inicio de sesión.

Para métricas de uso, auditoría de acceso y análisis de retención, se necesita registrar cada inicio de sesión individual.

## 2. Decisión de Diseño

Se adoptó un enfoque de tabla independiente (`sesion_usuario`) en lugar de campos adicionales en `usuario`, para:

1. Mantener el historial completo de cada inicio de sesión (no solo el último).
2. Capturar contexto adicional (IP, navegador) sin contaminar la tabla de identidad.
3. Permitir consultas analíticas sobre patrones de uso a lo largo del tiempo.

## 3. Implementación

### 3.1 Modelo de datos

Nueva tabla `sesion_usuario`:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | SERIAL | PK autoincremental |
| `usuario_id` | INTEGER NOT NULL | FK a `usuario.id` |
| `login_at` | TIMESTAMP | Fecha/hora del evento (default NOW()) |
| `ip_address` | VARCHAR(45) | IP real del cliente (vía X-Forwarded-For) |
| `user_agent` | TEXT | User-agent del navegador |
| `tipo` | VARCHAR(10) | `login` (OAuth) o `visita` (sesión existente) |

Índices:
- `idx_sesion_usuario_id` sobre `usuario_id`
- `idx_sesion_login_at` sobre `login_at`

### 3.2 Flujo de registro

El registro ocurre en dos puntos de `auth/routes.py`:

**Login (tipo=`login`):** En el callback de autenticación OAuth:
1. El usuario completa autenticación con Microsoft Entra ID.
2. Se persiste o recupera el usuario en BD (`get_or_create_user`).
3. Se crea la sesión en memoria.
4. Se registra el login con tipo `login`.

**Visita (tipo=`visita`):** En el endpoint `/api/auth/me`:
1. El usuario abre la app con sesión existente.
2. El frontend llama a `/api/auth/me` para verificar la cookie.
3. Si la sesión es válida, se registra una visita con tipo `visita`.
4. Throttle: máximo 1 visita cada 30 minutos por sesión para evitar duplicados por recargas.

**Resolución de IP real:**
- Se lee el header `X-Forwarded-For` (ya configurado en Nginx) para obtener la IP real del cliente.
- Si no está presente (ej. desarrollo local sin Nginx), se usa `request.client.host` como fallback.

### 3.3 Archivos modificados

- `backend/init.sql` — Schema de la nueva tabla.
- `backend/app/db/repository.py` — Función `register_login()`.
- `backend/app/auth/routes.py` — Llamada a `register_login` en callback OAuth. Se agregó `Request` a los imports y como parámetro del endpoint para acceder a IP y headers.
- `backend/scripts/backup.py` — `sesion_usuario` agregada a `PRESERVED_APP_TABLES`.
- `docs/modelo_datos.md` — Diagramas ER y descripción de la entidad actualizados.

## 4. Consultas útiles

```sql
-- Logins OAuth por usuario, últimos 30 días
SELECT u.email, u.nombre, COUNT(*) as logins
FROM sesion_usuario s
JOIN usuario u ON s.usuario_id = u.id
WHERE s.login_at > NOW() - INTERVAL '30 days' AND s.tipo = 'login'
GROUP BY u.email, u.nombre
ORDER BY logins DESC;

-- Visitas totales por usuario (entradas a la app)
SELECT u.email, u.nombre, COUNT(*) as visitas
FROM sesion_usuario s
JOIN usuario u ON s.usuario_id = u.id
WHERE s.login_at > NOW() - INTERVAL '30 days' AND s.tipo = 'visita'
GROUP BY u.email, u.nombre
ORDER BY visitas DESC;

-- Última actividad de cada usuario
SELECT u.email, u.nombre, MAX(s.login_at) as ultima_actividad
FROM usuario u
LEFT JOIN sesion_usuario s ON u.id = s.usuario_id
GROUP BY u.email, u.nombre;

-- Actividad diaria (logins + visitas)
SELECT DATE(login_at) as fecha, tipo, COUNT(*) as eventos
FROM sesion_usuario
GROUP BY DATE(login_at), tipo
ORDER BY fecha DESC;

-- Usuarios activos por semana
SELECT DATE_TRUNC('week', login_at) as semana, COUNT(DISTINCT usuario_id) as usuarios_activos
FROM sesion_usuario
GROUP BY semana
ORDER BY semana DESC;
```

## 5. Impacto en backups y almacenamiento

- La tabla está incluida en `PRESERVED_APP_TABLES`, por lo que se respalda junto con `usuario` y `horario_destacado` cada 4 horas.
- El crecimiento esperado es lineal con la cantidad de logins. Con 500 usuarios activos haciendo ~1 login/día, son ~15,000 registros/mes (~1.5 MB/mes en texto plano).
- La política de retención de snapshots existente (1125 archivos, ~6 meses) cubre este caso sin ajustes.

## 6. Consideraciones futuras

1. Si el volumen crece significativamente, considerar una política de retención sobre la propia tabla (ej. borrar registros de más de 12 meses).
2. Se podría complementar con Firebase Analytics para dashboards visuales de retención de usuarios, dado que Firebase ya está integrado en el frontend.
3. Si se necesita auditoría más detallada (ej. acciones del usuario dentro de la app), se puede extender esta tabla o crear una tabla de eventos separada.
