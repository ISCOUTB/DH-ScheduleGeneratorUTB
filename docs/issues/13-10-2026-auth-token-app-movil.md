# Registro Técnico: Autenticación por token para la app móvil (UTB App)

- Fecha: 2026-10-13
- Estado: Solución temporal activa · solución definitiva **pendiente**
- Tipo: Seguridad / Integración
- Alcance: Backend (`auth/`, rutas de favoritos y cursos personalizados), Entra ID, UTB App

## 1. Contexto

La app móvil institucional (UTB App, Flutter) integra el generador de horarios
consumiendo esta API. Los endpoints públicos (`/api/subjects*`,
`/api/schedules/generate`) funcionan sin sesión, pero **horarios destacados**
(`/api/favorites*`) y **cursos personalizados** (`/api/custom-courses*`) exigían la
cookie `session_id` que crea el login web (`/api/auth/login` → `callback`).

La app ya inicia sesión con Microsoft por su cuenta (registro de aplicación propio
en Entra ID) y envía `Authorization: Bearer <token>`, pero el backend solo leía la
cookie: la misma persona recibía 401.

El token de la app es un **access token de Microsoft Graph** (scope `User.Read`):
su destinatario (`aud`) es Graph y su firma no se puede validar fuera de Graph.

## 2. Decisión (solución temporal)

Aceptar, además de la cookie, un `Authorization: Bearer` que se verifica
**preguntándole a Graph** quién es su dueño (`GET /v1.0/me`):

1. Si hay cookie de sesión válida, se usa (la web no cambia).
2. Si no, se lee el Bearer. Sin verificar, sus claims sirven solo para descartar
   rápido: vencido (`exp`) o de un tenant fuera de `AZURE_ALLOWED_TENANTS` → 401
   sin llamar a Graph.
3. Se llama a Graph con el token. Si responde 200, el token es válido; su `id` es el
   mismo `oid` que guarda el login web y debe coincidir con el `oid` del token.
4. Se obtiene/crea el usuario con `get_or_create_user(oid, upn, nombre)`: **es el
   mismo registro que el de la web**, así que los destacados se comparten.
5. El usuario resultante tiene la forma de una sesión web; las rutas no distinguen
   el origen.
6. Se guarda en memoria (hash SHA-256 del token, nunca el token) hasta su `exp`
   (máx. 1 h): una sola llamada a Graph por token.
7. Se registra el acceso en `sesion_usuario` con `tipo = 'app'` (una vez por token
   verificado).

Graph caído o con error ≠ 401/403 → **503** («No se pudo verificar la sesión»): el
token puede ser válido y el cliente no debe cerrar la sesión.

### Implementación

- `backend/app/auth/token_auth.py`: verificación y caché.
- `backend/app/auth/routes.py`: dependencia `require_user` (cookie o Bearer).
- `backend/app/routes/favorite_routes.py` y `custom_course_routes.py`: usan
  `Depends(require_user)` en lugar de leer la cookie.
- Configuración opcional: `GRAPH_ME_URL`, `GRAPH_TIMEOUT_SECONDS`.
- Pruebas: `tests/test_token_auth.py` (sin red ni base de datos).

## 3. Riesgo aceptado

Se acepta **cualquier** token de Graph del usuario, aunque lo haya emitido otra
aplicación del tenant. Si una aplicación ajena obtuviera el token de un
estudiante, podría leer y modificar sus destacados y cursos personalizados en su
nombre. Mitigaciones actuales: solo tenants permitidos, el `oid` del token debe ser
el que reporta Graph, y el token vence en ~1 h. El impacto se limita a datos del
propio generador (no hay datos académicos sensibles aquí).

Además: una llamada saliente a Graph por token nuevo, y dependencia de Graph para
autenticar a la app (si Graph no responde, la app recibe 503).

## 4. Solución definitiva (pendiente)

Que el generador **publique su propia API** en Entra ID y que la app pida un token
**solo para él**, validado localmente.

### 4.1 Entra ID (quien administre el registro de aplicación del generador)

1. Registro del generador → **Exponer una API**:
   - URI de la aplicación: `api://<client-id-del-generador>`.
   - Agregar el scope `access_as_user` («Acceder al generador de horarios en nombre
     del usuario»; consentimiento: administradores y usuarios).
2. En la misma sección, **Aplicaciones cliente autorizadas**: agregar el client id
   de UTB App con el scope `access_as_user` (sin pantalla de consentimiento extra).
   Alternativa: en el registro de UTB App, **Permisos de API** → el scope del
   generador + consentimiento de administrador.
3. En el manifiesto del generador, `accessTokenAcceptedVersion: 2` (tokens v2, con
   `iss` `https://login.microsoftonline.com/<tenant>/v2.0`).

### 4.2 Backend

Reemplazar la consulta a Graph por validación local del JWT (`python-jose` ya es
dependencia):

- Firma con las llaves del tenant (`https://login.microsoftonline.com/<tenant>/discovery/v2.0/keys`, en caché).
- `iss` del tenant permitido, `aud` = client id (o `api://…`) del generador,
  `scp` contiene `access_as_user`, `exp`/`nbf`.
- Mantener la misma forma de usuario y la dependencia `require_user`.
- Durante la transición, aceptar ambos (token propio y, con fecha de retiro, el de
  Graph); luego retirar `token_auth._graph_me`.

### 4.3 App (UTB App)

Un token sirve para un solo destinatario: la app conserva el de Graph (foto,
gateway) y pide un **segundo token** para el generador con su refresh token
(`scope=api://<client-id-del-generador>/access_as_user`), con una clave nueva en
su ambiente (p. ej. `SCHEDULE_GENERATOR_SCOPE`).

### 4.4 Criterio de cierre

- Un token de Graph emitido para otra aplicación recibe 401 en `/api/favorites`.
- La app opera con su token del generador; sin llamadas a Graph para autenticar.
