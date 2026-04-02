extends GutTest

## Tests unitaires pour SettingsMigrator : migrations auto-decouvertes (timestamps).


# ── Auto-decouverte ──

func test_discover_finds_migrations() -> void:
	var version := SettingsMigrator.get_current_version()
	assert_gt(version, 0, "Au moins une migration doit exister")


func test_current_version_is_timestamp() -> void:
	var version := SettingsMigrator.get_current_version()
	# Un timestamp YYYYMMDDHHMMSS a au moins 14 chiffres
	assert_gt(version, 20200101000000, "La version doit etre un timestamp")


func test_migrations_are_sorted_by_version() -> void:
	var migrations := SettingsMigrator._discover_migrations()
	assert_gt(migrations.size(), 0, "Au moins une migration doit exister")
	for i in range(1, migrations.size()):
		assert_gt(migrations[i].get_version(), migrations[i - 1].get_version(),
			"Les migrations doivent etre triees par version croissante")


func test_migrations_extend_migration_base() -> void:
	var migrations := SettingsMigrator._discover_migrations()
	for m in migrations:
		assert_true(m is MigrationBase, "Chaque migration doit etendre MigrationBase")


func test_migrations_have_descriptions() -> void:
	var migrations := SettingsMigrator._discover_migrations()
	for m in migrations:
		assert_ne(m.get_description(), "", "Chaque migration doit avoir une description")


# ── Execution des migrations ──

func test_migrate_from_zero_applies_all() -> void:
	var data := _make_legacy_data()
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.get_current_version())
	assert_false(result.has("composition/payloads"), "Payloads supprimes")


func test_migrate_fixes_nacelle_lasermount() -> void:
	var data := _make_legacy_data()
	data["composition/nacelles"] = {
		"value": [
			{"id": "nacelle_lasermount", "name": "LaserMount", "compatible_drone_types": [1]},
			{"id": "nacelle_standard", "name": "Standard", "compatible_drone_types": [0, 1]},
		],
		"last_modified": "2026-01-01T00:00:00"
	}
	var result := SettingsMigrator.migrate(data)
	var nacelles: Array = result["composition/nacelles"]["value"]
	var lm: Variant = _find_by_id(nacelles, "nacelle_lasermount")
	assert_eq(lm["compatible_drone_types"], [0], "LaserMount doit passer sur RIFF")
	var std: Variant = _find_by_id(nacelles, "nacelle_standard")
	assert_eq(std["compatible_drone_types"], [0, 1], "Standard ne doit pas changer")


# ── Idempotence ──

func test_migrate_idempotent() -> void:
	var data := _make_legacy_data()
	var result1 := SettingsMigrator.migrate(data.duplicate(true))
	var result2 := SettingsMigrator.migrate(result1.duplicate(true))
	assert_eq(result1["_version"], result2["_version"])
	assert_false(result2.has("composition/payloads"))


func test_migrate_skips_if_current_version() -> void:
	var data := {"_version": SettingsMigrator.get_current_version()}
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.get_current_version())


# ── Donnees vides / manquantes ──

func test_migrate_empty_data() -> void:
	var data := {}
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.get_current_version())


func test_migrate_no_payloads_key() -> void:
	var data := {"_version": 0}
	var result := SettingsMigrator.migrate(data)
	assert_false(result.has("composition/payloads"))


# ── Transition depuis anciens numeros sequentiels ──

func test_migrate_from_old_sequential_version() -> void:
	# Un fichier avec _version: 2 (ancien format) doit relancer toutes les migrations
	var data := {"_version": 2, "composition/payloads": {"value": [{"id": "old"}]}}
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.get_current_version())
	assert_false(result.has("composition/payloads"), "Payloads nettoyes apres transition")


# ── find_referencing_constraints ──

func test_find_refs_with_matching_constraints() -> void:
	var constraints := [
		{"name": "Contrainte Laser", "category": DroneConstraint.ConstraintCategory.PAYLOAD, "value": "payload_laser"},
		{"name": "Contrainte Smoke", "category": DroneConstraint.ConstraintCategory.PAYLOAD, "value": "payload_smoke"},
		{"name": "Contrainte Type", "category": DroneConstraint.ConstraintCategory.DRONE_TYPE, "value": "0"},
	]
	var refs := SettingsMigrator.find_referencing_constraints(
		"payload_laser", DroneConstraint.ConstraintCategory.PAYLOAD, constraints
	)
	assert_eq(refs.size(), 1)
	assert_eq(refs[0], "Contrainte Laser")


func test_find_refs_no_match() -> void:
	var constraints := [
		{"name": "Contrainte Smoke", "category": DroneConstraint.ConstraintCategory.PAYLOAD, "value": "payload_smoke"},
	]
	var refs := SettingsMigrator.find_referencing_constraints(
		"payload_laser", DroneConstraint.ConstraintCategory.PAYLOAD, constraints
	)
	assert_eq(refs.size(), 0)


func test_find_refs_empty_constraints() -> void:
	var refs := SettingsMigrator.find_referencing_constraints(
		"payload_laser", DroneConstraint.ConstraintCategory.PAYLOAD, []
	)
	assert_eq(refs.size(), 0)


func test_find_refs_multiple_matches() -> void:
	var constraints := [
		{"name": "C1", "category": DroneConstraint.ConstraintCategory.PAYLOAD, "value": "payload_laser"},
		{"name": "C2", "category": DroneConstraint.ConstraintCategory.PAYLOAD, "value": "payload_laser"},
	]
	var refs := SettingsMigrator.find_referencing_constraints(
		"payload_laser", DroneConstraint.ConstraintCategory.PAYLOAD, constraints
	)
	assert_eq(refs.size(), 2)


func test_find_refs_nacelle_category() -> void:
	var constraints := [
		{"name": "Nacelle C", "category": DroneConstraint.ConstraintCategory.NACELLE, "value": "nacelle_lasermount"},
	]
	var refs := SettingsMigrator.find_referencing_constraints(
		"nacelle_lasermount", DroneConstraint.ConstraintCategory.NACELLE, constraints
	)
	assert_eq(refs.size(), 1)
	assert_eq(refs[0], "Nacelle C")


# ── Helpers ──

func _make_legacy_data() -> Dictionary:
	return {
		"composition/payloads": {
			"last_modified": "2026-01-01T00:00:00",
			"value": [
				{"id": "payload_laser", "name": "Laser", "compatible_drone_types": [1], "compatible_nacelle_ids": []},
				{"id": "payload_smoke", "name": "Smoke", "compatible_drone_types": [], "compatible_nacelle_ids": []},
			]
		}
	}


func _find_by_id(items: Array, id: String) -> Variant:
	for item in items:
		if item is Dictionary and str(item.get("id", "")) == id:
			return item
	return null
