package store

import (
	"os"
	"strings"
	"testing"
)

// openDialectTestStore is storetest.Open for this package's own tests, which
// cannot import storetest (it imports store). nil means "use SQLite".
func openDialectTestStore(t *testing.T) *Store {
	t.Helper()
	driver := strings.ToLower(os.Getenv("ARENA_STORE_TEST_DRIVER"))
	dsn := os.Getenv("ARENA_STORE_TEST_DSN")
	if driver == "" || driver == "sqlite" || dsn == "" {
		return nil
	}
	s, cleanup, err := OpenScratch(driver, dsn)
	if err != nil {
		t.Fatalf("OpenScratch(%s): %v", driver, err)
	}
	t.Cleanup(cleanup)
	return s
}

// TestDialectStoreIsTheConfiguredOne makes a mis-set variable visible instead
// of a silent SQLite run that "passes on postgres".
func TestDialectStoreIsTheConfiguredOne(t *testing.T) {
	driver := strings.ToLower(os.Getenv("ARENA_STORE_TEST_DRIVER"))
	if driver == "" || driver == "sqlite" {
		t.Skip("no dialect configured; the suite runs on SQLite")
	}
	got := newTestStore(t).DB().Dialector.Name()
	want := map[string]string{"postgresql": "postgres", "mariadb": "mysql"}[driver]
	if want == "" {
		want = driver
	}
	if got != want {
		t.Fatalf("store dialect = %q, want %q", got, want)
	}
	t.Logf("store tests running on %s", got)
}
