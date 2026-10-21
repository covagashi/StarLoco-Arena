package store

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"

	"gorm.io/driver/mysql"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// OpenScratch creates an empty, uniquely named schema (postgres) or database
// (mysql/mariadb) on the server dsn points at, opens a migrated Store on it and
// returns a cleanup that closes it and drops what it created. It exists so the
// test suites can run on the production dialects and not only on SQLite (S08);
// see storetest.Open.
func OpenScratch(driver, dsn string) (*Store, func(), error) {
	var buf [6]byte
	_, _ = rand.Read(buf[:])
	name := "t_" + hex.EncodeToString(buf[:])

	var admin gorm.Dialector
	var scratchDSN, create, drop string
	switch strings.ToLower(driver) {
	case "postgres", "postgresql":
		admin = postgres.Open(dsn)
		scratchDSN = dsn + " search_path=" + name
		create, drop = "CREATE SCHEMA "+name, "DROP SCHEMA "+name+" CASCADE"
	case "mysql", "mariadb":
		admin = mysql.Open(dsn)
		base, query, _ := strings.Cut(dsn, "?")
		if query == "" {
			query = "parseTime=true"
		}
		scratchDSN = strings.TrimSuffix(base, "/") + "/" + name + "?" + query
		create, drop = "CREATE DATABASE "+name, "DROP DATABASE "+name
	default:
		return nil, nil, fmt.Errorf("store: OpenScratch: driver %q is not postgres or mysql", driver)
	}
	adb, err := gorm.Open(admin, &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		return nil, nil, fmt.Errorf("store: OpenScratch connect (%s): %w", driver, err)
	}
	closeAdmin := func() {
		if sqlDB, err := adb.DB(); err == nil {
			_ = sqlDB.Close()
		}
	}
	if err := adb.Exec(create).Error; err != nil {
		closeAdmin()
		return nil, nil, fmt.Errorf("store: %s: %w", create, err)
	}
	s, err := OpenConfig(Config{Driver: driver, DSN: scratchDSN, MaxOpenConns: 4, MaxIdleConns: 1})
	if err != nil {
		_ = adb.Exec(drop).Error
		closeAdmin()
		return nil, nil, err
	}
	return s, func() {
		_ = s.Close()
		_ = adb.Exec(drop).Error
		closeAdmin()
	}, nil
}
