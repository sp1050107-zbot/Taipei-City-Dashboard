package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

// fakeLogin stands in for ValidateJWT: it puts a logged-in identity into the context.
func fakeLogin(accountID int, isAdmin bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("loginType", "Email")
		c.Set("accountID", accountID)
		c.Set("isAdmin", isAdmin)
		c.Next()
	}
}

func serveIsSelf(t *testing.T, accountID int, isAdmin bool, path string) int {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/user/:id/viewpoint", fakeLogin(accountID, isAdmin), IsSelf("id"), func(c *gin.Context) {
		c.Status(http.StatusOK)
	})
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
	return w.Code
}

func TestIsSelfRejectsOtherUser(t *testing.T) {
	if got := serveIsSelf(t, 3, false, "/user/2/viewpoint"); got != http.StatusForbidden {
		t.Fatalf("user 3 on /user/2: got %d, want 403", got)
	}
}

func TestIsSelfAllowsOwnID(t *testing.T) {
	if got := serveIsSelf(t, 3, false, "/user/3/viewpoint"); got != http.StatusOK {
		t.Fatalf("user 3 on /user/3: got %d, want 200", got)
	}
}

func TestIsSelfRejectsAdminOnOtherUser(t *testing.T) {
	if got := serveIsSelf(t, 2, true, "/user/3/viewpoint"); got != http.StatusForbidden {
		t.Fatalf("admin 2 on /user/3: got %d, want 403 (self-only, no admin bypass)", got)
	}
}

func TestIsSelfRejectsNonNumericID(t *testing.T) {
	if got := serveIsSelf(t, 3, false, "/user/abc/viewpoint"); got != http.StatusForbidden {
		t.Fatalf("user 3 on /user/abc: got %d, want 403", got)
	}
}
