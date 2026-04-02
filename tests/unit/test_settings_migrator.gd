extends GutTest

## Tests unitaires pour SettingsMigrator : migrations et verification d'integrite.


# ── Migration v0 → v1 ──

func test_migrate_v0_erases_old_payloads() -> void:
	var data := _make_v0_data()
	var result := SettingsMigrator.migrate(data)
	assert_false(result.has("composition/payloads"), "Les anciennes donnees payloads doivent etre supprimees")


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
	assert_eq(result1["_version"], result2["_version"])
	assert_false(result2.has("composition/payloads"), "Les payloads ne doivent pas reapparaitre")


func test_migrate_skips_if_current_version() -> void:
	var data := {"_version": SettingsMigrator.CURRENT_VERSION}
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.CURRENT_VERSION)


# ── Donnees vides / manquantes ──

func test_migrate_empty_data() -> void:
	var data := {}
	var result := SettingsMigrator.migrate(data)
	assert_eq(result["_version"], SettingsMigrator.CURRENT_VERSION)


func test_migrate_missing_payloads_key() -> void:
	var data := {"_version": 0}
	var result := SettingsMigrator.migrate(data)
	assert_false(result.has("composition/payloads"), "Pas de cle payloads si absente au depart")


# ── Migration v1 → v2 ──

func test_migrate_v1_erases_old_payloads() -> void:
	var data := _make_v1_data()
	var result := SettingsMigrator.migrate(data)
	assert_false(result.has("composition/payloads"), "Les payloads locaux v1 doivent etre supprimes")
	assert_eq(result["_version"], 2)


func test_migrate_v1_without_payloads() -> void:
	var data := {"_version": 1}
	var result := SettingsMigrator.migrate(data)
	assert_false(result.has("composition/payloads"))
	assert_eq(result["_version"], 2)


func test_migrate_v0_to_v2_full_chain() -> void:
	var data := _make_v0_data()
	var result := SettingsMigrator.migrate(data)
	assert_false(result.has("composition/payloads"), "Payloads supprimes apres chaine v0->v1->v2")
	assert_eq(result["_version"], 2)


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

func _make_v1_data() -> Dictionary:
	return {
		"_version": 1,
		"composition/payloads": {
			"last_modified": "2026-03-01T00:00:00",
			"value": [
				{"id": "payload_laser", "name": "Laser", "compatible_drone_types": [0], "compatible_nacelle_ids": ["nacelle_lasermount"]},
				{"id": "payload_smoke", "name": "Smoke", "compatible_drone_types": [], "compatible_nacelle_ids": []},
				{"id": "payload_strobe", "name": "Strobe", "compatible_drone_types": [], "compatible_nacelle_ids": []},
				{"id": "payload_superlight", "name": "SuperLight", "compatible_drone_types": [0], "compatible_nacelle_ids": []},
			]
		}
	}


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
