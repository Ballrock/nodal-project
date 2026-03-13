# res://core/settings/settings_manager.gd
extends Node

## Gère les paramètres du logiciel de manière data-driven.
## Distingue les paramètres globaux (logiciel) des paramètres locaux (projet/scénographie).

signal setting_changed(key: String, value: Variant)

enum SettingType {
	NUMBER = 0,
	STRING = 1,
	ARRAY = 2,
	JSON = 3,
	BOOLEAN = 4
}

enum SettingScope {
	GLOBAL = 0,   # Sauvegardé dans user://settings.json
	PROJECT = 1   # Sauvegardé dans le fichier .json du projet
}

const SETTINGS_FILE_PATH = "user://settings.json"

class Setting:
	var key: String
	var type: SettingType
	var scope: SettingScope
	var default_value: Variant
	var value: Variant
	var last_modified: String
	var category: String
	var label: String
	var description: String

	func _init(p_key: String, p_type: SettingType, p_default: Variant, p_scope: SettingScope = SettingScope.GLOBAL, p_category: String = "General", p_label: String = "", p_description: String = "") -> void:
		key = p_key
		type = p_type
		scope = p_scope
		default_value = p_default
		value = p_default
		category = p_category
		label = p_label if p_label != "" else p_key.capitalize()
		description = p_description
		last_modified = Time.get_datetime_string_from_system()

	func to_dict() -> Dictionary:
		return {
			"value": value,
			"last_modified": last_modified
		}

	func from_dict(d: Dictionary) -> void:
		if d.has("value"):
			value = d["value"]
		if d.has("last_modified"):
			last_modified = d["last_modified"]

var _settings: Dictionary = {} # String key -> Setting object

func _ready() -> void:
	_declare_defaults()
	_load_global_settings()

func _declare_defaults() -> void:
	# --- Paramètres GLOBAUX ---
	declare_setting("application/language", SettingType.STRING, "fr", SettingScope.GLOBAL, "Logiciel", "Langue", "Code de langue de l'interface (ex: fr, en)")
	declare_setting("nacelles/timestamp", SettingType.NUMBER, 0.0, SettingScope.GLOBAL, "Nacelles", "Version du fichier", "Timestamp de la version du fichier nacelles")
	declare_setting("nacelles/last_download", SettingType.STRING, "", SettingScope.GLOBAL, "Nacelles", "Dernier telechargement", "Date du dernier telechargement des nacelles")
	declare_setting("nacelles/count", SettingType.NUMBER, 0.0, SettingScope.GLOBAL, "Nacelles", "Nombre de nacelles", "Nombre de nacelles disponibles")
	
	# Catalogue global : nacelles (JSON)
	declare_setting("composition/nacelles", SettingType.JSON, _default_nacelles(), SettingScope.GLOBAL, "Composition", "Catalogue nacelles", "Définitions des nacelles disponibles")
	# Catalogue global : effets (JSON)
	declare_setting("composition/effects", SettingType.JSON, _default_effects(), SettingScope.GLOBAL, "Composition", "Catalogue effets", "Définitions des effets disponibles")
	# Catalogue global : payloads (JSON)
	declare_setting("composition/payloads", SettingType.JSON, _default_payloads(), SettingScope.GLOBAL, "Composition", "Catalogue payloads", "Types de payloads disponibles")
	
	# --- Paramètres PROJET (Scénographie) ---
	declare_setting("scenography/name", SettingType.STRING, "Ma Scénographie", SettingScope.PROJECT, "Général", "Nom de la scénographie", "Le nom identifiant ce projet")
	declare_setting("scenography/drone_count", SettingType.NUMBER, 10.0, SettingScope.PROJECT, "Drones", "Nombre de drones", "Nombre total de drones pour cette scénographie")
	
	# Composition projet
	declare_setting("composition/total_drones", SettingType.NUMBER, 0.0, SettingScope.PROJECT, "Composition", "Total drones", "Nombre total de drones déclaré")
	declare_setting("composition/constraints", SettingType.JSON, [], SettingScope.PROJECT, "Composition", "Contraintes de drones", "Liste des contraintes de drones (JSON)")
	
	# Paramètres techniques (Global)
	declare_setting("canvas/grid_visible", SettingType.BOOLEAN, true, SettingScope.GLOBAL, "Canvas", "Grille visible")
	declare_setting("canvas/snap_threshold", SettingType.NUMBER, 20.0, SettingScope.GLOBAL, "Canvas", "Seuil de magnétisme")


