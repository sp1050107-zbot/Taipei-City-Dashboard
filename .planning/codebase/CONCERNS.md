# Codebase Concerns

<!-- refreshed: 2026-10-06 -->

**Analysis Date:** 2026-10-06

## Initialization Crashes

### Critical: Missing ONNX Model/Tokenizer Crashes Backend at Startup

**What happens:** Backend calls `InitLmSession()` and `InitTokenizer()` at startup (in `app/app.go:47-48`). Both functions have hardcoded `log.Fatalf()` calls that terminate the entire process if the ONNX model or tokenizer.json files are missing or unreadable.

**Why it's wrong:** The backend becomes undeployable if the model files are not present or mounted correctly. No graceful degradation; no retry logic; no informative startup feedback about missing dependencies.

**Files:**
- `Taipei-City-Dashboard-BE/app/models/qdrant.go:102` - `log.Fatalf("InitializeEnvironment error: %v", err)`
- `Taipei-City-Dashboard-BE/app/models/qdrant.go:130` - `log.Fatalf("NewDynamicSession error: %v", err)` (when model.onnx not found)
- `Taipei-City-Dashboard-BE/app/models/qdrant.go:142` - `log.Fatalf("Critical: Failed to load tokenizer: %v", err)` (when tokenizer.json not found)
- `Taipei-City-Dashboard-BE/app/models/qdrant.go:159,166,176,189,205,215` - Additional `log.Fatalf()` calls in `GenVector()` (runtime crash on tokenization errors)
- `Taipei-City-Dashboard-BE/app/app.go:47-48` - Calls both init functions during `StartApplication()`

**Impact:** Production deployments fail completely if the large model files (`/opt/lm_model/onnx-e5/model.onnx`, `/opt/lm_model/onnx-e5/tokenizer.json`) are not properly mounted or downloaded. Container startup hangs and fails health checks. Kubernetes deployments never become Ready.

**Fix approach:** Convert `log.Fatalf()` to `log.Fatalf()` to error return values. Make model loading optional with fallback behavior. Provide startup warnings but allow the backend to run in degraded mode without vector operations. Add comprehensive startup logging to identify missing files early.

---

## Deployment & Container Configuration

### Issue: Fixed Container Names Create Deployment Conflicts

**What happens:** All Docker Compose files specify hardcoded `container_name` values:
- `nginx`, `dashboard-fe`, `dashboard-be`, `vector-db-upgrade` (docker-compose.yaml)
- `dashboard-fe-init`, `dashboard-be-init-manager`, `dashboard-be-init-dashboard` (docker-compose-init.yaml)
- `redis`, `postgres-data`, `postgres-manager`, `pgadmin`, `qdrant` (docker-compose-db.yaml)

