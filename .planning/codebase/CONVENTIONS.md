# Coding Conventions

**Analysis Date:** 2026-10-06

## Overview

This codebase is split into three main components:
- **Backend (GO)**: `Taipei-City-Dashboard-BE/` - REST API and business logic
- **Frontend (Vue 3)**: `Taipei-City-Dashboard-FE/` - User interface
- **Data Engineering**: `Taipei-City-Dashboard-DE/` - Data pipeline management

This document covers the backend and frontend separately.

---

## Backend (Go)

### Naming Patterns

**Files:**
- Lowercase, descriptive names with no underscores
- Controllers: `auth.go`, `componentData.go`, `dashboard.go`
- Models: `user.go`, `chatlog.go`, `auth.go`
- Utilities: `common.go`, `user.go`, `auth.go`
- Test files: `*_test.go` (e.g., `calendar_test.go`, `builder_test.go`)

**Packages:**
- Lowercase, single-word package names
- Examples: `models`, `controllers`, `middleware`, `cache`, `util`, `services`
- Larger packages nested under parent: `services/isochrone/`, `services/ai/`

**Functions:**
- Exported functions: PascalCase (e.g., `GenerateRandomString`, `GetUserByID`, `CreateUser`)
- Unexported helper functions: camelCase (e.g., `getFileLine`)
- Handler functions: Descriptive PascalCase (e.g., `Login`, `ValidateJWT`)

**Constants:**
- UPPERCASE for package-level constants (e.g., `emailRegex`)
- camelCase for local constants (e.g., `authPrefix`)

**Variables:**
- camelCase for all variable names
- Examples: `passwordSHA`, `permissions`, `curTimeout`, `timeToUpdate`
- Receiver names: Single letter (e.g., `func (c *gin.Context)`)

**Struct fields:**
- PascalCase (exported) with struct tags for JSON and database mapping
- Example: `ID`, `Name`, `Email` with tags like `json:"user_id" gorm:"column:id"`
- Database columns: snake_case (defined in gorm tag: `gorm:"column:id"`)

### Code Style

**Formatting:**
- No explicit linter configuration file found (`golangci.yml` absent)
- Follows standard Go conventions (implicitly via IDE/gofmt)
- Line length: No hard limit observed
- Indentation: Tabs (standard Go)

**Imports:**
- Organized in groups separated by blank lines:
  1. Standard library imports (`fmt`, `time`, `errors`, etc.)
  2. Blank line
  3. Third-party imports (`github.com`, `gorm.io`, etc.)
  4. Blank line
  5. Local package imports (`TaipeiCityDashboardBE/app/...`)
- Example from `auth.go` (`Taipei-City-Dashboard-BE/app/controllers/auth.go`):
  ```go
  import (
      "errors"
      "fmt"
      "net/http"
      "regexp"
      "time"

      "TaipeiCityDashboardBE/app/models"
      "TaipeiCityDashboardBE/app/util"
      "TaipeiCityDashboardBE/global"

      "github.com/dgrijalva/jwt-go"
      "github.com/gin-gonic/gin"
      "gorm.io/gorm"
  )
  ```

**Comments:**
- Package-level comments: Block comment at top of file describing the package purpose
- Example from `common.go` (`Taipei-City-Dashboard-BE/app/util/common.go`):
  ```go
  // Package util stores the utility functions for the application (functions that only handle internal logic)
  /*
  Developed By Taipei Urban Intelligence Center 2023-2024
  
  // Lead Developer:  Igor Ho (Full Stack Engineer)
  // Systems & Auth: Ann Shih (Systems Engineer)
  ...
  */
  package util
  ```
- Function comments: Descriptive comment immediately before function definition
  - Example: `// GenerateRandomString generates a random alphanumeric string of a specified length.`
- Inline comments: Used sparingly for complex logic or requirements
- TODO/FIXME: Not found in codebase (good practice to add when needed)

### Error Handling

**Strategy:** Explicit error checking on every function call that can error

**Patterns:**

1. **Return errors immediately:**
   ```go
   err := tempDB.Count(&totalUsers).Error
   if err != nil {
       return users, 0, 0, err
   }
   ```

2. **Check for specific errors (e.g., database not found):**
   ```go
   if errors.Is(err, gorm.ErrRecordNotFound) {
       c.JSON(http.StatusUnauthorized, gin.H{"error": "Incorrect username or password"})
       return
   } else {
       logs.FError("Login failed: unexpected database error: %v", err)
       c.JSON(http.StatusUnauthorized, gin.H{"error": "unexpected database error"})
       return
   }
   ```

3. **HTTP responses on error:**
   - Always return appropriate HTTP status codes (401, 403, 500, etc.)
   - Return JSON with error field: `gin.H{"error": "message"}`
   - Example from `auth.go`:
     ```go
     c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
     c.Abort()
     return
     ```

4. **Logging errors:**
   - Use custom logs package: `logs.FError()` for error-level logging
   - Example: `logs.FError("Login failed: unexpected database error: %v", err)`

### Logging

**Framework:** Custom logging package at `Taipei-City-Dashboard-BE/logs/logs.go`

