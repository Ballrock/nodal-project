class_name NacelleDefinition
extends Resource

## Définition d'un type de nacelle (catalogue global).

@export var id: StringName = &""
@export var name: String = ""
@export var compatible_drone_types: Array[int] = []


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
	}


static func from_dict(d: Dictionary) -> NacelleDefinition:
	var n := NacelleDefinition.new()
	n.id = StringName(str(d.get("id", "")))
	n.name = str(d.get("name", ""))
	var types = d.get("compatible_drone_types", [])
	n.compatible_drone_types = []
	for t in types:
		n.compatible_drone_types.append(int(t))
	return n
