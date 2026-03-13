extends GutTest

## Tests unitaires pour PyroEffectDefinition.


# ── Construction de base ──

func test_new_has_default_values() -> void:
	var e := PyroEffectDefinition.new()
	assert_eq(e.name, "")
	assert_eq(e.fabricant, "")
	assert_eq(e.is_assemblage, false)
	assert_eq(e.type, "")
	assert_eq(e.calibre, "")
	assert_eq(e.poids, 0.0)
	assert_eq(e.ae, false)
	assert_eq(e.poussee, false)


# ── from_download_dict ──

func test_from_download_dict_basic() -> void:
	var d := {
		"name": "BE 120S CL BL IG",
		"fabricant": "TestFab",
		"isAssemblage": false,
		"type": "Bengal",
		"calibre": "60mm",
		"poids": 66,
		"tailleInfla": 0,
		"codeONU": "0336",
		"categorie": "f2",
		"classe": "14G",
		"distanceSecuriteVerticale": 10,
		"distanceSecuriteHorizontale": 2,
		"hauteurEffet": 1,
		"ae": true,
		"duree": 120,
		"poussee": false,
	}
	var e := PyroEffectDefinition.from_download_dict(d)
	assert_eq(e.name, "BE 120S CL BL IG")
	assert_eq(str(e.id), "BE 120S CL BL IG")
	assert_eq(e.fabricant, "TestFab")
	assert_eq(e.is_assemblage, false)
	assert_eq(e.type, "Bengal")
	assert_eq(e.calibre, "60mm")
	assert_eq(e.poids, 66.0)
	assert_eq(e.taille_infla, 0.0)
	assert_eq(e.code_onu, "0336")
	assert_eq(e.categorie, "f2")
	assert_eq(e.classe, "14G")
	assert_eq(e.distance_securite_verticale, 10.0)
	assert_eq(e.distance_securite_horizontale, 2.0)
	assert_eq(e.hauteur_effet, 1.0)
	assert_eq(e.ae, true)
	assert_eq(e.duree, 120.0)
	assert_eq(e.poussee, false)


func test_from_download_dict_with_null_values() -> void:
	var d := {
		"name": "Test Null",
		"fabricant": null,
		"isAssemblage": false,
		"type": "Fumigène",
		"calibre": null,
		"poids": null,
		"tailleInfla": null,
		"codeONU": "",
		"categorie": "",
		"classe": "",
		"distanceSecuriteVerticale": null,
		"distanceSecuriteHorizontale": null,
		"hauteurEffet": null,
		"largeurEffet": null,
		"ae": false,
		"duree": null,
		"longueur": null,
		"nbEffets": null,
		"poussee": false,
		"valeurPoussee": null,
		"tube": null,
		"poidsResiduel": null,
	}
	var e := PyroEffectDefinition.from_download_dict(d)
	assert_eq(e.name, "Test Null")
	assert_eq(e.poids, 0.0)
	assert_eq(e.taille_infla, 0.0)
	assert_eq(e.distance_securite_verticale, 0.0)
	assert_eq(e.distance_securite_horizontale, 0.0)
	assert_eq(e.hauteur_effet, 0.0)
	assert_eq(e.largeur_effet, 0.0)
	assert_eq(e.duree, 0.0)
	assert_eq(e.longueur, 0.0)
	assert_eq(e.nb_effets, 0.0)
	assert_eq(e.valeur_poussee, 0.0)
	assert_eq(e.poids_residuel, 0.0)


func test_from_download_dict_assemblage() -> void:
	var d := {
		"name": "LA 60S CL BL IG x FX 15X25 AR CA WE",
		"isAssemblage": true,
		"type": "Bengal x Jet",
		"poids": 69,
		"nbEffets": 2,
	}
	var e := PyroEffectDefinition.from_download_dict(d)
	assert_eq(e.is_assemblage, true)
	assert_eq(e.type, "Bengal x Jet")
	assert_eq(e.nb_effets, 2.0)


func test_from_download_dict_with_poussee() -> void:
	var d := {
		"name": "MC 20 SW CO BT RC",
		"type": "Comètes",
		"poussee": true,
		"valeurPoussee": 0.71,
	}
	var e := PyroEffectDefinition.from_download_dict(d)
	assert_eq(e.poussee, true)
	assert_almost_eq(e.valeur_poussee, 0.71, 0.001)


