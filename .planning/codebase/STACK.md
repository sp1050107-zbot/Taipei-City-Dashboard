# Technology Stack

**Analysis Date:** 2026-10-06

## Languages

**Primary:**
- **JavaScript/TypeScript** - Vue 3 components, frontend routing, and build tooling
- **Go** `1.25.4` - Backend API server and data processing (main application language)
- **Python** `3.12` - Data engineering pipelines, model export, geospatial data processing

**Secondary:**
- **SQL** - PostgreSQL database schemas and migrations

## Runtime

**Environment:**
- **Frontend:** Node.js `21.6.0-alpine3.18` (Docker image)
- **Backend:** Go `1.25.4-bookworm` (compiled binary)
- **Data Engineering:** Python `3.12-slim` (Docker image)
- **Orchestration:** Apache Airflow `2.10.5`

**Package Manager:**
- **Frontend:** npm (implicit via Node.js)
- **Backend:** Go modules via `go.mod`
- **Data Engineering:** pip (Python)

## Frameworks

**Core:**
- **Vue 3** `^3.4.15` - Frontend UI framework with Composition API
- **Gin** `v1.9.1` - Go HTTP web framework for REST API
- **Apache Airflow** `2.10.5` - Data orchestration and scheduling (Data Engineering)

**Build/Dev:**
- **Vite** `^5.0.12` - Frontend bundler and dev server
- **Rollup** - Module bundler (via Vite)
- **Docker** - Container orchestration for all services

**Testing:**
- `pytest` `8.1.1` - Python test framework (Data Engineering)

## Key Dependencies

**Frontend - Mapping & Visualization:**
- `mapbox-gl` `^3.1.0` - Vector tile mapping library
- `@deck.gl/core` `^9.0.9` - Large-scale data visualization framework
- `@deck.gl/layers` `^9.0.9` - Deck.gl layer components
- `@deck.gl/mapbox` `^9.0.9` - Deck.gl + Mapbox integration
- `three.js` `^0.163.0` - 3D graphics library (used with Threebox)
- `threebox-plugin` `^2.2.7` - 3D objects on Mapbox
- `@turf/turf` `^6.5.0` - Geospatial analysis toolkit

**Frontend - Charts & UI:**
- `apexcharts` `^3.45.2` - Interactive charting library
- `vue3-apexcharts` `^1.4.4` - Vue 3 wrapper for ApexCharts
- `material-icons` `^1.13.12` - Material Design icon set

**Frontend - Utilities:**
- `axios` `^1.6.5` - HTTP client
- `pinia` `^2.1.7` - State management store
- `vue-router` `^4.2.5` - Client-side routing
- `@vueuse/core` `^10.7.2` - Vue 3 Composition utilities
- `dayjs` `^1.11.10` - Date/time handling
- `lodash.debounce` `^4.0.8` - Debounce utility
- `uuid` `^9.0.1` - UUID generation
- `hls.js` `^1.6.7` - HLS video streaming

**Backend - Core:**
- `github.com/gin-gonic/gin` `v1.9.1` - REST API framework
- `gorm.io/gorm` `v1.25.5` - ORM for database operations
- `gorm.io/driver/postgres` `v1.5.4` - PostgreSQL driver for GORM

**Backend - Authentication & Security:**
- `github.com/dgrijalva/jwt-go` `v3.2.0` - JWT token handling
- `github.com/fvbock/endless` - Graceful server shutdown

**Backend - Data & Vectorization:**
- `github.com/yalue/onnxruntime_go` `v1.22.0` - ONNX Runtime for embedding models (required at startup)
- `github.com/sugarme/tokenizer` `v0.3.0` - Text tokenization
- `github.com/sugarme/regexpset` - Regex pattern matching

**Backend - Caching & Messaging:**
- `github.com/go-redis/redis` `v6.15.9` - Redis client for caching
- `github.com/robfig/cron/v3` `v3.0.1` - Cron job scheduling

