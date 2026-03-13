class_name NacelleDefinition
extends Resource

## Definition d'un type de nacelle (catalogue global).
## Modele enrichi base sur le format de donnees Unreal.

@export var id: StringName = &""
@export var name: String = ""
@export var compatible_drone_types: Array[int] = []

# Champs enrichis depuis le format de telechargement
@export var type_drone: String = ""     # "EMO", "RIFF"
@export var mount_type: String = ""     # "dessus", "dessous", "suspension"
@export var weight: int = 0             # Poids en grammes
@export var effect_count: int = 0       # Nombre d'effets pyro
@export var effects: Array[Dictionary] = []  # [{channel, angleH, angleP}]


static func create(p_name: String, p_compatible_types: Array[int] = []) -> NacelleDefinition:
	var data := NacelleDefinition.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.name = p_name
	data.compatible_drone_types = p_compatible_types
	return data


func to_dict() -> Dictionary:
	return {
		"id": str(id),
		"name": name,
		"compatible_drone_types": compatible_drone_types,
		"typeDrone": type_drone,
		"type": mount_type,
		"poids": weight,
		"nbEffets": effect_count,
		"effects": effects,
	}


static func from_dict(d: Dictionary) -> NacelleDefinition:
	var n := NacelleDefinition.new()
	n.id = StringName(str(d.get("id", "")))
	n.name = str(d.get("name", ""))
	var types = d.get("compatible_drone_types", [])
	n.compatible_drone_types = []
	for t in types:
		n.compatible_drone_types.append(int(t))
	n.type_drone = str(d.get("typeDrone", ""))
	n.mount_type = str(d.get("type", ""))
	n.weight = int(d.get("poids", 0))
	n.effect_count = int(d.get("nbEffets", 0))
	n.effects = []
	for e in d.get("effects", []):
		if e is Dictionary:
			n.effects.append(e)
	return n


## Cree une NacelleDefinition depuis le format JSON telecharge (format serveur).
static func from_download_dict(d: Dictionary) -> NacelleDefinition:
	var n := NacelleDefinition.new()
	n.name = str(d.get("name", ""))
	n.id = StringName(n.name)
	n.type_drone = str(d.get("typeDrone", ""))
	n.mount_type = str(d.get("type", ""))
	n.weight = int(d.get("poids", 0))
	n.effect_count = int(d.get("nbEffets", 0))
	n.effects = []
	for e in d.get("effects", []):
		if e is Dictionary:
			n.effects.append({
				"channel": int(e.get("channel", 0)),
				"angleH": float(e.get("angleH", 0.0)),
				"angleP": float(e.get("angleP", 0.0)),
			})
	# Deduire les types de drones compatibles depuis typeDrone
	n.compatible_drone_types = n.get_compatible_drone_type_indices()
	return n


## Retourne les indices de types de drones compatibles (0=RIFF, 1=EMO).
func get_compatible_drone_type_indices() -> Array[int]:
	var result: Array[int] = []
	match type_drone.to_upper():
		"RIFF":
			result.append(0)
		"EMO":
			result.append(1)
		_:
			# Si inconnu, compatible avec les deux
			if not compatible_drone_types.is_empty():
				return compatible_drone_types
			result.append(0)
			result.append(1)
	return result


## Retourne un label lisible du type de montage.
func get_mount_type_label() -> String:
	match mount_type:
		"dessus":
			return "Dessus"
		"dessous":
			return "Dessous"
		"suspension":
			return "Suspension"
		_:
			return mount_type.capitalize() if not mount_type.is_empty() else "N/A"