**Why it's wrong:** Docker container names must be unique per host. Two developers or CI/CD pipelines running containers simultaneously on the same machine will crash — the second instance can't start because names are already taken. Kubernetes deployments (which don't use docker-compose) have their own naming, so this is only a local dev issue, but it blocks parallel testing and CI practices.

**Files:**
- `docker/docker-compose.yaml`: lines 6, 17, 44, 100
- `docker/docker-compose-init.yaml`: lines 5, 15, 36
- `docker/docker-compose-db.yaml`: lines 6, 13, 24, 37, 50

**Impact:** Multiple developers cannot run docker-compose on the same machine. CI/CD pipelines can only run one test suite at a time. Docker Compose project management is fragile.

**Fix approach:** Remove hardcoded `container_name` values and rely on Docker Compose's auto-generated names (project-scoped). If you need predictable names, use `docker-compose -p <project-name>` to scope by project name.

---

### Issue: Latest Image Tags in Production Paths

**What happens:** Docker Compose files use `:latest` tags for critical services:
- `nginx:latest`, `node:latest`, `golang:latest` (docker-compose.yaml:7, 16, 39)
- `pgadmin4:latest`, `qdrant:latest` (docker-compose-db.yaml:36, 49)
- `node:latest`, `golang:latest` (docker-compose-init.yaml:4, 14, 35)

**Why it's wrong:** `latest` tags are non-deterministic. Deployments can pull different image versions at different times, causing silent behavior changes and making it impossible to reproduce issues or roll back. A critical security patch in qdrant or pgadmin silently applies to all new containers without warning. This breaks the principle of reproducible deployments.

**Files:**
- `docker/docker-compose.yaml`: lines 7, 16, 39, 99
- `docker/docker-compose-db.yaml`: lines 36, 49
- `docker/docker-compose-init.yaml`: lines 4, 14, 35

**Impact:** Unpredictable deployments. Debugging becomes harder (which version was running?). Security patches apply silently. Rollback is impossible if `latest` has moved forward.

**Fix approach:** Pin all image tags to specific versions in production. Use `.env.template` overrides for development flexibility, but commit production docker-compose with pinned tags (e.g., `nginx:1.25.3-alpine`, `qdrant:v1.7.4`).

---

### Issue: External Docker Network Required; Automatic Creation Not Configured

**What happens:** All docker-compose files declare the network as `external: true` and require pre-creation:
```yaml
networks:
  default:
    name: br_dashboard
    external: true
```

Commands documented in comments show manual network creation:
```bash
docker network create --driver=bridge --subnet=192.168.128.0/24 --gateway=192.168.128.1 br_dashboard
```

**Why it's wrong:** New developers or CI/CD pipelines will fail immediately with "network not found" if they haven't run the setup command. The network setup is a hidden prerequisite. Teardown/cleanup also requires manual intervention.

**Files:**
- `docker/docker-compose.yaml:111-119`
- `docker/docker-compose-init.yaml:52-55`
- `docker/docker-compose-db.yaml:66-69`

**Impact:** Onboarding friction. CI/CD failures due to missing network setup. No automatic recovery. Requires documentation or scripts to set up, increasing deployment complexity.

**Fix approach:** Change `external: true` to `external: false` (or remove it) to let Docker Compose auto-create the network. If a specific subnet is required, define it in docker-compose: `driver_opts: {com.docker.network.bridge.name: "br_dashboard"}`.

---

## Security & Secrets

### Issue: Weak Default Secrets in Template

**What happens:** `docker/.env.template` contains weak placeholder secrets:
- `JWT_SECRET=secret` (line 21)
- `IDNO_SALT=salt` (line 22)

These are the defaults in `Taipei-City-Dashboard-BE/global/global.go:79-80` and get loaded even if `.env` is not filled. Any deployment using these defaults has cryptographically weak token signing and hashing.

**Files:**
- `docker/.env.template:21-22`
- `Taipei-City-Dashboard-BE/global/global.go:79-80`
- `Taipei-City-Dashboard-BE/app/middleware/auth.go:14` (uses `global.JwtSecret` directly)

**Impact:** All JWTs signed with "secret" are forgeable. Session tokens are not cryptographically secure. Any user with knowledge of the backend can forge admin tokens.

**Fix approach:** Generate strong random defaults or require env vars to be explicitly set before startup. Provide setup scripts that generate secrets: `openssl rand -base64 32`. Fail startup if `JWT_SECRET` or `IDNO_SALT` are still at default values.

---

### Issue: Database Credentials Exposed in Docker Compose Environment

**What happens:** Database passwords are passed as environment variables in docker-compose files and `.env.template`. No encryption at rest. Credentials visible in process listings and docker inspect output.

**Files:**
- `docker/docker-compose.yaml:54-66` (dashboard-be service env vars with DB passwords)
- `docker/.env.template:37-62` (all database passwords)

**Impact:** Accidental credential leaks in logs, screenshots, or CI output. Credentials readable by any process on the host with access to the docker daemon.

**Fix approach:** Use Docker Secrets (Swarm mode) or external secret management (Kubernetes Secrets, HashiCorp Vault). Pass secrets via files mounted with 0600 permissions, not environment variables. For local dev, use `.env` files with strict gitignore.

---

### Issue: API Key Placeholders in Configuration

**What happens:** Multiple external service API keys have placeholder or empty values in `docker/.env.template` and `global/global.go`:
- `QDRANT_API_KEY=your_api_key` (line 66, .env.template)
- `TWCC_API_KEY=your_twcc_api_key_here` (line 79)
- `OPENAI_API_KEY=your_openai_api_key_here` (line 84)
- `GEMINI_API_KEY=your_gemini_api_key_here` (line 89)
- `AIRFLOW_SUMMARY_SVC_PASS=` (line 95, empty)

**Why it's wrong:** Developers might accidentally deploy with placeholder keys. API calls fail silently or expose error messages that reveal the placeholder key. No validation at startup to detect missing credentials.

**Files:**
- `docker/.env.template:66,79,84,89,93-95`
- `Taipei-City-Dashboard-BE/global/global.go:143-165`

**Impact:** AI features fail without clear error messages. Airflow integration doesn't work silently. Developers might think features are unimplemented instead of under-configured.

**Fix approach:** Add startup validation to check for required API keys. Log warnings (not info) if external service credentials are missing, blocking those features explicitly.

---

## External Service Dependencies

### Issue: Hard Dependencies on Multiple Proprietary AI Services

**What happens:** Backend has conditional support for TWCC, OpenAI, and Gemini AI providers. All three are required to be configured (even if optional), and API keys for all are loaded at startup.

**Files:**
- `Taipei-City-Dashboard-BE/global/global.go:143-159` (TWCC, OpenAI, Gemini configs)
- `Taipei-City-Dashboard-BE/app/services/ai/ai_service.go:62-81` (provider selection)
- `Taipei-City-Dashboard-BE/app/services/ai/providers/factory.go` (provider factory)

**Dependencies:**
- TWCC AI Foundry Service (`TWCC_API_URL`, `TWCC_API_KEY`)
- OpenAI API (`OPENAI_API_URL`, `OPENAI_API_KEY`)
- Google Gemini API (`GEMINI_API_URL`, `GEMINI_API_KEY`)

**Impact:** If any external service goes down or rate-limits, backend AI features degrade. No fallback chain. API changes or authentication failures cause backend errors. Vendor lock-in on at least two third-party AI providers. Cost exposure — OpenAI and Gemini API calls are charged per token.

**Fix approach:** Implement graceful provider fallback. Make at least one provider truly optional. Add circuit breakers for external API calls. Monitor API error rates and respond with cached responses or degraded features.

---

### Issue: Mapbox Token and Proprietary Tileset Dependency

**What happens:** Frontend requires Mapbox tokens and a proprietary tileset URL for the map to render:
- `VITE_MAPBOXTOKEN` — required for Mapbox GL JS authentication
- `VITE_MAPBOXTILE` — required for proprietary tile layer styling

**Files:**
- `docker/.env.template:13-14` (empty placeholders)
- `Taipei-City-Dashboard-FE/src/store/mapStore.js:112-113` (token assignment)
- `Taipei-City-Dashboard-FE/vite.config.js` (geo_server proxy)

**Impact:** Map is non-functional without valid Mapbox credentials. Mapbox service pricing depends on usage (tile requests, vector tile requests). If Mapbox raises prices or changes pricing model, all map rendering costs change automatically. No open-source alternative configured.

**Fix approach:** Add OpenStreetMap (Leaflet/Maplibre) as free fallback. Make Mapbox optional. Cache tile layers locally if possible.

---

### Issue: Hard Dependency on GeoServer Instance

**What happens:** Frontend layers rely on a `/geo_server` endpoint for proprietary GeoServer WFS/WMS/tile services:
- `${location.origin}/geo_server/taipei_vioc/ows` — WFS service for feature queries
- `${location.origin}/geo_server/gwc/service/tms/1.0.0/taipei_vioc:*` — Cached tile services

**Files:**
- `Taipei-City-Dashboard-FE/src/store/mapStore.js` (multiple geo_server endpoints)
- `Taipei-City-Dashboard-FE/vite.config.js:10-12` (proxy to external GeoServer)

**Impact:** All map layers fail if GeoServer is down or unreachable. GeoServer is external infrastructure not managed by this dashboard repo. Requires deployment and maintenance of a separate service. No graceful degradation if GeoServer is unavailable.

**Fix approach:** Document GeoServer as a critical external dependency with its own runbook. Implement layer-level error handling and disable broken layers instead of crashing the map.

---

### Issue: Incomplete Rate Limiting Feature

**What happens:** Rate limiting middleware has a TODO comment indicating the whitelist/blacklist feature is incomplete:

```go
// TO BE COMPLETED: check if white_listed or black_listed and skip if so
```

**Files:**
- `Taipei-City-Dashboard-BE/app/middleware/rateLimit.go:65`

**Impact:** Users marked as whitelisted (if the feature existed) are NOT actually bypassed. Black-listed users are NOT blocked. The feature is half-implemented, leading to inconsistent behavior if code referencing it exists elsewhere. Developers may assume the feature works.

**Fix approach:** Complete the whitelist/blacklist lookup or remove the TODO and document that feature is not yet implemented.

---

## Database & Initialization

### Issue: InitDashboardManager Functions Not Idempotent

**What happens:** The `InitDashboardManager()` function in `app/initial/initial.go` calls:
1. `addRoles()` — creates "admin", "editor", "viewer" roles (lines 53-67)
2. `createAdmin()` — creates default admin user (lines 69-100)

Neither function checks if the role or user already exists before creation. Running `migrateDB` command twice will fail on duplicate key constraint violations.

**Files:**
- `Taipei-City-Dashboard-BE/app/initial/initial.go:53-67` (addRoles)
- `Taipei-City-Dashboard-BE/app/initial/initial.go:69-100` (createAdmin)
- `Taipei-City-Dashboard-BE/app/models/auth.go:73-90` (CreateRole — no duplicate check)
- `Taipei-City-Dashboard-BE/app/models/user.go:94+` (CreateUser — no duplicate check)
- `Taipei-City-Dashboard-BE/cmd/root.go:36-44` (migrateDB command)

**Impact:** Re-running initialization (common in containerized deployments with init sidecars) will crash with database constraint violations. Recovery requires manual database cleanup.

**Fix approach:** Add exists checks in `addRoles()` and `createAdmin()`. Modify `CreateRole()` and `CreateUser()` to use "INSERT ... ON CONFLICT DO NOTHING" or check for existing records before creation.

---

## Configuration & Deployment

### Issue: SSL/TLS Configuration Commented Out in Nginx

**What happens:** The nginx default config has SSL configuration commented out:
```nginx
#listen 443 ssl;
#ssl_certificate /etc/nginx/ssl/citydashboard-fullchain1.pem;
#ssl_certificate_key /etc/nginx/ssl/citydashboard-privkey.pem;
```

The file also documents itself as "recommended for use only in the local development environment."

**Files:**
- `docker/nginx/conf.d/default.conf:1,11,14-15`

**Impact:** HTTPS is disabled in the default configuration. Production deployments running this config transmit all traffic over unencrypted HTTP. STS header (line 13) is set to demand HTTPS, but HTTPS is not configured, creating a misconfiguration trap.

**Fix approach:** Uncomment SSL lines and document how to mount certificates into the container. Create a separate production nginx config with HTTPS enforced. Add validation to ensure SSL certs are present before starting nginx.

---

### Issue: Database Port Exposed to Host Network

**What happens:** `postgres-manager` service exposes port 5432 to the host:
```yaml
ports:
  - "5432:5432"
```

This allows any host user to connect to the dashboard manager database directly, bypassing the backend application logic.

**Files:**
- `docker/docker-compose-db.yaml:32-33`

**Impact:** Direct database access is a security boundary violation. Users could bypass application authorization and directly query/modify sensitive data. Backup/restore tools may connect directly and overwrite production data.

**Fix approach:** Remove the port mapping in production. Use only internal Docker network communication. Only expose postgres for local development under a clear warning.

---

### Issue: Missing Startup Validation for Critical Dependencies

**What happens:** Backend starts without validating that critical external services are reachable:
- Qdrant vector database
- Redis cache
- Mapbox (frontend-side)
- GeoServer (frontend-side)

**Files:**
- `Taipei-City-Dashboard-BE/app/app.go:33-51` (StartApplication)
- Missing: startup health checks for external services

**Impact:** Backend appears to start successfully but fails when users trigger AI or vector-based features. Frontend map works until GeoServer goes down. No diagnostic output on startup about which services are unavailable.

**Fix approach:** Add startup health checks for Qdrant, Redis, and external AI providers. Log warnings (not errors) for unreachable services. Proceed with startup but disable affected features.

---

## Performance & Scaling

### Issue: Vector Database Size Limit Not Documented

**What happens:** Qdrant docker-compose sets a storage size limit:
```yaml
- QDRANT__STORAGE__SIZE_LIMIT=20GB
```

No documentation about what happens when this limit is reached or how to increase it in production.

**Files:**
- `docker/docker-compose-db.yaml:61`

**Impact:** Qdrant silently fails to store new vectors when the 20GB limit is hit. New AI chat sessions or vector operations fail with unclear error messages. Production outage without warning.

**Fix approach:** Document the limit and provide scaling guidance. Monitor Qdrant storage usage. Provide a pre-incident runbook for expanding the volume and increasing the limit.

---

## Testing & Development

### Issue: AI Service Concurrency Limited to 100

**What happens:** AI service limits concurrent requests to 100:
```go
MaxConcurrent: getIntEnv("AI_MAX_CONCURRENT", 100)
```

No documentation about impact of concurrent AI requests on the external services (TWCC, OpenAI, Gemini).

**Files:**
- `Taipei-City-Dashboard-BE/global/global.go:140`
- `Taipei-City-Dashboard-BE/app/services/ai/ai_service.go:31-33` (semaphore limiting)

**Impact:** If the backend receives more than 100 concurrent AI requests, they queue and may timeout. External AI service rate limits or costs may be exceeded. No circuit breaker to prevent runaway requests.

**Fix approach:** Add monitoring for concurrent AI request queue length. Implement adaptive concurrency based on external service response times.

---

## Missing Features & Documentation

### Issue: Missing Fallback for Missing Mapbox Configuration

**What happens:** Frontend loads without checking if `VITE_MAPBOXTOKEN` is set. If the token is missing or invalid, the error occurs at runtime when the map initializes, not at build time.

**Files:**
- `Taipei-City-Dashboard-FE/src/store/mapStore.js:112` (token assignment without validation)

**Impact:** Frontend builds successfully but crashes with cryptic Mapbox errors at runtime when token is missing. Users see a broken map with no explanation.

**Fix approach:** Add validation in mapStore initialization to detect missing token and provide a clear error message. Offer OpenStreetMap fallback if available.

---

**Analysis Date:** 2026-10-06

*Concerns audit: 2026-10-06*
