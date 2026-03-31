# res://core/settings/settings_migrator.gd
class_name SettingsMigrator
extends RefCounted

## Systeme de migration versionnee des settings persistees.
## Chaque migration est une fonction statique _migrate_vX_to_vY().

const CURRENT_VERSION := 1


static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("_version", 0))

	if version < 1:
		data = _migrate_v0_to_v1(data)

	# Futures migrations :
	# if version < 2:
	#     data = _migrate_v1_to_v2(data)

	data["_version"] = CURRENT_VERSION
	return data


static func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	# --- Payloads : ajout SuperLight, correction Laser ---
	var payloads_entry: Dictionary = data.get("composition/payloads", {})
	var persisted_payloads: Array = payloads_entry.get("value", [])

	var existing_ids: Dictionary = {}
	for pl in persisted_payloads:
		if pl is Dictionary:
			existing_ids[str(pl.get("id", ""))] = true

	# Payloads attendus en v1 (autonome, pas de reference a l'autoload)
	var v1_payloads: Array = [
		{"id": "payload_laser", "name": "Laser", "compatible_drone_types": [0], "compatible_nacelle_ids": ["nacelle_lasermount"]},
		{"id": "payload_smoke", "name": "Smoke", "compatible_drone_types": [], "compatible_nacelle_ids": []},
		{"id": "payload_strobe", "name": "Strobe", "compatible_drone_types": [], "compatible_nacelle_ids": []},
		{"id": "payload_superlight", "name": "SuperLight", "compatible_drone_types": [0], "compatible_nacelle_ids": []},
	]
	# Ajouter les payloads par defaut manquants
	for default_pl in v1_payloads:
		var default_id: String = str(default_pl.get("id", ""))
		if not existing_ids.has(default_id):
			persisted_payloads.append(default_pl.duplicate(true))

	# Corriger payload_laser
	for pl in persisted_payloads:
		if pl is Dictionary and str(pl.get("id", "")) == "payload_laser":
			pl["compatible_drone_types"] = [0]
			pl["compatible_nacelle_ids"] = ["nacelle_lasermount"]

	payloads_entry["value"] = persisted_payloads
	payloads_entry["last_modified"] = Time.get_datetime_string_from_system()
	data["composition/payloads"] = payloads_entry

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
