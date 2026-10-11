// Package modelstest holds test helpers for code that uses models.DBManager.
// Only _test.go files import it, so it never ships in the server binary.
package modelstest

import (
	"testing"

	"TaipeiCityDashboardBE/app/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// UseDryRunDB points models.DBManager at a gorm DryRun session for one test.
// Statements are built but never sent, so no database is needed; every write
// reports 0 rows affected and every read returns nothing.
func UseDryRunDB(t testing.TB) {
	t.Helper()
	db, err := gorm.Open(postgres.New(postgres.Config{DSN: "host=127.0.0.1 port=1 dbname=dryrun sslmode=disable"}),
		// SkipDefaultTransaction: a write would otherwise BEGIN, which needs a real connection.
		&gorm.Config{DryRun: true, DisableAutomaticPing: true, SkipDefaultTransaction: true})
	if err != nil {
		t.Fatalf("open dry-run db: %v", err)
	}
	old := models.DBManager
	models.DBManager = db
	t.Cleanup(func() { models.DBManager = old })
}