**Available functions:**
- `Trace(v ...interface{})` - Trace level (lowest)
- `Debug(v ...interface{})` - Debug level
- `Info(v ...interface{})` - Info level
- `Warn(v ...interface{})` - Warning level
- `Error(v ...interface{})` - Error level
- `FError(format, v ...interface{})` - Formatted error

**Output format:**
- Includes timestamp and file line info
- Prefixed with level indicator: "t:", "d:", "i:", "w:", "e:"
- Example: `i: 14:35:42 /path/to/file.go:123 message`

**Best practices:**
- Use `FError()` for formatted error messages (most common pattern in code)
- Log at appropriate level: debug for internal logic, warn for unusual conditions, error for failures

### Database Conventions

**Framework:** GORM with PostgreSQL driver

**Struct tags:**
- JSON serialization: `json:"field_name"`
- Database mapping: `gorm:"column:db_column_name;type:..."`
- Validation constraints: embedded in gorm tag
- Example from `user.go` (`Taipei-City-Dashboard-BE/app/models/user.go`):
  ```go
  ID            int        `json:"user_id" gorm:"column:id;autoincrement;primaryKey"`
  Email         *string    `json:"account" gorm:"column:email;type:varchar;unique;check:(...regex...)"`
  IsAdmin       *bool      `json:"is_admin" gorm:"column:is_admin;type:boolean;default:false"`
  CreatedAt     time.Time  `json:"created_at" gorm:"column:created_at;type:timestamp with time zone;"`
  ```

**Database interaction patterns:**
- Query builder chaining: `tempDB.Where().Order().Limit().Offset().Find()`
- Error checking: Always check `.Error` field after query
- Null handling: Use pointers (`*string`, `*bool`) for nullable fields

### Web Framework (Gin)

**Pattern:** Gin web framework for HTTP handlers

**Handler signature:**
```go
func HandlerName(c *gin.Context) {
    // ...
}
```

**Request handling:**
- Query parameters: `c.Query("paramName")`
- URL parameters: `c.Param("paramName")`
- JSON body: `c.BindJSON(&structure)`
- Auth header: `c.GetHeader("Authorization")`

**Response pattern:**
```go
c.JSON(http.StatusOK, gin.H{
    "key": value,
    "error": nil,
})
c.Abort() // if aborting request
```

**Middleware pattern:**
- Receive context, process, call `c.Next()` to continue, or `c.Abort()` to stop
- Set values: `c.Set("key", value)`
- Get values: `value, exists := c.Get("key")`

---

## Frontend (Vue 3)

### Naming Patterns

**Files:**
- Component files: PascalCase (e.g., `MetroChart.vue`, `NavBar.vue`, `DashboardView.vue`)
- Script files: camelCase (e.g., `authStore.js`, `mapStore.js`, `dialogStore.js`)
- Service/utility files: camelCase (e.g., `taipeiMetroLines.js`)

**Components:**
- PascalCase names (e.g., `MetroChart`, `TagTooltip`, `MetroCarDensity`)
- Import at top of `<script setup>`
- Template usage: PascalCase (e.g., `<MetroChart />`)

**Stores (Pinia):**
- Export names: `use{StoreName}Store` (e.g., `useAuthStore`, `useDialogStore`, `useMapStore`)
- File names: camelCase with "Store" suffix (e.g., `authStore.js`)
- State properties: camelCase (e.g., `currentPath`, `currentVisibleLayers`)

**Functions:**
- camelCase for all functions (e.g., `reloadChartData`, `updateTimeToUpdate`, `reloadMapData`)
- Handler functions: `handle{Action}` or verb-based (e.g., `handleClick`, `reloadData`)

**Variables and refs:**
- camelCase for all (e.g., `timeToUpdate`, `isChatBtnShow`, `isMappedToUpdateBoards`)
- Boolean refs: `is{Something}` or `has{Something}` pattern (e.g., `isCrowdingUpdating`, `isActive`)

**Computed properties:**
- camelCase (e.g., `updateBoardsMap`, `formattedTimeToUpdate`, `parsedSeries`)

### Code Style

**Formatting:**
- Tool: Prettier (configured in `.prettierrc`)
- Indentation: **Tabs** (4 spaces visual width)
- Semicolons: Yes (enabled)
- Quotes: Double quotes (single quotes disabled)
- Line length: Not enforced by config

**Prettier configuration** (`.planning/codebase/../Taipei-City-Dashboard-FE/.prettierrc`):
```json
{
    "semi": true,
    "singleQuote": false,
    "tabWidth": 4,
    "useTabs": true
}
```

**Linting:**
- Tool: ESLint with flat config (`eslint.config.js`)
- Vue plugin: `eslint-plugin-vue`
- Build command includes auto-fix: `npm run build` runs `eslint . --fix` before vite build

