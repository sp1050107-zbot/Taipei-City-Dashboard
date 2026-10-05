<!-- refreshed: 2026-10-06 -->
# Architecture

**Analysis Date:** 2026-10-06

## System Overview

Taipei City Dashboard is a full-stack web application for visualizing city data with real-time charts, maps, and AI-powered insights. It uses a three-tier architecture with a Vue 3 frontend, Go backend, and multi-database system.

```text
┌─────────────────────────────────────────────────────────────────────┐
│                    Frontend (Vue 3 + Vite)                          │
│         `Taipei-City-Dashboard-FE/src/`                             │
├────────────────┬──────────────────────┬──────────────────────────┤
│  Router        │  Components          │  Stores (Pinia)          │
│ (vue-router)   │  (Charts, Maps)      │ (auth, content, map)     │
├────────────────┴──────────────────────┴──────────────────────────┤
│                     Vite Dev Server / Proxy                        │
│        /api/dev → http://dashboard-be:8080/api/v1 (rewrite)       │
└─────────────────────────────────────────────────────────────────────┘
                                 ↓ HTTP
┌─────────────────────────────────────────────────────────────────────┐
│                    Backend API Server (Gin)                         │
│         `Taipei-City-Dashboard-BE/app/`                             │
├────────────────┬──────────────────────┬──────────────────────────┤
│  Routes        │  Middleware          │  Controllers             │
│ (route groups) │ (JWT, rate limit)    │ (HTTP handlers)          │
├────────────────┴──────────────────────┴──────────────────────────┤
│                  Services Layer (Business Logic)                   │
│     - AI providers (TWCC, OpenAI, Gemini)                         │
│     - Transit/Isochrone (RAPTOR, GTFS)                            │
└─────────────────────────────────────────────────────────────────────┘
                 ↓ GORM / Redis / HTTP
┌──────────────┬──────────────┬───────────┬──────────────────────┐
│  Models      │  Cache       │  Vector   │  External APIs       │
│  (Data)      │  (Redis)     │  DB       │  (OpenAI, Google)    │
│              │              │ (Qdrant)  │                      │
├──────────────┼──────────────┼───────────┼──────────────────────┤
│ DBManager    │ Session      │ Query     │ TWCC LLM            │
│ (users,      │ storage      │ embeddings│ OpenAI (GPT)        │
│  config)     │ Chat cache   │ for AI    │ Google Gemini       │
│              │              │ search    │                     │
│ DBDashboard  │ Chart cache  │           │ Airflow API         │
│ (data,       │ Component    │           │ (DAG triggers)      │
│  charts)     │ data         │           │                     │
└──────────────┴──────────────┴───────────┴──────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Router | Route configuration, versioning, middleware chaining | `app/routes/router.go` |
| Controllers | HTTP request handling, parameter parsing, error responses | `app/controllers/*.go` |
| Services | Business logic, external API calls, data transformation | `app/services/ai/*`, `app/services/isochrone/*` |
| Models | Database access, GORM queries, schema definitions | `app/models/*.go` |
| Middleware | JWT validation, rate limiting, header sanitization | `app/middleware/*.go` |
| Cache | Redis connection, session/data caching | `app/cache/` |
| Initial | Database schema setup, cron job scheduling | `app/initial/` |
| Global | Configuration from environment variables | `global/global.go` |
| Frontend Router | Client-side routing, auth guards | `Taipei-City-Dashboard-FE/src/router/index.js` |
| Pinia Stores | State management (auth, content, maps) | `Taipei-City-Dashboard-FE/src/store/` |
| Components | Reusable Vue components for charts/maps | `Taipei-City-Dashboard-FE/src/dashboardComponent/components/` |

## Pattern Overview

**Overall:** Controller → Service → Model (classic three-tier MVC), with middleware pipeline for cross-cutting concerns. Frontend uses Pinia for state management and route-based lazy loading for components.

**Key Characteristics:**
- **Separation of concerns** — Controllers handle HTTP, services handle logic, models handle data
- **Middleware chain** — Each route group can compose middlewares (auth, rate limiting)
- **Database duality** — DBManager for user/config (postgis), DBDashboard for time-series data (postgis)
- **Async initialization** — Transit service and cron jobs run independently to avoid blocking
- **Vector search** — Qdrant stores component metadata embeddings for semantic search
- **Multi-provider AI** — Pluggable AI providers (TWCC, OpenAI, Gemini) for chat endpoints

## Layers

**Frontend Layer (Vue 3):**
- Purpose: User interface for dashboards, components, maps, and admin panel
- Location: `Taipei-City-Dashboard-FE/src/`
- Contains: Views (Dashboard, Map, Component), Components (Charts, Maps), Stores, Router
- Depends on: Vite dev proxy (backend), MapBox GL, Deck.gl
- Used by: Web browsers

**HTTP Handler Layer (Controllers):**
- Purpose: Parse requests, invoke services, format JSON responses
- Location: `app/controllers/`
- Contains: One file per domain (user.go, component.go, dashboard.go, etc.)
- Depends on: Services, Models, Middleware context
- Used by: Router (routes.ConfigureRoutes())

**Business Logic Layer (Services):**
- Purpose: Implement feature logic, call external APIs, transform data
- Location: `app/services/`
- Contains: `ai/` (LLM providers), `isochrone/` (transit routing)
- Depends on: Models, External APIs (OpenAI, TWCC, Gemini, Airflow)
- Used by: Controllers

**Data Access Layer (Models):**
- Purpose: GORM queries, schema definition, database operations
- Location: `app/models/`
- Contains: One file per domain, schema structs, SQL queries
- Depends on: GORM, PostgreSQL, Redis
- Used by: Controllers, Services

**Middleware Layer:**
- Purpose: Cross-cutting concerns (auth, rate limiting, header safety)
- Location: `app/middleware/`
- Provides: ValidateJWT, IsLoggedIn, IsSysAdm, LimitAPIRequests, LimitTotalRequests
- Applies to: All route groups

**Cache Layer:**
- Purpose: Redis connection pool, cache operations
- Location: `app/cache/`
- Provides: Redis client, key-value operations
- Used by: Models (component data), Controllers (session cache)

## Data Flow

### Primary Request Path: Dashboard Component Data

1. **Frontend initiation** (`src/router/index.js:164-184`) — Route guard loads component data
2. **API call** (Axios) — `GET /api/v1/component/:id/chart?city=taipei&time_from=...&time_to=...`
3. **Middleware** (`middleware/auth.go`, `middleware/rateLimit.go`) — Validate JWT, check rate limits
4. **Controller** (`app/controllers/componentData.go:20-85`) — Parse params, validate city/dates
5. **Model query** (`app/models/componentData.go`) — Fetch chart query from DBManager, execute on DBDashboard
6. **Chart type branching** — Call appropriate data formatter (two_d, three_d, time_series, map_legend)
7. **Response** — JSON with status, data, categories

### Secondary Path: AI Chat

1. **Frontend** (`src/store/chatStore.js`) — Build prompt, select provider
2. **API call** — `POST /api/v1/ai/chat/{twai|openai|gemini}` with message, context
3. **Middleware** — JWT + rate limit
4. **Controller** (`app/controllers/ai.go`) — Route to appropriate service
5. **Service** (`app/services/ai/providers/{twcc|openai|gemini}`) — Call external LLM with retry logic
6. **Cache** (`cache.Redis`) — Store chat session + message history
7. **Response** — Streamed or batched LLM response

### Tertiary Path: Component Vector Search

1. **Frontend** (`src/views/ComponentView.vue`) — User searches components by text query
2. **API call** — `POST /api/v1/vector/component` with query string
3. **Controller** (`app/controllers/qdrant.go`) — Embed query using ONNX LM
4. **Service** — Call Qdrant HTTP API with embedding vector
5. **Qdrant response** — Return top-K matching components by semantic similarity
6. **Model** — Load full component details from DBManager
7. **Response** — Ranked list of components

### Cron Path: Chat Log Cleanup

1. **Startup** (`app/initial/cron.go:26-85`) — Register daily cleanup job at app start
2. **Scheduler** — `robfig/cron` triggers at @daily (midnight)
3. **Lock acquisition** (`cache.Redis.SetNX()`) — Distributed lock for multi-instance safety
4. **Model delete** (`models.DeleteOldChatLogs()`) — Remove chat logs older than 6 months
5. **Lock release** — Lua script ensures only job owner releases lock

**State Management (Frontend):**
- **authStore** — user info, token, admin flag, current path
- **contentStore** — current dashboard, components, edit state
- **mapStore** — map layers, zoom, bounds, markers
- **adminStore** — admin form state, filters
- **chatStore** — chat messages, session, provider choice
- **dialogStore** — modal visibility flags

## Key Abstractions

**Route Groups:**
- Purpose: Organize endpoints by domain, apply middlewares in sequence
- Examples: `configureAuthRoutes()`, `configureDashboardRoutes()`, `configureComponentRoutes()`
- Pattern: `RouterGroup.Group("/path").Use(middleware...).POST(..., controller)`

**Models (GORM):**
- Purpose: Represent database table and query methods
- Examples: `Component`, `Dashboard`, `User`, `ChatLog`
- Pattern: Struct tags define columns; methods like `GetComponentByID()`, `GetComponentChartDataQuery()`

**Services:**
- Purpose: Encapsulate feature-specific logic separate from HTTP handling
- Examples: `TWCC.Chat()`, `OpenAI.Chat()`, `transit.InitService()`
- Pattern: Accept context/params, return (result, error)

**Controllers:**
- Purpose: Thin adapter layer — extract Gin context, call service, return JSON
- Pattern: `func HandlerName(c *gin.Context) { ... c.JSON(...) }`

**Pinia Stores (Frontend):**
- Purpose: Centralized reactive state, persisted across route changes
- Pattern: Definestore with state, getters, actions
- Example: `useAuthStore()` provides user, token, login/logout methods

## Entry Points

**Backend:**
- Location: `main.go` → `cmd/root.go` → `app/app.go:StartApplication()`
- Triggers: Server startup (go run main.go)
- Responsibilities: Initialize DB, Redis, cron, LM, Gin, routes; start endless server

**Frontend:**
- Location: `src/main.js` → `src/App.vue` → `src/router/index.js`
- Triggers: Browser load of `/` (redirects to `/dashboard`)
- Responsibilities: Mount Vue app, configure Pinia stores, set up route guards

**Cron Jobs:**
- Location: `app/initial/cron.go`
- Triggers: App startup + scheduled times (@daily)
- Responsibilities: Clean old chat logs with distributed locking

**Database Migrations:**
- Location: `cmd/root.go` (migrateDB, initDashboard commands)
- Triggers: Manual CLI invocation (go run main.go migrateDB)
- Responsibilities: Create schema, insert seed data

## Architectural Constraints

- **Threading:** Backend is single-threaded event loop (Gin + Redis + goroutines for async tasks). Frontend is single-threaded JS event loop.
- **Database split:** Two databases to separate write-heavy data (DBDashboard) from config (DBManager); both require separate connections.
- **API versioning:** `/api/v1/` prefix allows future breaking changes; set via `global.VERSION`.
- **Rate limiting:** Applied per route group; stored in Redis, using window-based counters.
- **JWT expiration:** Tokens expire based on `TokenExpirationDuration` (6 hours typical); refresh not implemented (re-login required).
- **Vector DB:** Qdrant is external service; embeddings computed once at init using ONNX E5 model.
- **Cascading middleware:** Route groups inherit parent middlewares; order matters (e.g., auth before admin check).
- **CORS disabled:** Currently commented out in `app.go`; assumes nginx handles CORS or frontend is same-origin.

## Anti-Patterns

### Hard-Coded External API Credentials in Code

**What happens:** API keys (OPENAI_API_KEY, etc.) loaded from env vars at `global.go:init()` but used directly in service calls without abstraction.
**Why it's wrong:** Credentials can leak in logs, error responses, or if env var is logged during debugging.
**Do this instead:** Wrap all external API calls in a secrets rotation layer or use a credential manager; never log keys. See `app/services/ai/providers/*.go` — load from env once at start, store in a typed config struct, never pass key directly to HTTP client.

### Controller Calling Model Directly Without Service Abstraction

**What happens:** Some controllers call `models.Get*()` directly; others call service methods. Inconsistent.
**Why it's wrong:** Hard to test controllers in isolation; business logic can leak into HTTP layer.
**Do this instead:** All database access should go through services. Controllers call services only. Example: `app/controllers/componentData.go` should call a `ComponentService.GetChartData()` rather than `models.GetComponentChartDataQuery()` directly.

### Synchronous Cron Job Holding Lock While Executing

**What happens:** Chatlog cleanup job acquires Redis lock, performs 10-minute DELETE, holds lock entire time.
**Why it's wrong:** Other instances cannot run even trivial jobs; lock timeout (1 hour) is too long for failure recovery.
**Do this instead:** Use sub-locks for each batch. Lock → process batch → release → relock next batch. If main lock expires, job dies gracefully; next instance picks up incomplete work.

### No Context Timeout on Database Queries

**What happens:** `models.DeleteOldChatLogs()` called with `ctx`, but GORM query doesn't use it; slow query blocks entire job.
**Why it's wrong:** One slow query stalls cleanup; lock held indefinitely.
**Do this instead:** Pass context to GORM: `db.WithContext(ctx).Where(...).Delete(...)` at `app/models/chatlog.go`.

## Error Handling

**Strategy:** Fail-safe with detailed error logging.

**Patterns:**
- Database errors → `http.StatusInternalServerError` with generic "error" message (never expose SQL errors to client)
- Invalid input → `http.StatusBadRequest` with validation detail (e.g., "Invalid City Name")
- Unauthorized (no token or invalid) → `http.StatusUnauthorized`
- Forbidden (token valid but insufficient permissions) → `http.StatusForbidden`
- Not found → `http.StatusNotFound`
- Rate limited → `http.StatusTooManyRequests`
- External API timeout → Retry logic in service; if all retries fail, `http.StatusServiceUnavailable`

**Logging:** All errors logged at ERROR or WARN level with context (user ID, component ID, etc.) via `logs.*()` package.

## Cross-Cutting Concerns

**Logging:** Package `logs/` provides `Info()`, `Warn()`, `Error()`, `FInfo()`, `FWarn()`, `FError()` (formatted). Used throughout for startup, queries, errors. No structured logging; plain text to stdout.

**Validation:** Input validation happens at controller layer:
- Route params parsed with `strconv.Atoi()`, checked for errors
- Query params validated with switch statements or helper functions
- Request body parsed and validated via `c.ShouldBindJSON()`

**Authentication:** JWT-based:
- Token stored in Authorization header as "Bearer <token>"
- Validated in `middleware.ValidateJWT()` on every request
- Claims extracted and set in Gin context for downstream use
- Token expiration checked; expired tokens result in 401

**Permission Model:** Role-based access control (RBAC):
- User has Permissions (GroupID + RoleID pairs)
- RoleID 3 = Viewer (read-only), higher numbers = more power
- Admin check via `middleware.IsSysAdm()` for sensitive operations
- Component/Dashboard access scoped by group membership

---

*Architecture analysis: 2026-10-06*
