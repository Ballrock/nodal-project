extends GutTest

## Tests unitaires pour NacelleDefinition, EffectDefinition et DroneConstraint.


# ── NacelleDefinition ──

func test_nacelle_create() -> void:
	var n := NacelleDefinition.create("PyroLight", [0])
	assert_ne(str(n.id), "", "Doit avoir un id")
	assert_eq(n.name, "PyroLight")
	assert_eq(n.compatible_drone_types, [0])


func test_nacelle_create_multiple_types() -> void:
	var n := NacelleDefinition.create("Standard", [0, 1])
	assert_eq(n.compatible_drone_types.size(), 2)
	assert_true(n.compatible_drone_types.has(0))
	assert_true(n.compatible_drone_types.has(1))


func test_nacelle_to_dict() -> void:
	var n := NacelleDefinition.create("LaserMount", [1])
	var d := n.to_dict()
	assert_eq(d["name"], "LaserMount")
	assert_eq(d["compatible_drone_types"], [1])
	assert_true(d.has("id"))


func test_nacelle_from_dict() -> void:
	var d := {"id": "test_id", "name": "TestNacelle", "compatible_drone_types": [0, 1]}
	var n := NacelleDefinition.from_dict(d)
	assert_eq(str(n.id), "test_id")
	assert_eq(n.name, "TestNacelle")
	assert_eq(n.compatible_drone_types, [0, 1])


func test_nacelle_from_dict_empty() -> void:
	var d := {}
	var n := NacelleDefinition.from_dict(d)
	assert_eq(n.name, "")
	assert_eq(n.compatible_drone_types, [])


func test_nacelle_roundtrip() -> void:
	var original := NacelleDefinition.create("RoundTrip", [0, 1])
	var d := original.to_dict()
	var restored := NacelleDefinition.from_dict(d)
	assert_eq(restored.name, original.name)
	assert_eq(restored.compatible_drone_types, original.compatible_drone_types)
	assert_eq(str(restored.id), str(original.id))


# ── EffectDefinition ──

func test_effect_create() -> void:
	var e := EffectDefinition.create("Feu pyro", EffectDefinition.Category.PYRO, [&"nacelle_a"], ["Verte", "Rouge"])
	assert_ne(str(e.id), "", "Doit avoir un id")
	assert_eq(e.name, "Feu pyro")
	assert_eq(e.category, EffectDefinition.Category.PYRO)
	assert_eq(e.compatible_nacelle_ids, [&"nacelle_a"])
	assert_eq(e.variants, ["Verte", "Rouge"])


func test_effect_get_category_label() -> void:
	var e := EffectDefinition.new()
	e.category = EffectDefinition.Category.PYRO
	assert_eq(e.get_category_label(), "Pyrotechnique")
	e.category = EffectDefinition.Category.SMOKE
	assert_eq(e.get_category_label(), "Fumée")
	e.category = EffectDefinition.Category.STROBE
	assert_eq(e.get_category_label(), "Stroboscopique")
	e.category = EffectDefinition.Category.LASER
	assert_eq(e.get_category_label(), "Laser")


func test_effect_is_compatible_with_nacelle() -> void:
	var e := EffectDefinition.create("Test", 0, [&"n1", &"n2"])
	assert_true(e.is_compatible_with_nacelle(&"n1"))
	assert_true(e.is_compatible_with_nacelle(&"n2"))
	assert_false(e.is_compatible_with_nacelle(&"n3"))


func test_effect_to_dict() -> void:
	var e := EffectDefinition.create("Laser", EffectDefinition.Category.LASER, [&"nac1"], ["RGB"])
	var d := e.to_dict()
	assert_eq(d["name"], "Laser")
	assert_eq(d["category"], EffectDefinition.Category.LASER)
	assert_true(d["compatible_nacelle_ids"].has("nac1"))
	assert_eq(d["variants"], ["RGB"])


