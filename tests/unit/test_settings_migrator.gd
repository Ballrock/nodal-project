extends GutTest

## Tests unitaires pour SettingsMigrator : migrations et verification d'integrite.


# ── Migration v0 → v1 ──

func test_migrate_v0_adds_superlight() -> void:
	var data := _make_v0_data()
	var result := SettingsMigrator.migrate(data)
	var payloads: Array = result["composition/payloads"]["value"]
	var ids := _extract_ids(payloads)
	assert_true(ids.has("payload_superlight"), "SuperLight doit etre ajoute par la migration")


func test_migrate_v0_fixes_laser_drone_types() -> void:
	var data := _make_v0_data()
	var result := SettingsMigrator.migrate(data)
	var payloads: Array = result["composition/payloads"]["value"]
	var laser: Variant = _find_by_id(payloads, "payload_laser")
	assert_not_null(laser)
	assert_eq(laser["compatible_drone_types"], [0], "Laser doit etre sur RIFF (type 0)")


func test_migrate_v0_fixes_laser_nacelle_ids() -> void:
	var data := _make_v0_data()
	var result := SettingsMigrator.migrate(data)
	var payloads: Array = result["composition/payloads"]["value"]
	var laser: Variant = _find_by_id(payloads, "payload_laser")
	assert_not_null(laser)
	assert_eq(laser["compatible_nacelle_ids"], ["nacelle_lasermount"])


func test_migrate_v0_preserves_user_payloads() -> void:
	var data := _make_v0_data()
	# Ajouter un payload custom
	data["composition/payloads"]["value"].append(
		{"id": "payload_custom", "name": "MonPayload", "compatible_drone_types": [1], "compatible_nacelle_ids": []}
	)
	var result := SettingsMigrator.migrate(data)
	var payloads: Array = result["composition/payloads"]["value"]
	var custom: Variant = _find_by_id(payloads, "payload_custom")
	assert_not_null(custom, "Le payload custom doit etre preserve")
	assert_eq(custom["compatible_drone_types"], [1], "Les valeurs custom ne doivent pas etre modifiees")


func test_migrate_v0_fixes_nacelle_lasermount() -> void:
	var data := _make_v0_data()
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


func test_migrate_sets_version() -> void:
	var data := _make_v0_data()
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.CURRENT_VERSION)


# ── Idempotence ──

func test_migrate_idempotent() -> void:
	var data := _make_v0_data()
	var result1 := SettingsMigrator.migrate(data.duplicate(true))
	var result2 := SettingsMigrator.migrate(result1.duplicate(true))
	var payloads1: Array = result1["composition/payloads"]["value"]
	var payloads2: Array = result2["composition/payloads"]["value"]
	assert_eq(payloads1.size(), payloads2.size(), "La migration ne doit pas dupliquer les payloads")
	var ids2 := _extract_ids(payloads2)
	# Pas de doublon
	var unique_ids := {}
	for id in ids2:
		assert_false(unique_ids.has(id), "ID duplique detecte : %s" % id)
		unique_ids[id] = true


func test_migrate_skips_if_current_version() -> void:
	var data := {"_version": SettingsMigrator.CURRENT_VERSION}
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.CURRENT_VERSION)
	assert_false(result.has("composition/payloads"), "Pas de modification si deja a jour")


# ── Donnees vides / manquantes ──

func test_migrate_empty_data() -> void:
	var data := {}
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.CURRENT_VERSION)
	# La migration doit ajouter les payloads par defaut
	var payloads: Array = result["composition/payloads"]["value"]
	assert_true(payloads.size() > 0, "Les defaults doivent etre crees")


func test_migrate_missing_payloads_key() -> void:
	var data := {"_version": 0}
	var result := SettingsMigrator.migrate(data)
	var payloads: Array = result["composition/payloads"]["value"]
	var ids := _extract_ids(payloads)
	assert_true(ids.has("payload_laser"))
	assert_true(ids.has("payload_superlight"))


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

func _make_v0_data() -> Dictionary:
	return {
		"composition/payloads": {
			"last_modified": "2026-01-01T00:00:00",
			"value": [
				{"id": "payload_laser", "name": "Laser", "compatible_drone_types": [1], "compatible_nacelle_ids": []},
				{"id": "payload_smoke", "name": "Smoke", "compatible_drone_types": [], "compatible_nacelle_ids": []},
				{"id": "payload_strobe", "name": "Strobe", "compatible_drone_types": [], "compatible_nacelle_ids": []},
			]
		}
	}


func _extract_ids(items: Array) -> Array:
	var ids := []
	for item in items:
		if item is Dictionary:
			ids.append(str(item.get("id", "")))
	return ids


func _find_by_id(items: Array, id: String) -> Variant:
	for item in items:
		if item is Dictionary and str(item.get("id", "")) == id:
			return item
	return null
