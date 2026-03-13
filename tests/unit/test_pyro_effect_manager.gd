extends GutTest

## Tests unitaires pour PyroEffectManager.

var PyroEffectManagerClass = load("res://core/pyro_effect/pyro_effect_manager.gd")
var _manager: Node = null


func before_each() -> void:
	_manager = PyroEffectManagerClass.new()
	# Ne pas appeler add_child pour eviter _ready() qui tente d'acceder au cache
	# On teste les methodes internes directement


func after_each() -> void:
	if _manager:
		_manager.free()


# ── Etat initial ──

func test_initial_state() -> void:
	assert_eq(_manager.get_pyro_effects().size(), 0)
	assert_eq(_manager.get_pyro_effect_count(), 0)
	assert_eq(_manager.is_loaded(), false)
	assert_eq(_manager.is_downloading(), false)
	assert_eq(_manager.get_last_download_date(), "")
	assert_eq(_manager.get_file_version_date(), "Inconnue")


func test_get_last_download_date_formatted_never() -> void:
	assert_eq(_manager.get_last_download_date_formatted(), "Jamais")


func test_get_last_download_date_formatted_with_value() -> void:
	_manager._last_download_date = "2026-03-13T10:00:00"
	assert_eq(_manager.get_last_download_date_formatted(), "2026-03-13T10:00:00")


func test_get_file_version_date_unknown() -> void:
	assert_eq(_manager.get_file_version_date(), "Inconnue")


func test_get_file_version_date_with_value() -> void:
	_manager._file_version_date = "2026-03-02T09:53:49.015Z"
	assert_eq(_manager.get_file_version_date(), "2026-03-02T09:53:49.015Z")


# ── Parsing ──

func test_parse_pyro_effects_data_empty() -> void:
	_manager._parse_pyro_effects_data([])
	assert_eq(_manager.get_pyro_effect_count(), 0)


func test_parse_pyro_effects_data_single() -> void:
	var data := [
		{
			"name": "BE 120S CL BL IG",
			"fabricant": "",
			"isAssemblage": false,
			"type": "Bengal",
			"calibre": "60mm",
			"poids": 66,
		}
	]
	_manager._parse_pyro_effects_data(data)
	assert_eq(_manager.get_pyro_effect_count(), 1)
	var e = _manager.get_pyro_effects()[0]
	assert_eq(e.name, "BE 120S CL BL IG")
	assert_eq(e.type, "Bengal")
	assert_eq(e.poids, 66.0)


func test_parse_pyro_effects_data_multiple() -> void:
	var data := [
		{"name": "Effect A", "type": "Bengal", "poids": 30},
		{"name": "Effect B", "type": "Cascade", "poids": 48},
		{"name": "Effect C", "type": "Fumigène", "poids": 250},
	]
	_manager._parse_pyro_effects_data(data)
	assert_eq(_manager.get_pyro_effect_count(), 3)


func test_parse_pyro_effects_data_skips_non_dict() -> void:
	var data: Array = [
		{"name": "Valid", "type": "Bengal"},
		"invalid_entry",
		42,
		{"name": "Also Valid", "type": "Cascade"},
	]
	_manager._parse_pyro_effects_data(data)
	assert_eq(_manager.get_pyro_effect_count(), 2)


func test_parse_clears_previous() -> void:
	_manager._parse_pyro_effects_data([{"name": "A", "type": "Bengal"}])
	assert_eq(_manager.get_pyro_effect_count(), 1)
	_manager._parse_pyro_effects_data([{"name": "B", "type": "Jet"}, {"name": "C", "type": "Flash"}])
	assert_eq(_manager.get_pyro_effect_count(), 2)
	assert_eq(_manager.get_pyro_effects()[0].name, "B")


# ── find_by_name ──

func test_find_by_name_found() -> void:
	_manager._parse_pyro_effects_data([
		{"name": "Effect A", "type": "Bengal"},
		{"name": "Effect B", "type": "Cascade"},
	])
	var found = _manager.find_by_name("Effect B")
	assert_not_null(found)
	assert_eq(found.name, "Effect B")
	assert_eq(found.type, "Cascade")


func test_find_by_name_not_found() -> void:
	_manager._parse_pyro_effects_data([
		{"name": "Effect A", "type": "Bengal"},
	])
	var found = _manager.find_by_name("Nonexistent")
	assert_null(found)


func test_find_by_name_empty_list() -> void:
	var found = _manager.find_by_name("Any")
	assert_null(found)


# ── get_unique_types ──

func test_get_unique_types() -> void:
	_manager._parse_pyro_effects_data([
		{"name": "A", "type": "Bengal"},
		{"name": "B", "type": "Cascade"},
		{"name": "C", "type": "Bengal"},
		{"name": "D", "type": "Fumigène"},
	])
	var types = _manager.get_unique_types()
	assert_eq(types.size(), 3)
	assert_true(types.has("Bengal"))
	assert_true(types.has("Cascade"))
	assert_true(types.has("Fumigène"))


func test_get_unique_types_empty() -> void:
	var types = _manager.get_unique_types()
	assert_eq(types.size(), 0)


# ── Constantes ──

func test_download_url_is_set() -> void:
	assert_true(_manager.DOWNLOAD_URL.begins_with("https://"))
	assert_true(_manager.DOWNLOAD_URL.contains("pyro_effects"))


func test_metadata_url_is_set() -> void:
	assert_true(_manager.METADATA_URL.begins_with("https://"))
	assert_true(_manager.METADATA_URL.contains("pyro_effects"))
	assert_false(_manager.METADATA_URL.contains("alt=media"))


func test_cache_paths() -> void:
	assert_true(_manager.CACHE_DIR.begins_with("user://"))
	assert_true(_manager.CACHE_FILE.begins_with("user://"))
	assert_true(_manager.META_FILE.begins_with("user://"))


# ── download_pyro_effects guard ──

func test_download_guard_prevents_double_download() -> void:
	_manager._is_downloading = true
	# Should return without doing anything
	_manager.download_pyro_effects()
	# Still downloading (no new request created since we didn't add_child)
	assert_true(_manager._is_downloading)
