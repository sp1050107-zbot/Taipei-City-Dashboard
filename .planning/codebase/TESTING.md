# Testing Patterns

**Analysis Date:** 2026-10-06

## Backend Testing (Go)

### Test Framework

**Runner:**
- Standard Go testing library (`testing` package)
- No specialized framework (no testify, no ginkgo observed)
- Version: Go 1.24.10 (from `go.mod`)

**Test discovery:**
- Files: `*_test.go` format
- Functions: `TestXxx(t *testing.T)` signature

**Run command:**
```bash
go test ./...                    # Run all tests in current module
go test ./app/services/...       # Run tests in specific package
go test -v                       # Verbose output
go test -run TestName            # Run specific test
```

**NOTE:** CI workflow at `.github/workflows/go.yml` only runs `go build`, not `go test` — **tests are not executed in CI**. This is a coverage gap.

### Test File Organization

**Location:** Co-located with implementation
- Implementation: `Taipei-City-Dashboard-BE/app/services/isochrone/gtfs/calendar.go`
- Tests: `Taipei-City-Dashboard-BE/app/services/isochrone/gtfs/calendar_test.go`

**Naming:**
- Same package as implementation (e.g., `package gtfs`)
- File suffix: `_test.go`
- Test functions: `TestXxx` or `TestXxxYyyy`

**Found test files:**
```
Taipei-City-Dashboard-BE/app/services/isochrone/raptor/query_test.go
Taipei-City-Dashboard-BE/app/services/isochrone/raptor/builder_test.go
Taipei-City-Dashboard-BE/app/services/isochrone/raptor/scanner_test.go
Taipei-City-Dashboard-BE/app/services/isochrone/gtfs/calendar_test.go
Taipei-City-Dashboard-BE/app/services/isochrone/isochrone/index_test.go
Taipei-City-Dashboard-BE/app/services/isochrone/isochrone/network_test.go
```

### Test Structure

**Basic test pattern:**
```go
func TestActiveServicesForProfile(t *testing.T) {
    // Setup
    feed := &Feed{
        Calendar: map[string]*ServicePattern{
            "bus_monday": {
                Weekdays: [7]bool{true, false, false, false, false, false, false},
            },
        },
    }
    
    // Execute
    weekday := ActiveServicesForProfile(feed, ServiceProfileWeekday)
    
    // Assert
    if !weekday["bus_monday"] {
        t.Fatalf("expected weekday bus service")
    }
}
```

**Assertion patterns:**
- Fatal assertions: `t.Fatalf("message", args...)` — stops test immediately
- Non-fatal: `t.Errorf("message", args...)` — continues test
- All use formatted strings for output

**Example assertions from `calendar_test.go` (`Taipei-City-Dashboard-BE/app/services/isochrone/gtfs/calendar_test.go`):
```go
if !weekday["bus_monday"] {
    t.Fatalf("expected weekday bus service")
}
if weekday["rail_holiday"] || weekday["2024-01-07_0000001"] {
    t.Fatalf("unexpected holiday-only service in weekday profile: %#v", weekday)
}
if got != want {
    t.Fatalf("ParseServiceProfile(%q)=%q, want %q", input, got, want)
}
```

### Mocking

**Approach:** No mocking framework used; uses helper functions to create test fixtures

**Pattern - Creating test data:**
```go
func testFeed(prefix string, stops map[string]*gtfs.RawStop, trips ...[]gtfs.RawStopTime) *gtfs.Feed {
    feed := &gtfs.Feed{
        Prefix:    prefix,
        Stops:     stops,
        Routes:    map[string]*gtfs.RawRoute{"r": {ID: "r"}},
        Trips:     make(map[string]*gtfs.RawTrip),
        StopTimes: make(map[string][]gtfs.RawStopTime),
        Calendar:  make(map[string]*gtfs.ServicePattern),
        CalDates:  make(map[string][]gtfs.CalDateException),
        Freqs:     make(map[string][]gtfs.FreqEntry),
    }
    for i, stopTimes := range trips {
        tripID := string(rune('a' + i))
        feed.Trips[tripID] = &gtfs.RawTrip{ID: tripID, RouteID: "r", ServiceID: "svc"}
        feed.StopTimes[tripID] = stopTimes
    }
    return feed
}
```

**What is tested:**
- Unit-level functionality (single function/method behavior)
- Data transformation and parsing
- Edge cases in business logic

**What is NOT tested (gaps):**
- HTTP handlers/controller layer
- Database operations (GORM integration)
- External service calls (AI providers, transit APIs)

### Fixtures and Factories

**Pattern:** Helper functions with `test` prefix

**Example from `builder_test.go` (`Taipei-City-Dashboard-BE/app/services/isochrone/raptor/builder_test.go`):
```go
feed := testFeed("bus:", map[string]*gtfs.RawStop{
    "a": {ID: "a", Name: "Taipei Main", Lat: 25.04780, Lon: 121.51740},
    "b": {ID: "b", Name: "Taipei Main", Lat: 25.04790, Lon: 121.51750},
    "c": {ID: "c", Name: "Zhongshan", Lat: 25.05200, Lon: 121.52000},
}, []gtfs.RawStopTime{
    {StopID: "a", Sequence: 1, Arrival: 28800, Dep: 28800},
    {StopID: "c", Sequence: 2, Arrival: 29100, Dep: 29100},
})
```

**Location:** Fixtures defined in same `_test.go` file as tests

### Coverage

**Requirements:** No explicit coverage target enforced

**How to check coverage:**
```bash
go test -cover ./...                         # Show coverage percentage
go test -coverprofile=coverage.out ./...     # Generate coverage file
go tool cover -html=coverage.out             # View HTML report
```

