package controllers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"TaipeiCityDashboardBE/app/models/modelstest"

	"github.com/gin-gonic/gin"
)

func TestDeleteViewPointReturns404WhenNothingDeleted(t *testing.T) {
	modelstest.UseDryRunDB(t)
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.DELETE("/user/:id/viewpoint/:viewpointid", DeleteViewPoint)

	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodDelete, "/user/3/viewpoint/99", nil))
	if w.Code != http.StatusNotFound {
		t.Fatalf("delete of a viewpoint the user does not own: got %d, want 404", w.Code)
	}
}
