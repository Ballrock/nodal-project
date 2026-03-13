extends GutTest

## Tests unitaires pour NacelleManager.

var NacelleManagerClass = load("res://core/nacelle/nacelle_manager.gd")
var _manager: Node = null


func before_each() -> void:
	_manager = NacelleManagerClass.new()
	# Ne pas appeler add_child pour eviter _ready() qui accede au cache


func after_each() -> void:
	if _manager:
		_manager.free()


# ── Etat initial ──

func test_initial_state() -> void:
	assert_eq(_manager.get_nacelles().size(), 0)
	assert_eq(_manager.get_nacelle_count(), 0)
	assert_eq(_manager.is_loaded(), false)
	assert_eq(_manager.is_downloading(), false)
	assert_eq(_manager.get_last_download_date(), "")
	assert_eq(_manager.get_timestamp(), 0)


func test_get_last_download_date_formatted_never() -> void:
	assert_eq(_manager.get_last_download_date_formatted(), "Jamais")


func test_get_last_download_date_formatted_with_value() -> void:
	_manager._last_download_date = "2026-03-13T10:00:00"
	assert_eq(_manager.get_last_download_date_formatted(), "2026-03-13T10:00:00")


func test_get_file_version_date_unknown() -> void:
	assert_eq(_manager.get_file_version_date(), "Inconnue")


func test_get_file_version_date_with_timestamp() -> void:
	_manager._timestamp = 1709373229  # 2024-03-02 ~10:53 UTC
	var result = _manager.get_file_version_date()
	assert_ne(result, "Inconnue")
	assert_true(result.contains("2024"))


# ── Parsing ──

func test_parse_nacelles_data_empty() -> void:
	_manager._parse_nacelles_data({"nacelles": [], "timestamp": 0})
	assert_eq(_manager.get_nacelle_count(), 0)


func test_parse_nacelles_data_single() -> void:
	var data := {
		"timestamp": 12345,
		"nacelles": [
			{
				"name": "Standard",
				"typeDrone": "RIFF",
				"type": "dessus",
				"poids": 120,
				"nbEffets": 2,
				"effects": [],
			}
		]
	}
	_manager._parse_nacelles_data(data)
	assert_eq(_manager.get_nacelle_count(), 1)
	assert_eq(_manager.get_timestamp(), 12345)
	var n = _manager.get_nacelles()[0]
	assert_eq(n.name, "Standard")
	assert_eq(n.type_drone, "RIFF")
	assert_eq(n.mount_type, "dessus")
	assert_eq(n.weight, 120)


func test_parse_nacelles_data_multiple() -> void:
	var data := {
		"timestamp": 100,
		"nacelles": [
			{"name": "Nac A", "typeDrone": "RIFF", "type": "dessus", "poids": 100, "nbEffets": 1, "effects": []},
			{"name": "Nac B", "typeDrone": "EMO", "type": "dessous", "poids": 200, "nbEffets": 3, "effects": []},
		]
	}
	_manager._parse_nacelles_data(data)
	assert_eq(_manager.get_nacelle_count(), 2)


func test_parse_nacelles_data_skips_non_dict() -> void:
	var data := {
		"timestamp": 0,
		"nacelles": [
			{"name": "Valid", "typeDrone": "RIFF"},
			"invalid_entry",
			42,
		]
	}
	_manager._parse_nacelles_data(data)
	assert_eq(_manager.get_nacelle_count(), 1)


func test_parse_clears_previous() -> void:
	_manager._parse_nacelles_data({"timestamp": 1, "nacelles": [{"name": "A"}]})
	assert_eq(_manager.get_nacelle_count(), 1)
	_manager._parse_nacelles_data({"timestamp": 2, "nacelles": [{"name": "B"}, {"name": "C"}]})
	assert_eq(_manager.get_nacelle_count(), 2)
	assert_eq(_manager.get_nacelles()[0].name, "B")


func test_parse_extracts_timestamp() -> void:
	_manager._parse_nacelles_data({"timestamp": 99999, "nacelles": []})
	assert_eq(_manager.get_timestamp(), 99999)


# ── find_nacelle_by_name ──