func test_effect_from_dict() -> void:
	var d := {
		"id": "eff_test",
		"name": "Smoke",
		"category": 1,
		"compatible_nacelle_ids": ["n1", "n2"],
		"variants": ["Blanche", "Colorée"],
	}
	var e := EffectDefinition.from_dict(d)
	assert_eq(str(e.id), "eff_test")
	assert_eq(e.name, "Smoke")
	assert_eq(e.category, EffectDefinition.Category.SMOKE)
	assert_eq(e.compatible_nacelle_ids.size(), 2)
	assert_eq(e.variants, ["Blanche", "Colorée"])


func test_effect_roundtrip() -> void:
	var original := EffectDefinition.create("Strobe", EffectDefinition.Category.STROBE, [&"n1"], [])
	var d := original.to_dict()
	var restored := EffectDefinition.from_dict(d)
	assert_eq(restored.name, original.name)
	assert_eq(restored.category, original.category)
	assert_eq(str(restored.id), str(original.id))


# ── DroneConstraint ──

func test_constraint_create() -> void:
	var p := DroneConstraint.create("Bengales", DroneConstraint.ConstraintCategory.PYRO_EFFECT, "effect_pyro::Bengale verte", 200)
	assert_ne(str(p.id), "", "Doit avoir un id")
	assert_eq(p.name, "Bengales")
	assert_eq(p.category, DroneConstraint.ConstraintCategory.PYRO_EFFECT)
	assert_eq(p.value, "effect_pyro::Bengale verte")
	assert_eq(p.quantity, 200)


func test_constraint_create_defaults() -> void:
	var p := DroneConstraint.create()
	assert_eq(p.name, "Nouvelle contrainte")
	assert_eq(p.category, DroneConstraint.ConstraintCategory.DRONE_TYPE)
	assert_eq(p.value, "")
	assert_eq(p.quantity, 1)


func test_constraint_get_category_label() -> void:
	var p := DroneConstraint.new()
	p.category = DroneConstraint.ConstraintCategory.DRONE_TYPE
	assert_eq(p.get_category_label(), "Type drone")
	p.category = DroneConstraint.ConstraintCategory.NACELLE
	assert_eq(p.get_category_label(), "Nacelle")
	p.category = DroneConstraint.ConstraintCategory.PAYLOAD
	assert_eq(p.get_category_label(), "Payload")
	p.category = DroneConstraint.ConstraintCategory.PYRO_EFFECT
	assert_eq(p.get_category_label(), "Effet Pyro")


func test_constraint_get_value_display_label_drone_type() -> void:
	var p := DroneConstraint.create("Riff", DroneConstraint.ConstraintCategory.DRONE_TYPE, "0", 10)
	assert_eq(p.get_value_display_label([], []), "RIFF")
	p.value = "1"
	assert_eq(p.get_value_display_label([], []), "EMO")


func test_constraint_get_value_display_label_nacelle() -> void:
	var nacelles := [{"id": "nacelle_standard", "name": "Standard", "compatible_drone_types": [0, 1]}]
	var p := DroneConstraint.create("Std", DroneConstraint.ConstraintCategory.NACELLE, "nacelle_standard", 10)
	assert_eq(p.get_value_display_label(nacelles, []), "Standard")


func test_constraint_get_value_display_label_payload() -> void:
	var p := DroneConstraint.create("Laser", DroneConstraint.ConstraintCategory.PAYLOAD, "payload_laser", 10)
	assert_eq(p.get_value_display_label([], []), "Laser")


func test_constraint_get_value_display_label_pyro_effect() -> void:
	var effects := [{"id": "effect_pyro", "name": "Feu pyro", "compatible_nacelle_ids": ["nacelle_standard"], "variants": ["Bengale verte"]}]
	var p := DroneConstraint.create("Bengale", DroneConstraint.ConstraintCategory.PYRO_EFFECT, "effect_pyro::Bengale verte", 10)
	assert_eq(p.get_value_display_label([], effects), "Feu pyro — Bengale verte")