**ESLint rules** (`Taipei-City-Dashboard-FE/eslint.config.js`):
- Indentation: Tab
- Quotes: No enforcement (disabled)
- Semicolons: No enforcement (disabled)
- Comments: Spaced comments not enforced
- Console: Only `console.warn()` and `console.error()` allowed (errors during build if using `console.log`)
- Import organization: No specific order enforced
- Destructuring: Prefer object destructuring (error if not used)
- Unused variables: Error, but ignores: `req`, `res`, `next`, `val`, `err`
- Vue-specific: Several rules relaxed (no setup props destructure, no prop name casing, no default props required)

**Script setup syntax:**
- Always use `<script setup>` (modern Vue 3 default)
- Imports at top of script
- Reactive state: `ref()` for primitives, `reactive()` for objects
- Computed: `computed(() => {...})`
- Props: `defineProps(["prop1", "prop2"])`
- Emits: `defineEmits(["event1"])` (commented out when not used)

### Import Organization

**Order:**
1. Vue composition API imports
2. Blank line
3. Vue Router imports (if applicable)
4. Store imports
5. Blank line
6. Component imports (local)
7. Utility/constant imports

**Example from `App.vue` (`Taipei-City-Dashboard-FE/src/App.vue`):
```javascript
import {
    onBeforeMount,
    onMounted,
    onBeforeUnmount,
    ref,
    computed,
    watch,
} from "vue";
import { useRoute } from "vue-router";
import { useAuthStore } from "./store/authStore";
import { useDialogStore } from "./store/dialogStore";
import { useContentStore } from "./store/contentStore";
import { useMapStore } from "./store/mapStore";

import NavBar from "./components/utilities/bars/NavBar.vue";
import SideBar from "./components/utilities/bars/SideBar.vue";
// ... more component imports
```

### State Management (Pinia)

**Store pattern:**
```javascript
export const useStoreNameStore = defineStore("storeName", {
    state: () => ({
        // state properties
    }),
    getters: {
        // computed properties
    },
    actions: {
        // methods
    },
});
```

**State naming:**
- All state properties in camelCase
- Booleans: `is{Something}` or `has{Something}` prefix
- Collections: camelCase plural (e.g., `dialogs`, `permissions`)

**Example from `dialogStore.js` (`Taipei-City-Dashboard-FE/src/store/dialogStore.js`):
```javascript
export const useDialogStore = defineStore("dialog", {
    state: () => ({
        dialogs: {
            adminComponentSettings: false,
            adminAddEditDashboards: false,
            // ...
        },
        notification: {
            status: "",
            message: "",
        },
        addEdit: "",
        curTimeout: null,
    }),
    actions: {
        showDialog(dialog) {
            this.dialogs[dialog] = true;
        },
        hideAllDialogs() {
            // ...
        },
    },
});
```

### Comments

**Header comments:**
- Files often start with: `<!-- Developed by Taipei Urban Intelligence Center 2023-2024 -->`
- Team credits included in many files

**JSDoc/TSDoc:** Not observed in codebase

**Component-level documentation:** Comments in state definition explain purpose
- Example from `dialogStore.js`: 
  ```javascript
  /*
  The dialogStore stores all states related to the popups and dialogs in the application.
  To add a new dialog to the existing list, simply give the dialog a name...
  */
  ```

**Inline comments:** Used for complex conditional logic or non-obvious behavior

### Error Handling

**Pattern:** Try-catch for async operations when needed

**Example from `App.vue`:
```javascript
isCrowdingUpdating = true;
try {
    await contentStore.updateCurrentDashboardCertainChartData();
} finally {
    isCrowdingUpdating = false;
}
```

**HTTP errors:** Handled through store methods (typically in backend calls)

**Validation:** Props validation via `defineProps` with type hints when applicable

---

## Where to Add New Code

### Backend (Go)

**New feature/API endpoint:**
1. Create handler in `Taipei-City-Dashboard-BE/app/controllers/{feature}.go`
2. Add route in `Taipei-City-Dashboard-BE/app/routes/` files
3. Add model/database logic in `Taipei-City-Dashboard-BE/app/models/` if needed
4. Add business logic in `Taipei-City-Dashboard-BE/app/services/` if needed
5. Create tests in `{feature}_test.go` in same directory as implementation

**New utility function:**
- Add to appropriate file in `Taipei-City-Dashboard-BE/app/util/` (or create new file if category-specific)
- Always add function comment describing what it does

**New middleware:**
- Add to `Taipei-City-Dashboard-BE/app/middleware/` directory
- File name: descriptive lowercase (e.g., `rateLimit.go`)

### Frontend (Vue 3)

**New page/view:**
1. Create component in `Taipei-City-Dashboard-FE/src/views/{ViewName}View.vue`
2. Add route in router configuration
3. Use stores for state management

**New reusable component:**
- Location: `Taipei-City-Dashboard-FE/src/components/{Category}/{ComponentName}.vue`
- Use PascalCase filename
- Export as default
- Accept props for configuration

**New store:**
- Create `Taipei-City-Dashboard-FE/src/store/{featureStore}.js`
- Follow Pinia defineStore pattern
- Name: `use{Feature}Store`

**New utility/helper:**
- Create in `Taipei-City-Dashboard-FE/src/utils/` or `Taipei-City-Dashboard-FE/src/services/`
- Use camelCase filename

---

*Convention analysis: 2026-10-06*
