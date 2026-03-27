# res://core/pyro_effect/pyro_effect_manager.gd
extends Node

## Gestionnaire d'effets pyro : chargement, telechargement et cache.
## Autoload singleton (PyroEffectManager).

signal pyro_effects_loaded
signal pyro_effects_download_failed(error_message: String)
signal download_started
signal download_finished
signal update_check_completed(update_available: bool)
signal update_check_failed

const DOWNLOAD_URL = "https://firebasestorage.googleapis.com/v0/b/droneslogsreader.appspot.com/o/hg_pyro_effects%2Fexport_pyro_data.json?alt=media"
const METADATA_URL = "https://firebasestorage.googleapis.com/v0/b/droneslogsreader.appspot.com/o/hg_pyro_effects%2Fexport_pyro_data.json"
const CACHE_DIR = "user://pyro_effect_cache/"
const CACHE_FILE = "user://pyro_effect_cache/pyro_effects.json"
const META_FILE = "user://pyro_effect_cache/pyro_effects_meta.json"

var _pyro_effects: Array[PyroEffectDefinition] = []
var _file_version_date: String = ""
var _last_download_date: String = ""
var _server_updated: String = ""
var _is_loaded: bool = false
var _is_downloading: bool = false
var _is_checking_update: bool = false
var _update_available: bool = false
var _http_request: HTTPRequest = null
var _http_meta_request: HTTPRequest = null
var _http_update_check: HTTPRequest = null


func _ready() -> void:
	_ensure_cache_dir()
	_load_from_cache()


func get_pyro_effects() -> Array[PyroEffectDefinition]:
	return _pyro_effects


func get_pyro_effect_count() -> int:
	return _pyro_effects.size()


func is_loaded() -> bool:
	return _is_loaded


func is_downloading() -> bool:
	return _is_downloading


func is_update_available() -> bool:
	return _update_available


func is_checking_update() -> bool:
	return _is_checking_update


func get_server_updated() -> String:
	return _server_updated


func get_last_download_date() -> String:
	return _last_download_date


func get_last_download_date_formatted() -> String:
	if _last_download_date.is_empty():
		return "Jamais"
	return _last_download_date


func get_file_version_date() -> String:
	if _file_version_date.is_empty():
		return "Inconnue"
	return _file_version_date


func find_by_name(effect_name: String) -> PyroEffectDefinition:
	for e in _pyro_effects:
		if e.name == effect_name:
			return e
	return null


func get_unique_types() -> Array[String]:
	return PyroEffectDefinition.get_unique_types(_pyro_effects)


func check_for_update() -> void:
	if _is_checking_update:
		return

	_is_checking_update = true

	if _http_update_check:
		_http_update_check.queue_free()

	_http_update_check = HTTPRequest.new()
	add_child(_http_update_check)
	_http_update_check.request_completed.connect(_on_update_check_completed)

	var error := _http_update_check.request(METADATA_URL)
	if error != OK:
		_is_checking_update = false
		_http_update_check.queue_free()
		_http_update_check = null
		update_check_failed.emit()


func _on_update_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_checking_update = false

	if _http_update_check:
		_http_update_check.queue_free()
		_http_update_check = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		update_check_failed.emit()
		return

	var json_text := body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		update_check_failed.emit()
		return

	var meta = json.data
	if not meta is Dictionary:
		update_check_failed.emit()
		return

	var remote_updated: String = str(meta.get("updated", ""))
	if remote_updated.is_empty():
		update_check_failed.emit()
		return

	# Comparer avec la version locale
	if _server_updated.is_empty() or remote_updated != _server_updated:
		_update_available = true
	else:
		_update_available = false

	update_check_completed.emit(_update_available)


