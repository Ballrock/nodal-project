class_name SlotData
extends Resource

## Données d'un emplacement de liaison (entrée ou sortie).

enum Direction { SLOT_INPUT = 0, SLOT_OUTPUT = 1 }

@export var id: StringName = &""
@export var label: String = ""
@export var direction: int = Direction.SLOT_INPUT
@export var index: int = 0


## Crée un SlotData avec un identifiant unique.
static func create(p_label: String, p_direction: int, p_index: int) -> SlotData:
	var data := SlotData.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.label = p_label
	data.direction = p_direction
	data.index = p_index
	return data
