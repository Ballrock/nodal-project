class_name DroneConstraint
extends Resource

## Contrainte de drones : filtre générique.
## Chaque contrainte = 1 catégorie + 1 valeur + 1 quantité.

enum ConstraintCategory {
	DRONE_TYPE = 0,   ## Valeur: "0" (RIFF) ou "1" (EMO)
	NACELLE = 1,      ## Valeur: id nacelle (ex: "nacelle_lasermount")
	PAYLOAD = 2,      ## Valeur: id payload (ex: "payload_laser")
	PYRO_EFFECT = 3,  ## Valeur: "effect_id::variant" ou "effect_id" si pas de variante
}

@export var id: StringName = &""
@export var name: String = "Nouvelle contrainte"
@export var category: int = ConstraintCategory.DRONE_TYPE
@export var value: String = ""
@export var quantity: int = 1


static func create(
	p_name: String = "Nouvelle contrainte",
	p_category: int = ConstraintCategory.DRONE_TYPE,
	p_value: String = "",
	p_quantity: int = 1,
) -> DroneConstraint:
	var data := DroneConstraint.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.name = p_name
	data.category = p_category
	data.value = p_value
	data.quantity = p_quantity
	return data


func get_category_label() -> String:
	match category:
		ConstraintCategory.DRONE_TYPE: return "Type drone"
		ConstraintCategory.NACELLE: return "Nacelle"
		ConstraintCategory.PAYLOAD: return "Payload"
		ConstraintCategory.PYRO_EFFECT: return "Effet Pyro"
		_: return "Inconnu"


## Retourne un libellé humain de la valeur.
func get_value_display_label(nacelles_catalog: Array, effects_catalog: Array) -> String:
	match category:
		ConstraintCategory.DRONE_TYPE:
			var type_val := int(value)
			if type_val == FleetData.DroneType.DRONE_RIFF:
				return "RIFF"
			elif type_val == FleetData.DroneType.DRONE_EMO:
				return "EMO"
			return value
		ConstraintCategory.NACELLE:
			for n in nacelles_catalog:
				if str(n.get("id", "")) == value:
					return str(n.get("name", value))
			return value
		ConstraintCategory.PAYLOAD:
			var payloads_catalog: Array = SettingsManager.get_setting("composition/payloads")
			if payloads_catalog == null:
				payloads_catalog = []
			for pl in payloads_catalog:
				if str(pl.get("id", "")) == value:
					return str(pl.get("name", value))
			return value
		ConstraintCategory.PYRO_EFFECT:
			var parts := value.split("::", false)
			var effect_id: String = parts[0] if parts.size() > 0 else ""
			var variant: String = parts[1] if parts.size() > 1 else ""
			for e in effects_catalog:
				if str(e.get("id", "")) == effect_id:
					var ename: String = str(e.get("name", ""))
					if variant != "":
						return "%s — %s" % [ename, variant]
					return ename
			if variant != "":
				return "%s — %s" % [effect_id, variant]
			return effect_id
		_:
			return value


