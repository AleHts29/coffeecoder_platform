// Package db expone las migraciones embebidas en el binario, así el
// deploy no depende de psql ni de tener el repo al lado.
package db

import "embed"

//go:embed migrations/*.sql
var Migrations embed.FS