**Backend - AI/LLM:**
- `github.com/tmc/langchaingo` `v0.1.14` - Go SDK for LangChain
- `cloud.google.com/go/ai` `v0.7.0` - Google AI Foundry SDK
- `google.golang.org/api` `v0.218.0` - Google API client library
- `github.com/google/generative-ai-go` `v0.15.1` - Google Gemini API

**Backend - Utilities:**
- `github.com/google/uuid` `v1.6.0` - UUID generation
- `github.com/spf13/cobra` `v1.8.0` - CLI framework

**Data Engineering - Geospatial:**
- `geopandas` `0.13.2` - Geospatial data analysis
- `GeoAlchemy2` `0.14.7` - SQLAlchemy geospatial types
- `Rtree` `1.2.0` - Spatial index library
- `geopy` `2.4.1` - Geocoding library

**Data Engineering - Database:**
- `psycopg2` `2.9.9` - PostgreSQL adapter for Python
- `openpyxl` `3.1.2` - Excel file handling
- `XlsxWriter` `3.2.0` - Excel file generation

**Data Engineering - Storage & Utilities:**
- `minio` `7.2.5` - S3-compatible object storage client
- `odfpy` `1.4.1` - ODF (OpenDocument) file support
- `pyminizip` `0.2.6` - Zip compression
- `wget` `3.2` - Download utility

## Configuration

**Environment:**
- **Frontend:** Vite dev server with proxy configuration for API routes
  - `VITE_API_URL` - Backend API endpoint (default: `/api/dev`)
  - `VITE_MAPBOXTOKEN` - Mapbox access token
  - `VITE_MAPBOXTILE` - Mapbox tile URL
  - `VITE_TAIPEIPASS_URL` - OAuth provider endpoint
  - `VITE_TAIPEIPASS_CLIENT_ID` - OAuth client ID
  - `VITE_TAIPEIPASS_SCOPE` - OAuth scope

- **Backend:** Gin web server with environment-based configuration
  - `GIN_MODE` - Server mode (debug/release/test)
  - `GIN_DOMAIN` - Server bind address (0.0.0.0 in dev)
  - `GIN_PORT` - Server port (default: 8080)
  - `JWT_SECRET` - JWT signing secret
  - `IDNO_SALT` - ID salt for hashing
  - `LM_MODEL_PATH` - ONNX embedding model directory (default: `/opt/lm_model/onnx-e5/`)
  - AI service timeouts and retry configuration

- **Data Engineering:** Apache Airflow with Celery executor
  - Separate worker queues: `default`, `realtime`, `heavy`
  - Redis broker for task queue
  - PostgreSQL metadata database
  - Gmail SMTP for notifications

**Build:**
- **Frontend:** `vite.config.js` - Vite configuration with Vue 3 plugin, compression, and dev proxy
- **Backend:** `go.mod`, `go.sum` - Go module dependencies
- **Dockerfile (Backend):** Multi-stage build with:
  - Model export stage (Python with Hugging Face transformers)
  - Builder stage (Go compilation)
  - Runtime stage (Debian slim + ONNX Runtime library)
- **docker-compose.yaml** - Orchestrates all services
- **Prettier** `.prettierrc` - Code formatting
- **ESLint** `eslint.config.js` - Linting

## Platform Requirements

**Development:**
- Docker & Docker Compose (for containerized dev environment)
- Node.js 21.6.0+ (frontend)
- Go 1.25.4 (backend)
- Python 3.12+ (data engineering)
- libonnxruntime library (for ONNX Runtime Go bindings)
- PostgreSQL 12+ with PostGIS extension
- Redis 7.2+
- Qdrant vector database

**Production:**
- Kubernetes (via Helm chart in `helm-chart/`)
- Docker container registry
- PostgreSQL database cluster (separate databases: dashboard, dashboardmanager)
- Redis instance
- Qdrant vector database instance
- ONNX Runtime library (v1.23.2) for embedding model inference
- External AI services (optional): TWCC, OpenAI, Google Gemini
- Airflow orchestration service (optional)

## Load Balancing & Reverse Proxy

- **Nginx** `latest` - Reverse proxy and static file serving (see `docker/nginx/conf.d/`)
- SSL/TLS termination at nginx layer

---

*Stack analysis: 2026-10-06*