func test_find_nacelle_by_name_found() -> void:
	_manager._parse_nacelles_data({
		"timestamp": 0,
		"nacelles": [
			{"name": "Alpha", "typeDrone": "RIFF"},
			{"name": "Beta", "typeDrone": "EMO"},
		]
	})
	var found = _manager.find_nacelle_by_name("Beta")
	assert_not_null(found)
	assert_eq(found.name, "Beta")
	assert_eq(found.type_drone, "EMO")


func test_find_nacelle_by_name_not_found() -> void:
	_manager._parse_nacelles_data({
		"timestamp": 0,
		"nacelles": [{"name": "Alpha"}]
	})
	var found = _manager.find_nacelle_by_name("Nonexistent")
	assert_null(found)


func test_find_nacelle_by_name_empty_list() -> void:
	var found = _manager.find_nacelle_by_name("Any")
	assert_null(found)


# ── Constantes ──

func test_download_url_is_set() -> void:
	assert_true(_manager.DOWNLOAD_URL.begins_with("https://"))
	assert_true(_manager.DOWNLOAD_URL.contains("nacelles"))


func test_cache_paths() -> void:
	assert_true(_manager.CACHE_DIR.begins_with("user://"))
	assert_true(_manager.CACHE_FILE.begins_with("user://"))
	assert_true(_manager.META_FILE.begins_with("user://"))


# ── download_nacelles guard ──

func test_download_guard_prevents_double_download() -> void:
	_manager._is_downloading = true
	_manager.download_nacelles()
	assert_true(_manager._is_downloading)


# ── NacelleDefinition from_download_dict ──

func test_nacelle_from_download_dict_riff() -> void:
	var d := {
		"name": "PyroLight",
		"typeDrone": "RIFF",
		"type": "dessus",
		"poids": 120,
		"nbEffets": 2,
		"effects": [
			{"channel": 1, "angleH": 45.0, "angleP": 10.0},
			{"channel": 2, "angleH": 90.0, "angleP": 20.0},
		]
	}
	var n := NacelleDefinition.from_download_dict(d)
	assert_eq(n.name, "PyroLight")
	assert_eq(str(n.id), "PyroLight")
	assert_eq(n.type_drone, "RIFF")
	assert_eq(n.mount_type, "dessus")
	assert_eq(n.weight, 120)
	assert_eq(n.effect_count, 2)
	assert_eq(n.effects.size(), 2)
	assert_eq(n.effects[0]["channel"], 1)
	assert_almost_eq(float(n.effects[0]["angleH"]), 45.0, 0.01)
	assert_eq(n.compatible_drone_types, [0])


func test_nacelle_from_download_dict_emo() -> void:
	var d := {"name": "LaserMount", "typeDrone": "EMO", "type": "dessous", "poids": 80, "nbEffets": 0, "effects": []}
	var n := NacelleDefinition.from_download_dict(d)
	assert_eq(n.compatible_drone_types, [1])


func test_nacelle_from_download_dict_unknown_type() -> void:
	var d := {"name": "Unknown", "typeDrone": "UNKNOWN", "type": "suspension", "poids": 50, "nbEffets": 0, "effects": []}
	var n := NacelleDefinition.from_download_dict(d)
	# Unknown type defaults to both drone types
	assert_eq(n.compatible_drone_types.size(), 2)
	assert_true(n.compatible_drone_types.has(0))
	assert_true(n.compatible_drone_types.has(1))


func test_nacelle_from_download_dict_empty() -> void:
	var d := {}
	var n := NacelleDefinition.from_download_dict(d)
	assert_eq(n.name, "")
	assert_eq(n.weight, 0)
	assert_eq(n.effects.size(), 0)


func test_nacelle_get_mount_type_label() -> void:
	var n := NacelleDefinition.new()
	n.mount_type = "dessus"
	assert_eq(n.get_mount_type_label(), "Dessus")
	n.mount_type = "dessous"
	assert_eq(n.get_mount_type_label(), "Dessous")
	n.mount_type = "suspension"
	assert_eq(n.get_mount_type_label(), "Suspension")
	n.mount_type = ""
	assert_eq(n.get_mount_type_label(), "N/A")
	n.mount_type = "custom"
	assert_eq(n.get_mount_type_label(), "Custom")