func test_constraint_to_dict() -> void:
	var p := DroneConstraint.create("Test", DroneConstraint.ConstraintCategory.NACELLE, "nac1", 50)
	var d := p.to_dict()
	assert_eq(d["name"], "Test")
	assert_eq(d["category"], DroneConstraint.ConstraintCategory.NACELLE)
	assert_eq(d["value"], "nac1")
	assert_eq(d["quantity"], 50)


func test_constraint_from_dict() -> void:
	var d := {
		"id": "prof_test",
		"name": "Lasers",
		"category": DroneConstraint.ConstraintCategory.PYRO_EFFECT,
		"value": "e_laser::RGB",
		"quantity": 50,
	}
	var p := DroneConstraint.from_dict(d)
	assert_eq(str(p.id), "prof_test")
	assert_eq(p.name, "Lasers")
	assert_eq(p.category, DroneConstraint.ConstraintCategory.PYRO_EFFECT)
	assert_eq(p.value, "e_laser::RGB")
	assert_eq(p.quantity, 50)


func test_constraint_from_dict_defaults() -> void:
	var d := {}
	var p := DroneConstraint.from_dict(d)
	assert_eq(p.name, "Nouvelle contrainte")
	assert_eq(p.quantity, 1)
	assert_eq(p.category, DroneConstraint.ConstraintCategory.DRONE_TYPE)
	assert_eq(p.value, "0")


func test_constraint_from_dict_legacy_migration_effects() -> void:
	var d := {
		"id": "legacy1",
		"name": "OldProfile",
		"drone_type": 0,
		"nacelle_id": "nac1",
		"effects": [{"effect_id": "e1", "variant": "Verte"}],
		"quantity": 100,
	}
	var p := DroneConstraint.from_dict(d)
	assert_eq(p.category, DroneConstraint.ConstraintCategory.PYRO_EFFECT)
	assert_eq(p.value, "e1::Verte")
	assert_eq(p.quantity, 100)


func test_constraint_from_dict_legacy_migration_nacelle() -> void:
	var d := {
		"id": "legacy2",
		"name": "OldNacelle",
		"drone_type": 1,
		"nacelle_id": "nacelle_lasermount",
		"effects": [],
		"quantity": 50,
	}
	var p := DroneConstraint.from_dict(d)
	assert_eq(p.category, DroneConstraint.ConstraintCategory.NACELLE)
	assert_eq(p.value, "nacelle_lasermount")


func test_constraint_from_dict_legacy_migration_drone_type() -> void:
	var d := {
		"id": "legacy3",
		"name": "OldType",
		"drone_type": 1,
		"effects": [],
		"quantity": 50,
	}
	var p := DroneConstraint.from_dict(d)
	assert_eq(p.category, DroneConstraint.ConstraintCategory.DRONE_TYPE)
	assert_eq(p.value, "1")


func test_constraint_roundtrip() -> void:
	var original := DroneConstraint.create("RoundTrip", DroneConstraint.ConstraintCategory.PYRO_EFFECT, "e1::Verte", 100)
	var d := original.to_dict()
	var restored := DroneConstraint.from_dict(d)
	assert_eq(restored.name, original.name)
	assert_eq(restored.category, original.category)
	assert_eq(restored.value, original.value)
	assert_eq(restored.quantity, original.quantity)
	assert_eq(str(restored.id), str(original.id))


func test_constraint_resolve_implications_drone_type() -> void:
	var p := DroneConstraint.create("Riff", DroneConstraint.ConstraintCategory.DRONE_TYPE, "0", 10)
	var result := p.resolve_implications([], [])
	assert_eq(result["implied_drone_types"], [0])
	assert_true(result["type_resolved"])
	assert_eq(result["implied_drone_type_labels"], ["RIFF"])


