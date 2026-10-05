# Codebase Structure

**Analysis Date:** 2026-10-06

## Directory Layout

```
Taipei-City-Dashboard/
├── Taipei-City-Dashboard-BE/                  # Go backend application
│   ├── main.go                                # Entry point
│   ├── cmd/
│   │   └── root.go                            # Cobra CLI setup
│   ├── app/
│   │   ├── app.go                             # StartApplication(), main bootstrap
│   │   ├── controllers/                       # HTTP handlers (user.go, component.go, etc.)
│   │   ├── models/                            # GORM models, database queries
│   │   ├── services/                          # Business logic
│   │   │   ├── ai/                            # AI integration (providers, tools)
│   │   │   │   ├── providers/                 # TWCC, OpenAI, Gemini implementations
│   │   │   │   ├── tools/                     # AI tools/plugins
│   │   │   └── isochrone/                     # Transit routing (RAPTOR, GTFS)
│   │   ├── routes/                            # Route configuration (router.go)
│   │   ├── middleware/                        # HTTP middleware (auth, rate limit)
│   │   ├── cache/                             # Redis cache layer
│   │   └── initial/                           # Startup tasks (cron, schema, data)
│   ├── global/                                # Global configuration (env vars)
│   ├── logs/                                  # Logging utilities
│   ├── go.mod, go.sum                         # Go dependencies
│   └── Dockerfile                             # Container image build
│
├── Taipei-City-Dashboard-FE/                  # Vue 3 frontend application
│   ├── index.html                             # HTML entry point
│   ├── vite.config.js                         # Vite build & dev server config
│   ├── package.json, package-lock.json        # Node dependencies
│   ├── src/
│   │   ├── main.js                            # Frontend bootstrap
│   │   ├── App.vue                            # Root component
│   │   ├── router/
│   │   │   └── index.js                       # Vue Router config, route guards
│   │   ├── store/                             # Pinia stores (global state)
│   │   │   ├── authStore.js                   # User, login, permissions
│   │   │   ├── contentStore.js                # Dashboard, component content
│   │   │   ├── mapStore.js                    # Map layers, zoom, bounds
│   │   │   ├── adminStore.js                  # Admin panel state
│   │   │   ├── chatStore.js                   # Chat messages, AI state
│   │   │   └── dialogStore.js                 # Modal visibility
│   │   ├── views/                             # Page-level components
│   │   │   ├── DashboardView.vue              # Main dashboard page
│   │   │   ├── MapView.vue                    # Map page
│   │   │   ├── ComponentView.vue              # Component browser
│   │   │   ├── ComponentInfoView.vue          # Component detail page
│   │   │   ├── EmbedView.vue                  # Embed/iframe view
│   │   │   ├── CallBack.vue                   # OAuth callback
│   │   │   └── admin/                         # Admin pages (user, dashboard, etc.)
│   │   ├── components/                        # Reusable UI components
│   │   │   ├── charts/                        # Chart components (not dashboardComponent)
│   │   │   ├── dialogs/                       # Modal/dialog components
│   │   │   ├── map/                           # Map utilities & overlays
│   │   │   ├── icons/                         # SVG icon components
│   │   │   └── utilities/                     # Helper components
│   │   ├── dashboardComponent/                # Dashboard-specific chart components
│   │   │   ├── components/                    # BarChart.vue, ColumnChart.vue, etc.
│   │   │   ├── assets/                        # Component-specific images
│   │   │   ├── styles/                        # Component-specific styles
│   │   │   └── utilities/                     # Component helpers
│   │   ├── composables/                       # Vue 3 composables (shared logic)
│   │   ├── directives/                        # Custom Vue directives
│   │   ├── assets/                            # Static assets
│   │   │   ├── configs/                       # Config files (e.g., API endpoints)
│   │   │   ├── images/                        # Logos, icons
│   │   │   ├── styles/                        # Global SCSS/CSS
│   │   │   └── utilityFunctions/              # Shared JS utilities
│   │   └── App.vue                            # Root layout
│   └── public/                                # Public static files (robots.txt, etc.)
│
├── Taipei-City-Dashboard-DE/                  # Data Engineering (Airflow DAGs)
│   ├── dags/                                  # Airflow DAG definitions
│   ├── db_migrations/                         # Database migration scripts
│   ├── config/                                # Airflow config
│   ├── cicd/                                  # CI/CD scripts
│   └── docker/                                # Docker for DE services
│
├── docker/                                    # Main Docker Compose files
│   ├── docker-compose.yaml                    # Main services (nginx, FE, BE)
│   ├── docker-compose-db.yaml                 # Database services (postgres, redis, qdrant)
│   ├── docker-compose-init.yaml               # One-time init services
│   ├── nginx/
│   │   ├── conf.d/                            # Nginx config (routing, SSL)
│   │   └── ssl/                               # SSL certificates
│   └── qdrant-upgrade/                        # Vector DB upgrade utility
│
├── db-sample-data/                            # Sample SQL data files
│   ├── dashboardmanager-demo.sql              # Manager DB seed
│   └── dashboard-demo.sql                     # Dashboard DB seed
│
├── helm-chart/                                # Kubernetes Helm deployment
│   ├── templates/                             # K8s resource templates
│   └── docker/                                # Custom container images
│
├── docs/                                      # Project documentation
│   ├── agent-workflow/                        # Agent workflow docs
│   └── superpowers/                           # Custom tooling docs
│
└── .github/                                   # CI/CD workflows
    └── workflows/                             # GitHub Actions YAML files
```

