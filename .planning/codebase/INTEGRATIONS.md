# External Integrations

**Analysis Date:** 2026-10-06

## APIs & External Services

**AI/LLM Services:**
- **TWCC AI Foundry (AFS)** - Taiwan AI computing platform
  - SDK/Client: Direct HTTP API calls via `net/http`
  - Auth: `TWCC_API_KEY` (env var in `global/global.go`)
  - Models: `llama3.3-ffm-70b-32k-chat` (default, configurable via `TWCC_MODEL`)
  - Base URL: `https://api-ams.twcc.ai/api` (configured in `TWCC.ApiUrl`)
  - Used by: Backend LLM query processing (`app/models/qdrant.go`)

- **OpenAI API** - GPT models for natural language processing
  - SDK/Client: Direct HTTP API calls via `tmc/langchaingo` v0.1.14
  - Auth: `OPENAI_API_KEY` (env var)
  - Models: `gpt-4o` (default, configurable via `OPENAI_MODEL`)
  - Base URL: `https://api.openai.com/v1`
  - Used by: LLM-powered backend features

- **Google Gemini API** - Google's generative AI platform
  - SDK/Client: `google.golang.org/generativeai` and `cloud.google.com/go/ai` v0.7.0
  - Auth: `GEMINI_API_KEY` (env var)
  - Models: `gemini-2.5-pro` (default, configurable via `GEMINI_MODEL`)
  - Base URL: `https://generativelanguage.googleapis.com`
  - Used by: Alternative LLM backend processing

**Mapping & Geospatial:**
- **Mapbox GL** - Vector tile mapping and visualization
  - SDK/Client: `mapbox-gl` v3.1.0 (npm package)
  - Auth: `VITE_MAPBOXTOKEN` (frontend env var)
  - Tile Source: `VITE_MAPBOXTILE` (configurable)
  - Used by: Interactive mapping in frontend (`Taipei-City-Dashboard-FE/src/views/MapView.vue`)
  - Features: 3D layers via Deck.gl integration, Threebox 3D objects

**Authentication & Identity:**
- **TaipeiPass** - Taipei city's OAuth identity provider
  - Protocol: OAuth 2.0
  - Auth Endpoint: `VITE_TAIPEIPASS_URL` (frontend) / `TAIPEIPASS_URL` (backend)
  - Client ID: `ISSO_CLIENT_ID` / `VITE_TAIPEIPASS_CLIENT_ID`
  - Scope: `ISSO_CLIENT_SCOPE` / `VITE_TAIPEIPASS_SCOPE`
  - Used by: User authentication and authorization in both frontend and backend
  - Callback: `CallBack.vue` component in frontend
  - Backend Integration: `global/global.go` Isso config

- **ISSO (Internal SSO)** - Internal single sign-on (if used)
  - Base URL: `ISSO_URL` (default: `https://id.taipei/isso`)
  - Client Secret: `ISSO_CLIENT_SECRET`
  - Used by: User authentication in dashboard

## Data Storage

**Databases:**
- **PostgreSQL (Dashboard)** - Primary application database
  - Connection: `DB_DASHBOARD_HOST`, `DB_DASHBOARD_USER`, `DB_DASHBOARD_PASSWORD`, `DB_DASHBOARD_DBNAME` (default: `dashboard`)
  - Port: `DB_DASHBOARD_PORT` (default: 5432)
  - Client: GORM `gorm.io/driver/postgres` v1.5.4
  - Features: PostGIS extension for geospatial data
  - Docker service: `postgres-data`

- **PostgreSQL (Manager)** - Dashboard management and metadata database
  - Connection: `DB_MANAGER_HOST`, `DB_MANAGER_USER`, `DB_MANAGER_PASSWORD`, `DB_MANAGER_DBNAME` (default: `dashboardmanager`)
  - Port: `DB_MANAGER_PORT` (default: 5432)
  - Client: GORM v1.25.5
  - Docker service: `postgres-manager`
  - Used by: Qdrant vector DB upgrade service, user and configuration management

**Vector Database:**
- **Qdrant** - Vector similarity search for embeddings
  - Server URL: `QDRANT_URL` (default: `http://qdrant:6333`)
  - API Key: `QDRANT_API_KEY` (for authentication)
  - Collection: `QDRANT_COLLECTION` (default: `query_charts`)
  - Features: Used for semantic search of dashboard queries and charts
  - Integration: `app/models/qdrant.go` with ONNX embedding models
  - Upgrade Service: `vector-db-upgrade` container for schema migrations

**File Storage:**
- **MinIO** - S3-compatible object storage (Data Engineering)
  - SDK/Client: `minio` v7.2.5 (Python)
  - Used by: Data Engineering pipelines for storing processed data, raw data exports
  - Configuration: Managed via environment variables in Data Engineering docker-compose

**Caching:**
- **Redis** - In-memory data store for caching and message broker
  - Host: `REDIS_HOST` (default: `redis`)
  - Port: `REDIS_PORT` (default: 6379)
  - Database: `REDIS_DB` (default: 0)
  - Password: `REDIS_PASSWORD` (optional)
  - Client: `github.com/go-redis/redis` v6.15.9
  - Used by: Session caching, query result caching, Airflow broker in Data Engineering

## Authentication & Identity

