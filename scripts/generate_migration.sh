#!/usr/bin/env bash
# Genere une nouvelle migration dans core/settings/migrations/
# Usage: ./scripts/generate_migration.sh "description courte"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MIGRATIONS_DIR="$PROJECT_DIR/core/settings/migrations"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
FILE="$MIGRATIONS_DIR/migration_${TIMESTAMP}.gd"
DESC="${1:-TODO description}"

cat > "$FILE" << EOF
# res://core/settings/migrations/migration_${TIMESTAMP}.gd
extends MigrationBase

## Migration ${TIMESTAMP} : ${DESC}


func get_version() -> int:
	return ${TIMESTAMP}


func get_description() -> String:
	return "${DESC}"


func up(data: Dictionary) -> Dictionary:
	# TODO: implementer la migration
	return data
EOF

echo "Migration creee : $FILE"
