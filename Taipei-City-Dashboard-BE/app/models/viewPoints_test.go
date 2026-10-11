package models_test

import (
	"errors"
	"testing"

	"TaipeiCityDashboardBE/app/models"
	"TaipeiCityDashboardBE/app/models/modelstest"

	"gorm.io/gorm"
)

// Ticket 01 defense in depth: a delete that matches no (id, user_id) row must
// not report success, so a viewpoint owned by someone else is never "deleted".
func TestDeleteViewPointReportsNotFoundWhenNoRowMatches(t *testing.T) {
	modelstest.UseDryRunDB(t)

	err := models.DeleteViewPoint(3, 99)
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("DeleteViewPoint with no matching row: got %v, want gorm.ErrRecordNotFound", err)
	}
}