static func _default_nacelles() -> Array:
	return [
		{"id": "nacelle_standard", "name": "Standard", "compatible_drone_types": [0, 1]},
		{"id": "nacelle_pyrolight", "name": "PyroLight", "compatible_drone_types": [0]},
		{"id": "nacelle_lasermount", "name": "LaserMount", "compatible_drone_types": [1]},
	]


static func _default_effects() -> Array:
	return [
		{"id": "effect_pyro", "name": "Feu pyrotechnique", "category": 0, "compatible_nacelle_ids": ["nacelle_pyrolight", "nacelle_standard"], "variants": ["Bengale verte", "Bengale rouge", "Bengale blanche", "Flamme dorée"]},
		{"id": "effect_smoke", "name": "Fumée", "category": 1, "compatible_nacelle_ids": ["nacelle_pyrolight", "nacelle_standard"], "variants": ["Blanche", "Colorée"]},
		{"id": "effect_strobe", "name": "Stroboscopique", "category": 2, "compatible_nacelle_ids": ["nacelle_standard", "nacelle_lasermount"], "variants": []},
		{"id": "effect_laser", "name": "Laser", "category": 3, "compatible_nacelle_ids": ["nacelle_lasermount"], "variants": ["RGB", "Vert", "Rouge"]},
	]


static func _default_payloads() -> Array:
	return [
		{"id": "payload_laser", "name": "Laser"},
		{"id": "payload_smoke", "name": "Smoke"},
		{"id": "payload_strobe", "name": "Strobe"},
	]

func declare_setting(key: String, type: SettingType, default_value: Variant, scope: SettingScope = SettingScope.GLOBAL, category: String = "Général", label: String = "", description: String = "") -> void:
	if not _settings.has(key):
		_settings[key] = Setting.new(key, type, default_value, scope, category, label, description)

func get_setting(key: String) -> Variant:
	if _settings.has(key):
		return _settings[key].value
	push_warning("SettingsManager: paramètre inconnu '%s'" % key)
	return null

func set_setting(key: String, value: Variant) -> void:
	if _settings.has(key):
		var s: Setting = _settings[key]
		if s.value != value:
			s.value = value
			s.last_modified = Time.get_datetime_string_from_system()
			setting_changed.emit(key, value)
			if s.scope == SettingScope.GLOBAL:
				_save_global_settings()
	else:
		push_error("SettingsManager: impossible de modifier le paramètre inconnu '%s'" % key)

func get_settings_by_scope(scope: SettingScope) -> Array:
	var result: Array = []
	for key in _settings:
		var s: Setting = _settings[key]
		if s.scope == scope:
			result.append(s)
	return result

func get_categories_for_scope(scope: SettingScope) -> Array[String]:
	var cats: Dictionary = {}
	for key in _settings:
		var s: Setting = _settings[key]
		if s.scope == scope:
			cats[s.category] = true
	var keys = cats.keys()
	keys.sort()
	var result: Array[String] = []
	for k: String in keys:
		result.append(k)
	return result

func get_settings_by_category_and_scope(category: String, scope: SettingScope) -> Array:
	var result: Array = []
	for key in _settings:
		var s: Setting = _settings[key]
		if s.category == category and s.scope == scope:
			result.append(s)
	return result

# --- Sérialisation PROJET (pour GraphSerializer) ---

func get_project_settings_dict() -> Dictionary:
	var data := {}
	for key in _settings:
		var s: Setting = _settings[key]
		if s.scope == SettingScope.PROJECT:
			data[key] = s.to_dict()
	return data

func load_project_settings_dict(data: Dictionary) -> void:
	for key in data:
		if _settings.has(key) and _settings[key].scope == SettingScope.PROJECT:
			_settings[key].from_dict(data[key])
			setting_changed.emit(key, _settings[key].value)

# --- Persistance GLOBALE ---

func _save_global_settings() -> void:
	var data := {}
	for key: String in _settings:
		var s: Setting = _settings[key]
		if s.scope == SettingScope.GLOBAL:
			data[key] = s.to_dict()
	
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func _load_global_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return
	
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if not file:
		return
	
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(content) == OK:
		var data = json.data
		if data is Dictionary:
			for key: String in data:
				if _settings.has(key) and _settings[key].scope == SettingScope.GLOBAL:
					_settings[key].from_dict(data[key])
