# res://core/settings/migrations/migration_20260401000000.gd
extends MigrationBase

## Migration initiale : nettoyage des donnees legacy.


func get_version() -> int:
	return 20260401000000


func get_description() -> String:
	return "Cleanup legacy data: fix nacelle LaserMount, remove local payloads"


func up(data: Dictionary) -> Dictionary:
	# --- Payloads : supprimer les anciennes donnees locales (desormais telecharges) ---
	if data.has("composition/payloads"):
		data.erase("composition/payloads")

	# --- Nacelles : corriger lasermount si present ---
	var nacelles_entry: Dictionary = data.get("composition/nacelles", {})
	var persisted_nacelles: Array = nacelles_entry.get("value", [])
	for nac in persisted_nacelles:
		if nac is Dictionary and str(nac.get("id", "")) == "nacelle_lasermount":
			nac["compatible_drone_types"] = [0]
	if not persisted_nacelles.is_empty():
		nacelles_entry["value"] = persisted_nacelles
		nacelles_entry["last_modified"] = Time.get_datetime_string_from_system()
		data["composition/nacelles"] = nacelles_entry

	return data
