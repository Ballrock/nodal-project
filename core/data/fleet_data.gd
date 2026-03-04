class_name FleetData
extends Resource

## Données d'une flotte de drones.

enum DroneType { DRONE_RIFF = 0, DRONE_EMO = 1 }

@export var id: StringName = &""
@export var name: String = "Nouvelle flotte"
@export var drone_type: int = DroneType.DRONE_RIFF
@export var drone_count: int = 1


## Crée un FleetData avec un identifiant unique.
static func create(
	p_name: String = "Nouvelle flotte",
	p_drone_type: int = DroneType.DRONE_RIFF,
	p_drone_count: int = 1
) -> FleetData:
	var data := FleetData.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.name = p_name
	data.drone_type = p_drone_type
	data.drone_count = p_drone_count
	return data


## Retourne le nom lisible du type de drone.
func get_drone_type_label() -> String:
	match drone_type:
		DroneType.DRONE_RIFF:
			return "RIFF"
		DroneType.DRONE_EMO:
			return "EMO"
		_:
			return "Inconnu"
