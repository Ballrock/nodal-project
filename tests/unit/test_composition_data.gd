extends GutTest

## Tests unitaires pour NacelleDefinition, EffectDefinition et DroneProfile.


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


# ── DroneProfile ──

func test_profile_create() -> void:
	var effects: Array[Dictionary] = [{"effect_id": &"e1", "variant": "Verte"}]
	var p := DroneProfile.create("Bengales", FleetData.DroneType.DRONE_RIFF, &"nac1", effects, 200)
	assert_ne(str(p.id), "", "Doit avoir un id")
	assert_eq(p.name, "Bengales")
	assert_eq(p.drone_type, FleetData.DroneType.DRONE_RIFF)
	assert_eq(p.nacelle_id, &"nac1")
	assert_eq(p.quantity, 200)
	assert_eq(p.effects.size(), 1)


func test_profile_create_defaults() -> void:
	var p := DroneProfile.create()
	assert_eq(p.name, "Nouveau profil")
	assert_eq(p.drone_type, FleetData.DroneType.DRONE_RIFF)
	assert_eq(p.quantity, 1)
	assert_eq(p.effects, [])


func test_profile_get_drone_type_label() -> void:
	var p := DroneProfile.new()
	p.drone_type = FleetData.DroneType.DRONE_RIFF
	assert_eq(p.get_drone_type_label(), "RIFF")
	p.drone_type = FleetData.DroneType.DRONE_EMO
	assert_eq(p.get_drone_type_label(), "EMO")


func test_profile_to_dict() -> void:
	var effects: Array[Dictionary] = [{"effect_id": &"e1", "variant": "Rouge"}]
	var p := DroneProfile.create("Test", 0, &"nac1", effects, 50)
	var d := p.to_dict()
	assert_eq(d["name"], "Test")
	assert_eq(d["drone_type"], 0)
	assert_eq(d["nacelle_id"], "nac1")
	assert_eq(d["quantity"], 50)
	assert_eq(d["effects"].size(), 1)
	assert_eq(d["effects"][0]["variant"], "Rouge")


func test_profile_from_dict() -> void:
	var d := {
		"id": "prof_test",
		"name": "Lasers",
		"drone_type": 1,
		"nacelle_id": "nac_laser",
		"effects": [{"effect_id": "e_laser", "variant": "RGB"}],
		"quantity": 50,
	}
	var p := DroneProfile.from_dict(d)
	assert_eq(str(p.id), "prof_test")
	assert_eq(p.name, "Lasers")
	assert_eq(p.drone_type, FleetData.DroneType.DRONE_EMO)
	assert_eq(str(p.nacelle_id), "nac_laser")
	assert_eq(p.quantity, 50)
	assert_eq(p.effects.size(), 1)


func test_profile_from_dict_defaults() -> void:
	var d := {}
	var p := DroneProfile.from_dict(d)
	assert_eq(p.name, "Nouveau profil")
	assert_eq(p.quantity, 1)
	assert_eq(p.effects, [])


func test_profile_roundtrip() -> void:
	var effects: Array[Dictionary] = [
		{"effect_id": &"e1", "variant": "Verte"},
		{"effect_id": &"e2", "variant": ""},
	]
	var original := DroneProfile.create("RoundTrip", 1, &"nac2", effects, 100)
	var d := original.to_dict()
	var restored := DroneProfile.from_dict(d)
	assert_eq(restored.name, original.name)
	assert_eq(restored.drone_type, original.drone_type)
	assert_eq(str(restored.nacelle_id), str(original.nacelle_id))
	assert_eq(restored.quantity, original.quantity)
	assert_eq(restored.effects.size(), original.effects.size())
	assert_eq(str(restored.id), str(original.id))