**Auth Provider:**
- **TaipeiPass OAuth 2.0** - Primary identity provider
  - Implementation: OAuth 2.0 authorization code flow
  - Frontend handling: `CallBack.vue` component
  - Backend handling: JWT token generation/validation with secret stored in `JWT_SECRET`
  - User ID Hashing: `IDNO_SALT` for secure user ID transformation

**JWT:**
- Token signing secret: `JWT_SECRET` (env var, backend only)
- Token validation: `github.com/dgrijalva/jwt-go` v3.2.0

## Monitoring & Observability

**Error Tracking:**
- Not detected in current configuration

**Logs:**
- File-based logging in `Taipei-City-Dashboard-BE/logs/` directory
- Airflow logging: `/opt/airflow/logs/` in Data Engineering
- Structured logging: `TaipeiCityDashboardBE/logs` package

## CI/CD & Deployment

**Hosting:**
- **Local Development:** Docker Compose (creates `br_dashboard` bridge network)
- **Production:** Kubernetes (via Helm charts in `helm-chart/`)

**CI Pipeline:**
- GitHub Actions (workflows in `.github/workflows/`)

**Containers:**
- **Frontend:** Node.js `21.6.0-alpine3.18`
- **Backend:** Debian `bookworm-slim` with Go runtime and ONNX Runtime library
- **Data Engineering:** Apache Airflow `2.10.5` with Celery workers
- **Nginx:** `latest` for reverse proxy

## Environment Configuration

**Required env vars (Frontend):**
- `VITE_API_URL` - Backend API endpoint
- `VITE_MAPBOXTOKEN` - Mapbox access token (must be set for maps)
- `VITE_MAPBOXTILE` - Mapbox tile URL
- `VITE_TAIPEIPASS_URL` - TaipeiPass OAuth URL
- `VITE_TAIPEIPASS_CLIENT_ID` - TaipeiPass client ID
- `VITE_TAIPEIPASS_SCOPE` - OAuth scopes

**Required env vars (Backend):**
- `DB_DASHBOARD_HOST`, `DB_DASHBOARD_USER`, `DB_DASHBOARD_PASSWORD`, `DB_DASHBOARD_DBNAME` - Dashboard DB
- `DB_MANAGER_HOST`, `DB_MANAGER_USER`, `DB_MANAGER_PASSWORD`, `DB_MANAGER_DBNAME` - Manager DB
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_DB` - Redis configuration
- `QDRANT_URL`, `QDRANT_API_KEY`, `QDRANT_COLLECTION` - Qdrant configuration
- `JWT_SECRET` - JWT signing key
- `IDNO_SALT` - User ID hashing salt
- `LM_MODEL_PATH` - ONNX embedding model path (default: `/opt/lm_model/onnx-e5/`)
- `AI_TIMEOUT`, `AI_MAX_RETRY`, `AI_MAX_CONCURRENT` - AI service configuration
- `TWCC_API_URL`, `TWCC_API_KEY`, `TWCC_MODEL` - TWCC configuration (if using TWCC)
- `OPENAI_API_URL`, `OPENAI_API_KEY`, `OPENAI_MODEL` - OpenAI configuration (if using OpenAI)
- `GEMINI_API_URL`, `GEMINI_API_KEY`, `GEMINI_MODEL` - Gemini configuration (if using Gemini)

**Required env vars (Data Engineering/Airflow):**
- `MATADATA_DATABASE` - Airflow metadata DB connection string
- `CELERY_RESULT_BACKEND` - Celery result backend URL
- `REDIS_CONN` - Redis connection string for Celery broker
- `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_MAIL_FROM` - Gmail SMTP for notifications
- `AIRFLOW_SUMMARY_BASE_URL`, `AIRFLOW_SUMMARY_SVC_USER`, `AIRFLOW_SUMMARY_SVC_PASS` - Airflow API access

**Secrets location:**
- Docker: `.env` file (never committed, use `.env.template` as reference)
- Configuration files: `docker/.env.template`, `Taipei-City-Dashboard-FE/.env.template`
- Kubernetes: Stored as Secrets in cluster (via Helm values)
- Secret management: Do NOT commit `.env` or `mapbox-key.txt`

## Webhooks & Callbacks

**Incoming:**
- **TaipeiPass OAuth Callback** - `CallBack.vue` component handles OAuth redirect
  - Endpoint: Frontend route `/callback` or similar
  - Flow: User redirected from TaipeiPass after authentication

**Outgoing:**
- **Airflow Summary API** - Backend calls Airflow REST API
  - Base URL: `AIRFLOW_SUMMARY_BASE_URL`
  - Authentication: `AIRFLOW_SUMMARY_SVC_USER` + `AIRFLOW_SUMMARY_SVC_PASS`
  - Used for: Fetching data pipeline summaries in backend

## Data Pipeline Integration

**Apache Airflow** - Data orchestration
- Version: `2.10.5`
- Executor: CeleryExecutor with Redis broker
- Worker Queues:
  - `default` - General-purpose tasks (concurrency: 1)
  - `realtime` - Immediate execution tasks (concurrency: 10)
  - `heavy` - Resource-intensive tasks (concurrency: 4)
- Services: Webserver, Scheduler, Workers (default/realtime/heavy), Triggerer, Flower monitoring
- Metadata DB: PostgreSQL
- Result Backend: Redis
- Email Notifications: Gmail SMTP
- Data Sources: Connected to dashboard databases and MinIO storage

---

*Integration audit: 2026-10-06*