**Observed coverage:** Tests exist only for `isochrone` services; most of the application lacks test coverage (controllers, models, middleware, authentication not tested)

---

## Frontend Testing (Vue 3)

### Test Framework

**Status:** **NOT IMPLEMENTED**

- No test files found (no `.test.js`, `.spec.js` files)
- No test framework installed (no vitest, jest in package.json)
- No test configuration files (no vitest.config.js, jest.config.js)
- No test scripts in package.json (`npm run test` does not exist)

### CI Testing

**Status:** **TESTS NOT RUN IN CI**

**Node.js workflow** (`.github/workflows/node.js.yml`):
- Runs `npm run build` only
- No test execution step
- Builds on Node.js 18.x and 20.x

### Development Workflow

**Build validation:**
```bash
npm run build          # Runs: eslint . --fix && vite build
npm run lint           # Runs: eslint . --fix
npm run format         # Runs: prettier --write .
npm run dev            # Local development with HMR
```

**Linting catches:**
- Import organization (ESLint)
- Unused variables
- `console.log` statements (only `.warn()` and `.error()` allowed)
- Formatting (Prettier)

---

## Test Coverage Assessment

### Backend (Go)

**Tested areas:**
- Transit/isochrone service logic (`app/services/isochrone/`)
  - GTFS calendar parsing and service profiles
  - RAPTOR routing algorithm
  - Isochrone index and network operations

**Major gaps:**
- ❌ HTTP handlers (`app/controllers/`) — auth, component data, AI, etc.
- ❌ Middleware (`app/middleware/`) — auth, rate limiting, sanitization
- ❌ Models (`app/models/`) — database operations, GORM queries
- ❌ Authentication logic
- ❌ Chat and component services
- ❌ External API integrations (Google Vertex AI, etc.)
- ❌ Database migrations
- ❌ Route configuration

**Recommendation:** Add at least basic integration tests for HTTP endpoints using Gin's test utilities or httptest package.

### Frontend (Vue 3)

**Tested areas:**
- ❌ No unit tests
- ❌ No integration tests
- ❌ No E2E tests
- ✅ Linting during build (catches some errors)

**Major gaps:**
- Component rendering and lifecycle
- State management (Pinia stores)
- User interactions (button clicks, form submissions)
- API integration and data fetching
- Route navigation
- Error handling

**Recommendation:** Set up Vitest or Jest as development dependency and add test suites for critical components and stores. Start with high-impact areas:
1. Authentication flows
2. Dashboard data loading and display
3. Map interaction
4. Component configuration changes

---

## Recommended Testing Setup

### Backend improvements

1. **Add `go test` to CI workflow**
   - Update `.github/workflows/go.yml` to run `go test -v ./...`
   - Add coverage reporting: `go test -coverprofile=coverage.out ./...`

2. **Increase test coverage**
   - Prioritize HTTP handlers and middleware (integration layer)
   - Use `httptest` package for testing Gin endpoints
   - Add table-driven tests for complex logic

3. **Example handler test pattern:**
   ```go
   func TestLoginEndpoint(t *testing.T) {
       // Setup router
       router := gin.Default()
       router.POST("/login", Login)
       
       // Create request
       req, _ := http.NewRequest("POST", "/login", nil)
       req.Header.Add("Authorization", "Basic user:pass")
       
       // Record response
       w := httptest.NewRecorder()
       router.ServeHTTP(w, req)
       
       // Assert
       if w.Code != http.StatusOK {
           t.Fatalf("expected 200, got %d", w.Code)
       }
   }
   ```

### Frontend improvements

1. **Install Vitest**
   ```bash
   npm install -D vitest @vitest/ui @vue/test-utils jsdom
   ```

2. **Add test configuration** (`vitest.config.js`):
   ```javascript
   import { defineConfig } from 'vitest/config'
   import vue from '@vitejs/plugin-vue'
   
   export default defineConfig({
       plugins: [vue()],
       test: {
           globals: true,
           environment: 'jsdom',
       },
   })
   ```

3. **Add test scripts to package.json**:
   ```json
   {
       "scripts": {
           "test": "vitest",
           "test:ui": "vitest --ui",
           "test:coverage": "vitest --coverage"
       }
   }
   ```

4. **Start with store tests** (`src/store/dialogStore.test.js`):
   ```javascript
   import { describe, it, expect, beforeEach } from 'vitest'
   import { setActivePinia, createPinia } from 'pinia'
   import { useDialogStore } from './dialogStore'
   
   describe('dialogStore', () => {
       beforeEach(() => {
           setActivePinia(createPinia())
       })
       
       it('shows dialog when requested', () => {
           const store = useDialogStore()
           store.showDialog('login')
           expect(store.dialogs.login).toBe(true)
       })
   })
   ```

---

## Testing Best Practices

### General

- **Run tests locally before committing:** Tests catch regressions early
- **Keep tests focused:** One concern per test function
- **Use descriptive names:** Test name should explain what is tested and expected outcome
- **Avoid test interdependencies:** Each test should be independently runnable
- **Clean up after tests:** Restore state, close connections, etc.

### Go-specific

- Use `t.Run()` for organizing subtests
- Use helper functions with `tb.Helper()` to reduce test boilerplate
- Prefer `errors.Is()` over `==` for error comparisons
- Use `t.TempDir()` for temporary test files

### Vue/Frontend-specific

- Test behavior, not implementation (click button → verify result, not "verify function was called")
- Use component props to inject dependencies (easier to test)
- Mock API calls with interceptors or MSW
- Test async operations with `await` and proper waits
- Use data-testid attributes for reliable element selection

---

*Testing analysis: 2026-10-06*