## Directory Purposes

**`Taipei-City-Dashboard-BE/`:**
- Purpose: REST API backend for all dashboard data, auth, and AI features
- Contains: Go source code, CLI, Docker setup
- Key files: `main.go` (entry), `app/app.go` (bootstrap), `app/routes/router.go` (endpoints)

**`Taipei-City-Dashboard-BE/app/controllers/`:**
- Purpose: HTTP request handlers, one file per domain
- Contains: Functions like `GetComponentByID()`, `CreateDashboard()`, etc.
- Pattern: Extract params → call service/model → return JSON

**`Taipei-City-Dashboard-BE/app/models/`:**
- Purpose: GORM schemas, database queries, data access
- Contains: Struct definitions, query methods, SQL helpers
- Pattern: One file per domain (user.go has User struct + methods)

**`Taipei-City-Dashboard-BE/app/services/`:**
- Purpose: Business logic, external integrations, data transformation
- Contains: `ai/` (LLM providers), `isochrone/` (transit routing)
- Pattern: Service methods take context, return (result, error)

**`Taipei-City-Dashboard-BE/app/middleware/`:**
- Purpose: Reusable HTTP middleware for all routes
- Contains: `auth.go` (JWT), `rateLimit.go`, `common.go` (headers), `sanitizeXForwardedFor.go`
- Applied to: All route groups via `routes.ConfigureRoutes()`

**`Taipei-City-Dashboard-FE/src/`:**
- Purpose: Vue 3 SPA frontend code
- Entry: `main.js` → `App.vue` → `router/`
- Vite dev server runs here; HMR enabled during development

**`Taipei-City-Dashboard-FE/src/router/`:**
- Purpose: Client-side routing, auth guards, state setup per route
- Key file: `index.js` — defines routes, beforeEach guards
- Routes: `/dashboard`, `/mapview`, `/component`, `/admin/*`, `/embed/:id/:city`

**`Taipei-City-Dashboard-FE/src/store/`:**
- Purpose: Pinia stores for global state (auth, dashboards, maps, chat)
- Pattern: Each store is a separate `.js` file; accessed via `useStore()`
- Persisted across route changes, but cleared on logout

**`Taipei-City-Dashboard-FE/src/dashboardComponent/components/`:**
- Purpose: Chart/visualization components (BarChart.vue, MapLegend.vue, etc.)
- Contains: ~20+ chart types using ApexCharts, Deck.gl, Mapbox
- Pattern: Accept `data` prop, emit events for interaction

