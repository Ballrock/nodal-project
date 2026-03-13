# res://core/nacelle/nacelle_manager.gd
extends Node

## Gestionnaire de nacelles : chargement, téléchargement et cache.
## Autoload singleton (NacelleManager).

signal nacelles_loaded
signal nacelles_download_failed(error_message: String)
signal download_started
signal download_finished

const DOWNLOAD_URL = "https://storage.googleapis.com/droneslogsreader.appspot.com/hg_nacelles/nacelles.json"
const CACHE_DIR = "user://nacelle_cache/"
const CACHE_FILE = "user://nacelle_cache/nacelles.json"
const META_FILE = "user://nacelle_cache/nacelles_meta.json"

var _nacelles: Array[NacelleDefinition] = []
var _timestamp: int = 0
var _last_download_date: String = ""
var _is_loaded: bool = false
var _is_downloading: bool = false
var _http_request: HTTPRequest = null


func _ready() -> void:
	_ensure_cache_dir()
	_load_from_cache()


func get_nacelles() -> Array[NacelleDefinition]:
	return _nacelles


func get_nacelle_count() -> int:
	return _nacelles.size()


func is_loaded() -> bool:
	return _is_loaded


func is_downloading() -> bool:
	return _is_downloading


func get_timestamp() -> int:
	return _timestamp


func get_last_download_date() -> String:
	return _last_download_date


func get_last_download_date_formatted() -> String:
	if _last_download_date.is_empty():
		return "Jamais"
	return _last_download_date


func get_file_version_date() -> String:
	if _timestamp == 0:
		return "Inconnue"
	var dt := Time.get_datetime_dict_from_unix_time(_timestamp)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]]


func find_nacelle_by_name(nacelle_name: String) -> NacelleDefinition:
	for n in _nacelles:
		if n.name == nacelle_name:
			return n
	return null


func download_nacelles() -> void:
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
		nacelles_download_failed.emit(msg)
		download_finished.emit()


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_downloading = false

	if _http_request:
		_http_request.queue_free()
		_http_request = null

	if result != HTTPRequest.RESULT_SUCCESS:
		var msg := "Echec du telechargement (result: %d)" % result
		nacelles_download_failed.emit(msg)
		download_finished.emit()
		return

	if response_code != 200:
		var msg := "Reponse HTTP %d" % response_code
		nacelles_download_failed.emit(msg)
		download_finished.emit()
		return

	var json_text := body.get_string_from_utf8()

	# Valider le JSON avant de sauvegarder
	var json := JSON.new()
	if json.parse(json_text) != OK:
		var msg := "JSON invalide: %s" % json.get_error_message()
		nacelles_download_failed.emit(msg)
		download_finished.emit()
		return

	var data = json.data
	if not data is Dictionary or not data.has("nacelles"):
		nacelles_download_failed.emit("Format de donnees invalide (pas de cle 'nacelles')")
		download_finished.emit()
		return

	# Sauvegarder le fichier en cache
	_ensure_cache_dir()
	var file := FileAccess.open(CACHE_FILE, FileAccess.WRITE)
	if not file:
		nacelles_download_failed.emit("Impossible d'ecrire le fichier cache")
		download_finished.emit()
		return

	file.store_string(json_text)
	file.close()

	# Mettre a jour la date de telechargement
	_last_download_date = Time.get_datetime_string_from_system(true)
	_save_download_meta()

	# Charger les nouvelles donnees
	_parse_nacelles_data(data)
	_is_loaded = true
	nacelles_loaded.emit()
	download_finished.emit()

	# Mettre a jour le SettingsManager
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
		push_warning("NacelleManager: fichier cache invalide")
		return

	var data = json.data
	if data is Dictionary and data.has("nacelles"):
		_parse_nacelles_data(data)
		_is_loaded = true
		_sync_to_settings()
		nacelles_loaded.emit()


func _parse_nacelles_data(data: Dictionary) -> void:
	_nacelles.clear()
	_timestamp = int(data.get("timestamp", 0))

	var nacelles_array = data.get("nacelles", [])
	for entry in nacelles_array:
		if entry is Dictionary:
			var n := NacelleDefinition.from_download_dict(entry)
			_nacelles.append(n)


func _save_download_meta() -> void:
	var meta := {"lastDownload": _last_download_date}
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


func _sync_to_settings() -> void:
	# Mettre a jour les parametres dans le SettingsManager pour l'affichage
	SettingsManager.set_setting("nacelles/timestamp", _timestamp)
	SettingsManager.set_setting("nacelles/last_download", _last_download_date)
	SettingsManager.set_setting("nacelles/count", _nacelles.size())

	# Mettre a jour le catalogue composition/nacelles
	var catalog: Array = []
	for n in _nacelles:
		catalog.append({
			"id": n.name,
			"name": n.name,
			"compatible_drone_types": n.get_compatible_drone_type_indices(),
		})
	SettingsManager.set_setting("composition/nacelles", catalog)