func test_from_download_dict_empty() -> void:
	var d := {}
	var e := PyroEffectDefinition.from_download_dict(d)
	assert_eq(e.name, "")
	assert_eq(e.type, "")
	assert_eq(e.poids, 0.0)
	assert_eq(e.ae, false)


func test_from_download_dict_strips_type_edges() -> void:
	var d := {"name": "Test", "type": "  Bengal  "}
	var e := PyroEffectDefinition.from_download_dict(d)
	assert_eq(e.type, "Bengal")


# ── to_dict / from_dict roundtrip ──

func test_to_dict() -> void:
	var e := PyroEffectDefinition.new()
	e.id = &"test_id"
	e.name = "Test Effect"
	e.fabricant = "Fab"
	e.is_assemblage = true
	e.type = "Cascade"
	e.calibre = "30mm"
	e.poids = 48.0
	e.taille_infla = 18.0
	e.code_onu = "0336"
	e.categorie = "f4"
	e.classe = "14G"
	e.distance_securite_verticale = 20.0
	e.distance_securite_horizontale = 2.0
	e.hauteur_effet = 50.0
	e.ae = true
	e.duree = 40.0
	e.poussee = false

	var d := e.to_dict()
	assert_eq(d["id"], "test_id")
	assert_eq(d["name"], "Test Effect")
	assert_eq(d["fabricant"], "Fab")
	assert_eq(d["isAssemblage"], true)
	assert_eq(d["type"], "Cascade")
	assert_eq(d["calibre"], "30mm")
	assert_eq(d["poids"], 48.0)
	assert_eq(d["tailleInfla"], 18.0)
	assert_eq(d["codeONU"], "0336")
	assert_eq(d["categorie"], "f4")
	assert_eq(d["classe"], "14G")
	assert_eq(d["distanceSecuriteVerticale"], 20.0)
	assert_eq(d["distanceSecuriteHorizontale"], 2.0)
	assert_eq(d["hauteurEffet"], 50.0)
	assert_eq(d["ae"], true)
	assert_eq(d["duree"], 40.0)
	assert_eq(d["poussee"], false)


func test_from_dict() -> void:
	var d := {
		"id": "my_id",
		"name": "From Dict",
		"fabricant": "MyFab",
		"isAssemblage": false,
		"type": "Fumigène",
		"calibre": "20mm",
		"poids": 250.0,
		"tailleInfla": 0.0,
		"codeONU": "0197",
		"categorie": "p1",
		"classe": "14G",
		"distanceSecuriteVerticale": 5.0,
		"distanceSecuriteHorizontale": 3.0,
		"hauteurEffet": 2.0,
		"largeurEffet": 1.0,
		"ae": false,
		"duree": 90.0,
		"longueur": 12.0,
		"nbEffets": 0.0,
		"poussee": false,
		"valeurPoussee": 0.0,
		"tube": "T1",
		"poidsResiduel": 10.0,
	}
	var e := PyroEffectDefinition.from_dict(d)
	assert_eq(str(e.id), "my_id")
	assert_eq(e.name, "From Dict")
	assert_eq(e.fabricant, "MyFab")
	assert_eq(e.type, "Fumigène")
	assert_eq(e.poids, 250.0)
	assert_eq(e.code_onu, "0197")
	assert_eq(e.tube, "T1")
	assert_eq(e.poids_residuel, 10.0)


