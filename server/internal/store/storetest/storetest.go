// Package storetest opens the store the test suites use: SQLite at the path
// the test chose, or, when ARENA_STORE_TEST_DRIVER and ARENA_STORE_TEST_DSN are
// set, a scratch schema on that Postgres or MySQL/MariaDB server (S08):
//
//	ARENA_STORE_TEST_DRIVER=postgres
//	ARENA_STORE_TEST_DSN="host=127.0.0.1 port=55432 user=arena password=arena dbname=arena sslmode=disable"
//
//	ARENA_STORE_TEST_DRIVER=mysql
//	ARENA_STORE_TEST_DSN="root:arena@tcp(127.0.0.1:53306)/"
//
// Unset, nothing changes: every test stays on its own SQLite file.
package storetest

import (
	"os"
	"strings"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/store"
)

// Dialect returns the configured driver, or "" for SQLite.
func Dialect() (driver, dsn string) {
	driver = strings.ToLower(os.Getenv("ARENA_STORE_TEST_DRIVER"))
	dsn = os.Getenv("ARENA_STORE_TEST_DSN")
	if driver == "sqlite" || dsn == "" {
		return "", ""
	}
	return driver, dsn
}

// Open is store.Open(sqlitePath) unless a dialect is configured, in which case
// it opens a scratch schema there and drops it when the test ends. The path is
// ignored then, so a test must not rely on reopening the same file.
func Open(t testing.TB, sqlitePath string) (*store.Store, error) {
	t.Helper()
	driver, dsn := Dialect()
	if driver == "" {
		return store.Open(sqlitePath)
	}
	s, cleanup, err := store.OpenScratch(driver, dsn)
	if err != nil {
		return nil, err
	}
	t.Cleanup(cleanup)
	return s, nil
}
