class_name LinkData
extends Resource

## Données d'un câble reliant un slot de sortie à un slot d'entrée.

@export var id: StringName = &""
@export var source_box_id: StringName = &""
@export var source_slot_id: StringName = &""
@export var target_box_id: StringName = &""
@export var target_slot_id: StringName = &""


## Crée un LinkData avec un identifiant unique.
static func create(
	p_source_box_id: StringName,
	p_source_slot_id: StringName,
	p_target_box_id: StringName,
	p_target_slot_id: StringName
) -> LinkData:
	var data := LinkData.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.source_box_id = p_source_box_id
	data.source_slot_id = p_source_slot_id
	data.target_box_id = p_target_box_id
	data.target_slot_id = p_target_slot_id
	return data
