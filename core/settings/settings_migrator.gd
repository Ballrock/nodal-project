# res://core/settings/settings_migrator.gd
class_name SettingsMigrator
extends RefCounted

## Systeme de migration versionnee des settings persistees.
## Chaque migration est une fonction statique _migrate_vX_to_vY().

const CURRENT_VERSION := 2


static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("_version", 0))

	if version < 1:
		data = _migrate_v0_to_v1(data)

	if version < 2:
		data = _migrate_v1_to_v2(data)

	data["_version"] = CURRENT_VERSION
	return data


static func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
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

	data["_version"] = 1
	return data


static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	# --- Payloads : supprimer les anciennes donnees locales editables ---
	# Les payloads sont desormais telecharges via PayloadManager.
	if data.has("composition/payloads"):
		data.erase("composition/payloads")

	data["_version"] = 2
	return data


## Retourne les noms des contraintes qui referencent un item donne.
static func find_referencing_constraints(item_id: String, category_filter: int, constraints_data: Array) -> Array[String]:
	var referencing: Array[String] = []
	for d in constraints_data:
		if not d is Dictionary:
			continue
		var cat: int = int(d.get("category", -1))
		var val: String = str(d.get("value", ""))
		if cat == category_filter and val == item_id:
			referencing.append(str(d.get("name", "Contrainte")))
	return referencing