func download_pyro_effects() -> void:
	if _is_downloading:
		return

	_is_downloading = true
	download_started.emit()

	if _http_request:
		_http_request.queue_free()

	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_download_completed)

	var error := _http_request.request(DOWNLOAD_URL)
	if error != OK:
		_is_downloading = false
		_http_request.queue_free()
		_http_request = null
		var msg := "Erreur lors de la requete HTTP: %s" % error_string(error)
		pyro_effects_download_failed.emit(msg)
		download_finished.emit()


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_downloading = false

	if _http_request:
		_http_request.queue_free()
		_http_request = null

	if result != HTTPRequest.RESULT_SUCCESS:
		var msg := "Echec du telechargement (result: %d)" % result
		pyro_effects_download_failed.emit(msg)
		download_finished.emit()
		return

	if response_code != 200:
		var msg := "Reponse HTTP %d" % response_code
		pyro_effects_download_failed.emit(msg)
		download_finished.emit()
		return

	var json_text := body.get_string_from_utf8()

	# Valider le JSON avant de sauvegarder
	var json := JSON.new()
	if json.parse(json_text) != OK:
		var msg := "JSON invalide: %s" % json.get_error_message()
		pyro_effects_download_failed.emit(msg)
		download_finished.emit()
		return

	var data = json.data
	if not data is Array:
		pyro_effects_download_failed.emit("Format de donnees invalide (le JSON doit etre un tableau)")
		download_finished.emit()
		return

	# Sauvegarder le fichier en cache
	_ensure_cache_dir()
	var file := FileAccess.open(CACHE_FILE, FileAccess.WRITE)
	if not file:
		pyro_effects_download_failed.emit("Impossible d'ecrire le fichier cache")
		download_finished.emit()
		return

	file.store_string(json_text)
	file.close()

	# Charger les nouvelles donnees
	_parse_pyro_effects_data(data)
	_is_loaded = true
	_update_available = false

	# Lancer le telechargement des metadonnees pour la date de version
	_download_metadata()

	# Mettre a jour la date de telechargement
	_last_download_date = Time.get_datetime_string_from_system(true)
	_save_download_meta()

	pyro_effects_loaded.emit()
	download_finished.emit()

	# Mettre a jour le SettingsManager
	_sync_to_settings()


func _download_metadata() -> void:
	if _http_meta_request:
		_http_meta_request.queue_free()

	_http_meta_request = HTTPRequest.new()
	add_child(_http_meta_request)
	_http_meta_request.request_completed.connect(_on_metadata_completed)

	var error := _http_meta_request.request(METADATA_URL)
	if error != OK:
		if _http_meta_request:
			_http_meta_request.queue_free()
			_http_meta_request = null


func _on_metadata_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http_meta_request:
		_http_meta_request.queue_free()
		_http_meta_request = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return

	var json_text := body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return

	var meta = json.data
	if not meta is Dictionary:
		return

	# timeCreated est la date de mise a jour du fichier
	var time_created: String = str(meta.get("timeCreated", ""))
	if not time_created.is_empty():
		_file_version_date = time_created
	# updated est la date de derniere modification sur le serveur
	var updated: String = str(meta.get("updated", ""))
	if not updated.is_empty():
		_server_updated = updated
	_save_download_meta()
	_sync_to_settings()


func _ensure_cache_dir() -> void:
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)


func _load_from_cache() -> void:
	_load_download_meta()

	if not FileAccess.file_exists(CACHE_FILE):
		return

	var file := FileAccess.open(CACHE_FILE, FileAccess.READ)
	if not file:
		return

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) != OK:
		push_warning("PyroEffectManager: fichier cache invalide")
		return

	var data = json.data
	if data is Array:
		_parse_pyro_effects_data(data)
		_is_loaded = true
		_sync_to_settings()
		pyro_effects_loaded.emit()


func _parse_pyro_effects_data(data: Array) -> void:
	_pyro_effects.clear()
	for entry in data:
		if entry is Dictionary:
			var e := PyroEffectDefinition.from_download_dict(entry)
			_pyro_effects.append(e)


func _save_download_meta() -> void:
	var meta := {
		"lastDownload": _last_download_date,
		"fileVersionDate": _file_version_date,
		"serverUpdated": _server_updated,
	}
	var file := FileAccess.open(META_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta, "\t"))
		file.close()


func _load_download_meta() -> void:
	if not FileAccess.file_exists(META_FILE):
		return

	var file := FileAccess.open(META_FILE, FileAccess.READ)
	if not file:
		return

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		_last_download_date = str(json.data.get("lastDownload", ""))
		_file_version_date = str(json.data.get("fileVersionDate", ""))
		_server_updated = str(json.data.get("serverUpdated", ""))


func _sync_to_settings() -> void:
	SettingsManager.set_setting("pyro_effects/file_version_date", _file_version_date)
	SettingsManager.set_setting("pyro_effects/last_download", _last_download_date)
	SettingsManager.set_setting("pyro_effects/count", _pyro_effects.size())

	# Mettre a jour le catalogue composition/pyro_effects
	var catalog: Array = []
	for e in _pyro_effects:
		catalog.append({
			"id": str(e.id),
			"name": e.name,
			"type": e.type,
		})
	SettingsManager.set_setting("composition/pyro_effects", catalog)

	# Mettre a jour la liste des types uniques
	var types := get_unique_types()
	SettingsManager.set_setting("pyro_effects/types", types)