**`Taipei-City-Dashboard-FE/src/views/`:**
- Purpose: Page-level components (one per major route)
- Contains: DashboardView.vue (main), MapView.vue, ComponentView.vue, admin/*
- Pattern: Layout + child components; uses stores and router

**`docker/`:**
- Purpose: Docker Compose orchestration for local dev and production
- docker-compose.yaml: nginx, dashboard-fe, dashboard-be, vector-db-upgrade
- docker-compose-db.yaml: postgres-data, postgres-manager, redis, qdrant, pgadmin
- Network: br_dashboard (bridged, requires manual `docker network create`)

**`helm-chart/`:**
- Purpose: Kubernetes deployment manifests (production)
- Contains: Deployment, Service, ConfigMap templates for each component
- Used by: K8s clusters or Helm package manager

## Key File Locations

**Entry Points:**
- Backend: `Taipei-City-Dashboard-BE/main.go` → `cmd/root.go` → `app/app.go:StartApplication()`
- Frontend: `Taipei-City-Dashboard-FE/index.html` → `src/main.js` → `src/App.vue`
- Cron: `Taipei-City-Dashboard-BE/app/initial/cron.go:InitCronJobs()`
- DB migrations: `Taipei-City-Dashboard-BE/cmd/root.go` (migrateDB, initDashboard commands)

**Configuration:**
- Backend env: Loaded at `Taipei-City-Dashboard-BE/global/global.go` from OS environment
- Frontend env: Set via docker-compose.yaml `environment:` → vite.config.js proxy + build
- Docker: `docker/docker-compose.yaml`, `docker/docker-compose-db.yaml`
- Nginx: `docker/nginx/conf.d/` (routing, SSL)

**Core Logic:**
- Routes: `Taipei-City-Dashboard-BE/app/routes/router.go`
- Middleware: `Taipei-City-Dashboard-BE/app/middleware/auth.go` (JWT), `rateLimit.go`
- AI providers: `Taipei-City-Dashboard-BE/app/services/ai/providers/{twcc,openai,gemini}/`
- Transit routing: `Taipei-City-Dashboard-BE/app/services/isochrone/transit/` (RAPTOR)
- Frontend router: `Taipei-City-Dashboard-FE/src/router/index.js`
- Auth store: `Taipei-City-Dashboard-FE/src/store/authStore.js`

**Testing:**
- No dedicated test directory visible; tests appear to be minimal or in-file comments

**Database Schemas:**
- Manager DB (users, config): Schema defined in `Taipei-City-Dashboard-BE/app/models/*.go`
- Dashboard DB (data): Schema defined in same location
- Seed data: `db-sample-data/dashboardmanager-demo.sql`, `db-sample-data/dashboard-demo.sql`

## Naming Conventions

**Files:**
- Go: `camelCase.go` (e.g., `componentData.go`, `chatlog.go`)
- Vue: `PascalCase.vue` (e.g., `DashboardView.vue`, `ComponentTag.vue`)
- JS: `camelCase.js` (e.g., `index.js`, `authStore.js`)
- Styles: `camelCase.scss` (e.g., `global.scss`)

**Go Functions:**
- Public (exported): `PascalCase` (e.g., `GetComponentByID`, `StartApplication`)
- Private: `camelCase` (e.g., `parseComponent`, `connectToDatabase`)
- Middleware: `PascalCase` (e.g., `ValidateJWT`, `IsLoggedIn`)
- Controllers: Action verb + resource (e.g., `GetUserInfo`, `CreateDashboard`, `UpdateComponent`)

**Vue Components:**
- Page components: `*View.vue` or `*Page.vue` (e.g., `DashboardView.vue`)
- Reusable components: `PascalCase.vue` (e.g., `BarChart.vue`, `ComponentTag.vue`)
- Dashboard charts: Located in `dashboardComponent/components/`, inherit naming

**Database Models (Go structs):**
- Table name: snake_case (e.g., `users`, `components`, `dashboards`)
- Struct name: PascalCase (e.g., `User`, `Component`, `Dashboard`)
- Field name: PascalCase (e.g., `UserID`, `CreatedAt`, `ChartData`)

**API Endpoints:**
- Versioned prefix: `/api/v1/`
- Resource plural: `/component`, `/dashboard`, `/user` (not `/components`)
- Hierarchy: `/resource/:id/subresource` (e.g., `/user/:id/viewpoint`)
- Action verbs (non-RESTful): `/component/:id/chart`, `/component/ai-summary/trigger`

**Environment Variables:**
- UPPER_SNAKE_CASE (e.g., `DB_DASHBOARD_HOST`, `JWT_SECRET`, `REDIS_PORT`)
- Prefix by service: `DB_*`, `REDIS_*`, `TWCC_*`, `OPENAI_*`, `GEMINI_*`
- Load location: `global/global.go:getEnv()`, `getIntEnv()`

**Pinia Stores:**
- File: `camelCase.js` (e.g., `authStore.js`, `contentStore.js`)
- Function: `use{StoreName}()` (e.g., `useAuthStore()`, `useContentStore()`)
- State properties: `camelCase` (e.g., `user`, `isAdmin`, `currentDashboard`)

## Where to Add New Code

**New Feature (Domain):**
- Primary code: Create `app/controllers/{feature}.go`, `app/models/{feature}.go`, `app/services/{feature}.go`
- Routes: Add `configure{Feature}Routes()` function in `app/routes/router.go`, call from `ConfigureRoutes()`
- Frontend: Create `src/views/{Feature}View.vue`, add route to `src/router/index.js`
- Store: If state needed, add `src/store/{feature}Store.js`

**New Chart Type:**
- Implementation: Create `Taipei-City-Dashboard-FE/src/dashboardComponent/components/{ChartType}Chart.vue`
- Model support: Add chart data type handling in `app/models/componentData.go:GetComponentChartData()`
- Controller: Map chart type in `app/controllers/componentData.go:GetComponentChartData()` switch statement

**New AI Provider:**
- Implementation: Create `Taipei-City-Dashboard-BE/app/services/ai/providers/{provider}/service.go`
- Interface: Implement the provider interface (e.g., `Chat()` method)
- Controller: Add new POST handler in `app/controllers/ai.go`
- Route: Add to `configureAIRoutes()` in `app/routes/router.go`

**New Database Table:**
- Schema: Add Go struct to `app/models/{domain}.go` with GORM tags
- Queries: Add methods to same file (e.g., `CreateRecord()`, `GetByID()`)
- Migration: Run `go run main.go migrateDB` (uses GORM AutoMigrate)
- Controller: Create `app/controllers/{domain}.go` if new domain

**Utilities:**
- Shared Go helpers: `Taipei-City-Dashboard-BE/app/util/`
- Shared Vue helpers: `Taipei-City-Dashboard-FE/src/assets/utilityFunctions/`
- Composables (Vue 3): `Taipei-City-Dashboard-FE/src/composables/`

## Special Directories

**`docker/`:**
- Purpose: Container orchestration for development and production
- Generated: No (committed to repo)
- Committed: Yes (included in git)
- Modify: `docker-compose.yaml` for service topology, `nginx/conf.d/` for routing config

**`db-sample-data/`:**
- Purpose: SQL seed files for initial data population
- Generated: No (manually created and maintained)
- Committed: Yes
- Modify: Edit SQL directly; re-run `initDashboard` command to apply

**`logs/`:**
- Purpose: Runtime logs (stderr output)
- Generated: Yes (created at runtime)
- Committed: No (gitignored)
- Access: `docker logs <container-name>` or stdout tail

**`.planning/codebase/`:**
- Purpose: Analysis and architecture documentation
- Generated: Yes (written by gsd-map-codebase)
- Committed: No (gitignored, local ref only)
- Modify: Re-run mapping tool after structural changes

**`helm-chart/`:**
- Purpose: Kubernetes production deployment
- Generated: No (committed)
- Committed: Yes
- Modify: Edit templates when changing K8s resource requirements

---

*Structure analysis: 2026-10-06*
