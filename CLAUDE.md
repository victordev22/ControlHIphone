# ControlH — Project Context

## What this is
**ControlH** is an Android app (Kotlin + Jetpack Compose) that monitors when company PCs are turned on or off, and sends push notifications via Novu/Firebase when a user's PC is still on past their scheduled `of_control` time.

## Tech stack
- **Language**: Kotlin — minSdk 25, targetSdk 35, JVM 11
- **UI**: Jetpack Compose + Material3 + Navigation Compose 2.9.2
- **Auth**: Keycloak via AppAuth 0.11.1 (OpenID Connect) + custom email/password fallback
- **Network**: Retrofit 2.11.0 + OkHttp 4.12.0 + Gson
- **Background**: WorkManager 2.9.0 (work-runtime-ktx)
- **Push**: Firebase BOM 33.1.0 (messaging + analytics) + Novu (self-hosted)
- **Storage**: EncryptedSharedPreferences (security-crypto)
- **Package**: `com.example.controlh`

## Backends
| Name | Base URL | Client |
|------|----------|--------|
| Auth | `https://auth.meta4bim.com/` | `RetrofitClient.instanceA` |
| Control | `https://control.meta4bim.com/` | `RetrofitClient.instance` |
| Novu | `http://4.245.229.134:3000/v1/` | `NovuManager` (own Retrofit, no JWT) |
| Keycloak | `https://keycloak.meta4bim.com/auth/realms/bim6d/protocol/openid-connect` | AppAuth |

## Key API endpoints
| Method | Path | Notes |
|--------|------|-------|
| POST | `/auth/signin` | Login email/password |
| GET | `/auth/me` | Current user — **does NOT return `of_control`** |
| GET | `/auth/admin/user/{email}` | Full user with `on_control`, `of_control` |
| GET | `/auth/admin/users` | All users (admin only) |
| GET | `/control/listhoras` | PC session records (Horas) |
| PUT | `/v1/subscribers/{id}/credentials` | Register FCM token in Novu |
| POST | `/v1/events/trigger` | Fire Novu notification (workflow: `horas-notification`) |

## Data models
```kotlin
// PC session record — hora_apagado == null means PC is still ON
Horas(id, user: String, hora_encendido: Date?, hora_apagado: Date?, minutosInactivo, listaApps)

// Full user profile — from /auth/admin/user/{email}
UserFull(id, nickname, email, password, on_control: String?, of_control: String?, roles, role)
// of_control example: "11:00:00"

// Auth response from /auth/me — of_control is always null here
UserMe(token, email, nickname, roles, of_control = null)

// In-memory session object (no of_control)
User(nickname, email, roles: List<Role>, role: String?)

Role(erole: String)  // "ROLE_ADMIN" | "ROLE_USER"

// Incidencia — GET /api/incidencias returns the full pc object, not just the id
Incidencia(id, pc: PcRef, gestor_incidencia: String, incidencia: String, fecha: Date?, estado: String?)
// PcRef embeds the full user — API returns: id, nickname, email, on_control, of_control, roles, etc.
PcRef(id, nickname: String?, email: String?, of_control: String?, on_control: String?)
// CreateIncidenciaRequest sends only PcRef(id) — the server resolves the full object
// Confirmed live: endpoint returns 1 incidencia (tested 2026-06-22 with valid JWT)
```

## Architecture (MVVM)
```
LoginActivity (Keycloak AppAuth — clientId: client-movil, realm: bim6d)
    └─> MainActivity (setupWorkManager → NotificationWorker immediate)
            └─> AppNavigation (NavHost, start: SplashScreen)
                   ├─ SplashScreen   — checks isAuthenticated
                   ├─ AuthScreen     — email/pwd login OR Keycloak button
                   ├─ HomeScreen     — AuthViewModel + HomeViewModel + ControlViewModel
                   ├─ ListScreen     — all Horas records
                   ├─ ListUser       — user management (admin only)
                   ├─ IncidenciaScreen (admin only)
                   └─ DetailScreen/{id}
```

## Key classes
| Class | Role |
|-------|------|
| `TokenManager` | EncryptedSharedPreferences: JWT, AuthState (Keycloak), `novu_email`, `of_control`, `nickname` |
| `RetrofitClient` | Two Retrofit instances with JWT Bearer interceptor |
| `NovuManager` | Own Retrofit, 30s timeout, 3 retries with 5s delay; saves email on bind success |
| `NotificationWorker` | Refreshes Keycloak token → fetches `of_control` → checks `getHoras()` → sends Novu → always reschedules |
| `AuthViewModel` | After login: calls `/auth/me` then `/auth/admin/user/{email}`, saves `of_control` + `nickname` to TokenManager |
| `MyFirebaseMessagingService` | `onNewToken` → re-binds FCM token to Novu automatically |

## Notification flow
1. **Login** → `AuthViewModel.fetchCurrentUser()` → `/auth/me` → `/auth/admin/user/{email}` → saves `of_control` + `nickname` to `TokenManager`
2. **App start** → `MainActivity.setupWorkManager()` → `NotificationWorker` runs immediately
3. **Worker step 1** → `refreshTokenIfNeeded()` (AppAuth refresh token from `TokenManager.getAuthState()`)
4. **Worker step 2** → calls `/auth/me`; if `of_control` missing → calls `/auth/admin/user/{email}` directly; saves to `TokenManager`
5. **Worker step 3** → if `LocalTime.now() >= of_control` → calls `getHoras()` → checks `Horas.user == nickname && hora_apagado == null`
6. **Worker step 4** → if PC on → `NovuManager.enviarNotificacion(email)` → Novu triggers FCM push to device
7. **Always** → `reprogramarSiguienteEjecucion(targetTime, isPcStillOn)` (15 min if PC on, else next day at `of_control`)

## Critical rules — read before editing
- `/auth/me` **never** returns `of_control` — always call `/auth/admin/user/{email}` to get it
- `Horas.user` matches `UserMe.nickname` (e.g. `"bim6d.21"`), NOT the email address
- `TokenManager.getAuthState()` holds the full Keycloak `AuthState` with refresh token (AppAuth)
- `NovuManager` has its own Retrofit instance — it does NOT use the JWT interceptor from `RetrofitClient`
- `NOVU_API_KEY` is in `local.properties` → `BuildConfig.NOVU_API_KEY`; Novu header format: `Authorization: ApiKey <key>`
- WorkManager unique work name is `"DailyCheck"` — `KEEP` on first enqueue, `REPLACE` on self-reschedule
- `reprogramarSiguienteEjecucion` must **always** be called — never inside a try/catch — or the worker cycle breaks

## Environment
- Google Services: `app/google-services.json`
- Keycloak redirect URI: `meta4bim://oauth`
- SSH endpoint: `http://4.245.225.143:8087/api/ssh/execute?command=`