func test_roundtrip() -> void:
	var original := PyroEffectDefinition.new()
	original.id = &"roundtrip_id"
	original.name = "Roundtrip"
	original.fabricant = "Fab"
	original.is_assemblage = true
	original.type = "Jet"
	original.calibre = "15mm"
	original.poids = 35.0
	original.taille_infla = 18.0
	original.code_onu = "0432"
	original.categorie = "t1"
	original.classe = "14S"
	original.distance_securite_verticale = 3.0
	original.distance_securite_horizontale = 2.0
	original.hauteur_effet = 7.0
	original.largeur_effet = 4.0
	original.ae = true
	original.duree = 15.0
	original.longueur = 10.0
	original.nb_effets = 2.0
	original.poussee = true
	original.valeur_poussee = 1.5
	original.tube = "T2"
	original.poids_residuel = 5.0

	var d := original.to_dict()
	var restored := PyroEffectDefinition.from_dict(d)

	assert_eq(str(restored.id), str(original.id))
	assert_eq(restored.name, original.name)
	assert_eq(restored.fabricant, original.fabricant)
	assert_eq(restored.is_assemblage, original.is_assemblage)
	assert_eq(restored.type, original.type)
	assert_eq(restored.calibre, original.calibre)
	assert_eq(restored.poids, original.poids)
	assert_eq(restored.taille_infla, original.taille_infla)
	assert_eq(restored.code_onu, original.code_onu)
	assert_eq(restored.categorie, original.categorie)
	assert_eq(restored.classe, original.classe)
	assert_eq(restored.distance_securite_verticale, original.distance_securite_verticale)
	assert_eq(restored.distance_securite_horizontale, original.distance_securite_horizontale)
	assert_eq(restored.hauteur_effet, original.hauteur_effet)
	assert_eq(restored.largeur_effet, original.largeur_effet)
	assert_eq(restored.ae, original.ae)
	assert_eq(restored.duree, original.duree)
	assert_eq(restored.longueur, original.longueur)
	assert_eq(restored.nb_effets, original.nb_effets)
	assert_eq(restored.poussee, original.poussee)
	assert_eq(restored.valeur_poussee, original.valeur_poussee)
	assert_eq(restored.tube, original.tube)
	assert_eq(restored.poids_residuel, original.poids_residuel)


# ── get_unique_types ──

func test_get_unique_types_empty() -> void:
	var effects: Array[PyroEffectDefinition] = []
	var types := PyroEffectDefinition.get_unique_types(effects)
	assert_eq(types.size(), 0)


func test_get_unique_types_basic() -> void:
	var effects: Array[PyroEffectDefinition] = []
	var e1 := PyroEffectDefinition.new()
	e1.type = "Bengal"
	var e2 := PyroEffectDefinition.new()
	e2.type = "Cascade"
	var e3 := PyroEffectDefinition.new()
	e3.type = "Bengal"
	effects.append(e1)
	effects.append(e2)
	effects.append(e3)
	var types := PyroEffectDefinition.get_unique_types(effects)
	assert_eq(types.size(), 2)
	assert_true(types.has("Bengal"))
	assert_true(types.has("Cascade"))


func test_get_unique_types_sorted() -> void:
	var effects: Array[PyroEffectDefinition] = []
	var e1 := PyroEffectDefinition.new()
	e1.type = "Fumigène"
	var e2 := PyroEffectDefinition.new()
	e2.type = "Bengal"
	var e3 := PyroEffectDefinition.new()
	e3.type = "Cascade"
	effects.append(e1)
	effects.append(e2)
	effects.append(e3)
	var types := PyroEffectDefinition.get_unique_types(effects)
	assert_eq(types[0], "Bengal")
	assert_eq(types[1], "Cascade")
	assert_eq(types[2], "Fumigène")


func test_get_unique_types_skips_empty() -> void:
	var effects: Array[PyroEffectDefinition] = []
	var e1 := PyroEffectDefinition.new()
	e1.type = "Bengal"
	var e2 := PyroEffectDefinition.new()
	e2.type = ""
	var e3 := PyroEffectDefinition.new()
	e3.type = "  "
	effects.append(e1)
	effects.append(e2)
	effects.append(e3)
	var types := PyroEffectDefinition.get_unique_types(effects)
	assert_eq(types.size(), 1)
	assert_eq(types[0], "Bengal")


# ── _safe_float ──

func test_safe_float_null() -> void:
	assert_eq(PyroEffectDefinition._safe_float(null), 0.0)


func test_safe_float_int() -> void:
	assert_eq(PyroEffectDefinition._safe_float(66), 66.0)


func test_safe_float_float() -> void:
	assert_almost_eq(PyroEffectDefinition._safe_float(0.71), 0.71, 0.001)


func test_safe_float_zero() -> void:
	assert_eq(PyroEffectDefinition._safe_float(0), 0.0)