func test_constraint_resolve_implications_nacelle() -> void:
	var nacelles := [
		{"id": "nacelle_pyrolight", "name": "PyroLight", "compatible_drone_types": [0]},
	]
	var p := DroneConstraint.create("PyroNacelle", DroneConstraint.ConstraintCategory.NACELLE, "nacelle_pyrolight", 10)
	var result := p.resolve_implications(nacelles, [])
	assert_eq(result["implied_nacelle_ids"], ["nacelle_pyrolight"])
	assert_true(result["nacelle_resolved"])
	assert_eq(result["implied_drone_types"], [0])
	assert_true(result["type_resolved"])
	assert_eq(result["implied_drone_type_labels"], ["RIFF"])


func test_constraint_resolve_implications_nacelle_multiple_types() -> void:
	var nacelles := [
		{"id": "nacelle_standard", "name": "Standard", "compatible_drone_types": [0, 1]},
	]
	var p := DroneConstraint.create("Std", DroneConstraint.ConstraintCategory.NACELLE, "nacelle_standard", 10)
	var result := p.resolve_implications(nacelles, [])
	assert_false(result["type_resolved"])
	assert_eq(result["implied_drone_types"].size(), 2)


func test_constraint_resolve_implications_pyro_effect() -> void:
	var nacelles := [
		{"id": "nacelle_pyrolight", "name": "PyroLight", "compatible_drone_types": [0]},
		{"id": "nacelle_standard", "name": "Standard", "compatible_drone_types": [0, 1]},
	]
	var effects := [
		{"id": "effect_pyro", "name": "Feu pyro", "category": 0, "compatible_nacelle_ids": ["nacelle_pyrolight", "nacelle_standard"], "variants": ["Bengale verte"]},
	]
	var p := DroneConstraint.create("Bengale", DroneConstraint.ConstraintCategory.PYRO_EFFECT, "effect_pyro::Bengale verte", 10)
	var result := p.resolve_implications(nacelles, effects)
	assert_eq(result["implied_nacelle_ids"].size(), 2)
	assert_false(result["nacelle_resolved"])
	assert_true(result["implied_drone_types"].has(0))


func test_constraint_resolve_implications_payload_with_nacelle() -> void:
	# Injecter un catalogue payloads avec contraintes dans SettingsManager
	var test_payloads := [
		{"id": "payload_laser", "name": "Laser", "compatible_drone_types": [], "compatible_nacelle_ids": ["nacelle_lasermount"]},
	]
	var old_payloads = SettingsManager.get_setting("composition/payloads")
	SettingsManager.set_setting("composition/payloads", test_payloads)

	var nacelles := [
		{"id": "nacelle_lasermount", "name": "LaserMount", "compatible_drone_types": [1]},
	]
	var p := DroneConstraint.create("Laser", DroneConstraint.ConstraintCategory.PAYLOAD, "payload_laser", 10)
	var result := p.resolve_implications(nacelles, [])
	assert_eq(result["implied_nacelle_ids"].size(), 1, "Laser implique nacelle_lasermount")
	assert_true(result["nacelle_resolved"], "Nacelle resolue (1 seule)")
	assert_eq(result["implied_drone_types"].size(), 1, "Un type drone implique via nacelle")
	assert_true(result["type_resolved"], "Type drone resolu")

	# Restaurer
	SettingsManager.set_setting("composition/payloads", old_payloads)


func test_constraint_resolve_implications_payload_no_constraints() -> void:
	# Injecter un payload sans contrainte
	var test_payloads := [
		{"id": "payload_smoke", "name": "Smoke", "compatible_drone_types": [], "compatible_nacelle_ids": []},
	]
	var old_payloads = SettingsManager.get_setting("composition/payloads")
	SettingsManager.set_setting("composition/payloads", test_payloads)

	var p := DroneConstraint.create("Smoke", DroneConstraint.ConstraintCategory.PAYLOAD, "payload_smoke", 5)
	var result := p.resolve_implications([], [])
	assert_eq(result["implied_nacelle_ids"].size(), 0)
	assert_eq(result["implied_drone_types"].size(), 0)
	assert_false(result["type_resolved"])

	# Restaurer
	SettingsManager.set_setting("composition/payloads", old_payloads)