## Résout les sous-contraintes implicites.
## Retourne {implied_nacelle_ids: Array[String], implied_drone_types: Array[int],
##           nacelle_resolved: bool, type_resolved: bool,
##           implied_nacelle_names: Array[String], implied_drone_type_labels: Array[String]}
func resolve_implications(nacelles_catalog: Array, effects_catalog: Array) -> Dictionary:
	var result := {
		"implied_nacelle_ids": [] as Array[String],
		"implied_drone_types": [] as Array[int],
		"nacelle_resolved": false,
		"type_resolved": false,
		"implied_nacelle_names": [] as Array[String],
		"implied_drone_type_labels": [] as Array[String],
	}

	match category:
		ConstraintCategory.DRONE_TYPE:
			result["implied_drone_types"] = [int(value)]
			result["type_resolved"] = true
			result["nacelle_resolved"] = true  # N/A
			var label := "RIFF" if int(value) == 0 else "EMO"
			result["implied_drone_type_labels"] = [label]
			return result

		ConstraintCategory.NACELLE:
			result["implied_nacelle_ids"] = [value]
			result["nacelle_resolved"] = true
			# Find nacelle name
			for n in nacelles_catalog:
				if str(n.get("id", "")) == value:
					result["implied_nacelle_names"] = [str(n.get("name", value))]
					# Resolve drone types from nacelle
					var compatible_types = n.get("compatible_drone_types", [])
					for t in compatible_types:
						var ti := int(t)
						if ti not in result["implied_drone_types"]:
							result["implied_drone_types"].append(ti)
					break
			result["type_resolved"] = result["implied_drone_types"].size() == 1
			for dt in result["implied_drone_types"]:
				result["implied_drone_type_labels"].append("RIFF" if dt == 0 else "EMO")
			return result

		ConstraintCategory.PAYLOAD:
			# Resout les implications depuis le catalogue payloads (telecharge)
			var payloads_catalog: Array = SettingsManager.get_setting("composition/payloads")
			if payloads_catalog == null:
				payloads_catalog = []
			for pl in payloads_catalog:
				if str(pl.get("id", "")) == value:
					# Types drones depuis actif_riff / actif_emo
					if pl.get("actif_riff", false):
						if 0 not in result["implied_drone_types"]:
							result["implied_drone_types"].append(0)
					if pl.get("actif_emo", false):
						if 1 not in result["implied_drone_types"]:
							result["implied_drone_types"].append(1)
					result["type_resolved"] = result["implied_drone_types"].size() == 1
					result["nacelle_resolved"] = true  # N/A pour les payloads
					for dt in result["implied_drone_types"]:
						result["implied_drone_type_labels"].append("RIFF" if dt == 0 else "EMO")
					break
			return result

		ConstraintCategory.PYRO_EFFECT:
			var parts := value.split("::", false)
			var effect_id: String = parts[0] if parts.size() > 0 else ""
			# Find compatible nacelles from effect
			for e in effects_catalog:
				if str(e.get("id", "")) == effect_id:
					var compatible_nacelle_ids = e.get("compatible_nacelle_ids", [])
					for nid in compatible_nacelle_ids:
						var nid_str := str(nid)
						if nid_str not in result["implied_nacelle_ids"]:
							result["implied_nacelle_ids"].append(nid_str)
					break
			result["nacelle_resolved"] = result["implied_nacelle_ids"].size() == 1
			# Find nacelle names and resolve drone types
			var all_drone_types: Array[int] = []
			for nid_str in result["implied_nacelle_ids"]:
				for n in nacelles_catalog:
					if str(n.get("id", "")) == nid_str:
						result["implied_nacelle_names"].append(str(n.get("name", nid_str)))
						var compat = n.get("compatible_drone_types", [])
						for t in compat:
							var ti := int(t)
							if ti not in all_drone_types:
								all_drone_types.append(ti)
						break
			result["implied_drone_types"] = all_drone_types
			result["type_resolved"] = all_drone_types.size() == 1
			for dt in all_drone_types:
				result["implied_drone_type_labels"].append("RIFF" if dt == 0 else "EMO")
			return result

	return result


func to_dict() -> Dictionary:
	return {
		"id": str(id),
		"name": name,
		"category": category,
		"value": value,
		"quantity": quantity,
	}


static func from_dict(d: Dictionary) -> DroneConstraint:
	var p := DroneConstraint.new()
	p.id = StringName(str(d.get("id", "")))
	p.name = str(d.get("name", "Nouvelle contrainte"))
	p.quantity = int(d.get("quantity", 1))

	# New format: category + value
	if d.has("category"):
		p.category = int(d.get("category", 0))
		p.value = str(d.get("value", ""))
	else:
		# Legacy migration: old format with drone_type, nacelle_id, effects
		var old_effects = d.get("effects", [])
		if old_effects is Array and old_effects.size() > 0:
			var first_effect: Dictionary = old_effects[0]
			var eid := str(first_effect.get("effect_id", ""))
			var variant := str(first_effect.get("variant", ""))
			p.category = ConstraintCategory.PYRO_EFFECT
			if variant != "":
				p.value = "%s::%s" % [eid, variant]
			else:
				p.value = eid
		elif d.has("nacelle_id") and str(d.get("nacelle_id", "")) != "":
			p.category = ConstraintCategory.NACELLE
			p.value = str(d.get("nacelle_id", ""))
		else:
			p.category = ConstraintCategory.DRONE_TYPE
			p.value = str(int(d.get("drone_type", 0)))

	return p
