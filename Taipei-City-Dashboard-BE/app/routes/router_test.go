package routes

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	"TaipeiCityDashboardBE/app/models/modelstest"
	"TaipeiCityDashboardBE/global"

	"github.com/gin-gonic/gin"
)

// identity stands in for ValidateJWT. accountID 0 means anonymous.
func identity(accountID int, isAdmin bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if accountID == 0 {
			c.Set("loginType", "no login")
		} else {
			c.Set("loginType", "Email")
		}
		c.Set("accountID", accountID)
		c.Set("isAdmin", isAdmin)
		c.Next()
	}
}

// newTestGroup builds an engine without rate limiters (they need Redis);
// Recovery turns a handler that reaches the nil database into a 500, not a crash.
func newTestGroup(accountID int, isAdmin bool, prefix string) (*gin.Engine, *gin.RouterGroup) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(gin.Recovery(), identity(accountID, isAdmin))
	return r, r.Group(prefix)
}

func do(r *gin.Engine, method, path, body string) int {
	w := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	return w.Code
}

// Ticket 01: a logged-in user must not read, create or delete another user's viewpoints.
func TestViewPointRoutesRejectOtherUser(t *testing.T) {
	r, g := newTestGroup(3, false, "/api/v1/user")
	registerViewPointRoutes(g)

	cases := []struct{ method, path, body string }{
		{http.MethodGet, "/api/v1/user/2/viewpoint", ""},
		{http.MethodPost, "/api/v1/user/2/viewpoint", `{"name":"x"}`},
		{http.MethodDelete, "/api/v1/user/2/viewpoint/1", ""},
	}
	for _, tc := range cases {
		if got := do(r, tc.method, tc.path, tc.body); got != http.StatusForbidden {
			t.Errorf("%s %s as user 3: got %d, want 403", tc.method, tc.path, got)
		}
	}
}

func TestViewPointRoutesAllowOwnID(t *testing.T) {
	modelstest.UseDryRunDB(t)
	r, g := newTestGroup(3, false, "/api/v1/user")
	registerViewPointRoutes(g)

	if got := do(r, http.MethodGet, "/api/v1/user/3/viewpoint", ""); got != http.StatusOK {
		t.Fatalf("GET own viewpoints as user 3: got %d, want 200", got)
	}
}

func TestViewPointRoutesRejectAnonymous(t *testing.T) {
	r, g := newTestGroup(0, false, "/api/v1/user")
	registerViewPointRoutes(g)

	if got := do(r, http.MethodGet, "/api/v1/user/0/viewpoint", ""); got != http.StatusForbidden {
		t.Fatalf("anonymous GET /user/0/viewpoint: got %d, want 403", got)
	}
}

// fakeAirflow replaces the real Airflow; it only counts calls.
func fakeAirflow(t *testing.T) *int32 {
	t.Helper()
	var calls int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		atomic.AddInt32(&calls, 1)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"dag_run_id":"fake","state":"queued"}`))
	}))
	t.Cleanup(srv.Close)
	old := global.Airflow
	global.Airflow.BaseURL = srv.URL
	t.Cleanup(func() { global.Airflow = old })
	return &calls
}

// Ticket 03: only system admins may trigger the AI summary DAG or read its run status.
func TestAISummaryAdminRoutesRejectNonAdmins(t *testing.T) {
	who := []struct {
		name      string
		accountID int
	}{{"anonymous", 0}, {"non-admin", 3}}
	for _, u := range who {
		calls := fakeAirflow(t)
		r, g := newTestGroup(u.accountID, false, "/api/v1/component")
		registerAISummaryRoutes(g)

		if got := do(r, http.MethodPost, "/api/v1/component/ai-summary/trigger", `{"index":"qa","type":"chart"}`); got != http.StatusForbidden {
			t.Errorf("%s POST trigger: got %d, want 403", u.name, got)
		}
		if got := do(r, http.MethodGet, "/api/v1/component/ai-summary/status/fake", ""); got != http.StatusForbidden {
			t.Errorf("%s GET status: got %d, want 403", u.name, got)
		}
		if n := atomic.LoadInt32(calls); n != 0 {
			t.Errorf("%s: Airflow was called %d times, want 0", u.name, n)
		}
	}
}

func TestAISummaryAdminRoutesAllowAdmin(t *testing.T) {
	calls := fakeAirflow(t)
	r, g := newTestGroup(2, true, "/api/v1/component")
	registerAISummaryRoutes(g)

	if got := do(r, http.MethodPost, "/api/v1/component/ai-summary/trigger", `{"index":"qa","type":"chart"}`); got != http.StatusOK {
		t.Errorf("admin POST trigger: got %d, want 200 from fake Airflow", got)
	}
	if got := do(r, http.MethodGet, "/api/v1/component/ai-summary/status/fake", ""); got != http.StatusOK {
		t.Errorf("admin GET status: got %d, want 200 from fake Airflow", got)
	}
	if n := atomic.LoadInt32(calls); n != 2 {
		t.Errorf("Airflow calls: got %d, want 2", n)
	}
}
