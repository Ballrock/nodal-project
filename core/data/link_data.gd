class_name LinkData
extends Resource

## Données d'un câble reliant un slot de sortie à un slot d'entrée.

@export var id: StringName = &""
@export var source_figure_id: StringName = &""
@export var source_slot_id: StringName = &""
@export var target_figure_id: StringName = &""
@export var target_slot_id: StringName = &""
@export var is_locked: bool = false


## Crée un LinkData avec un identifiant unique.
static func create(
	p_source_figure_id: StringName,
	p_source_slot_id: StringName,
	p_target_figure_id: StringName,
	p_target_slot_id: StringName,
	p_is_locked: bool = false
) -> LinkData:
	var data := LinkData.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.source_figure_id = p_source_figure_id
	data.source_slot_id = p_source_slot_id
	data.target_figure_id = p_target_figure_id
	data.target_slot_id = p_target_slot_id
	data.is_locked = p_is_locked
	return data
