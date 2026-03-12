class_name DroneProfile
extends Resource

## Profil de drones : décrit un lot de drones identiques avec leur équipement.

@export var id: StringName = &""
@export var name: String = "Nouveau profil"
@export var drone_type: int = FleetData.DroneType.DRONE_RIFF
@export var nacelle_id: StringName = &""
@export var effects: Array[Dictionary] = [] # [{effect_id: StringName, variant: String}]
@export var quantity: int = 1


static func create(
	p_name: String = "Nouveau profil",
	p_drone_type: int = FleetData.DroneType.DRONE_RIFF,
	p_nacelle_id: StringName = &"",
	p_effects: Array[Dictionary] = [],
	p_quantity: int = 1,
) -> DroneProfile:
	var data := DroneProfile.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.name = p_name
	data.drone_type = p_drone_type
	data.nacelle_id = p_nacelle_id
	data.effects = p_effects
	data.quantity = p_quantity
	return data


func get_drone_type_label() -> String:
	match drone_type:
		FleetData.DroneType.DRONE_RIFF: return "RIFF"
		FleetData.DroneType.DRONE_EMO: return "EMO"
		_: return "Inconnu"


func to_dict() -> Dictionary:
	var effects_arr: Array = []
	for e in effects:
		effects_arr.append({
			"effect_id": str(e.get("effect_id", "")),
			"variant": str(e.get("variant", "")),
		})
	return {
		"id": str(id),
		"name": name,
		"drone_type": drone_type,
		"nacelle_id": str(nacelle_id),
		"effects": effects_arr,
		"quantity": quantity,
	}


static func from_dict(d: Dictionary) -> DroneProfile:
	var p := DroneProfile.new()
	p.id = StringName(str(d.get("id", "")))
	p.name = str(d.get("name", "Nouveau profil"))
	p.drone_type = int(d.get("drone_type", 0))
	p.nacelle_id = StringName(str(d.get("nacelle_id", "")))
	var effects_raw = d.get("effects", [])
	p.effects = []
	for e in effects_raw:
		p.effects.append({
			"effect_id": StringName(str(e.get("effect_id", ""))),
			"variant": str(e.get("variant", "")),
		})
	p.quantity = int(d.get("quantity", 1))
	return p
