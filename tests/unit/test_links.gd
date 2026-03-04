extends GutTest

## Tests unitaires pour les opérations sur les liens (LinksLayer).

const MainScene := preload("res://ui/main/main.tscn")

var _main: Control = null

func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame

func _workspace() -> Node:
	return _main.get_node("%Workspace")

func _links_layer() -> LinksLayer:
	return _workspace().get_node("%LinksLayer") as LinksLayer

func _figures_by_id() -> Dictionary:
	return _main.get("_figures_by_id") as Dictionary

func _link_count() -> int:
	return _links_layer().get_all_link_data().size()

func _get_standard_figures() -> Array[Figure]:
	var result: Array[Figure] = []
	var figs = _figures_by_id()
	for id in figs:
		var figure = figs[id]
		if not figure.is_fleet_figure:
			result.append(figure)
	return result

func _create_link_between(src_figure: Figure, src_slot_data: SlotData, tgt_figure: Figure, tgt_slot_data: SlotData) -> LinkData:
	var src_slot := src_figure.find_slot_by_id(src_slot_data.id)
	var tgt_slot := tgt_figure.find_slot_by_id(tgt_slot_data.id)
	if src_slot == null or tgt_slot == null:
		return null
	var link := LinkData.create(src_figure.data.id, src_slot_data.id, tgt_figure.data.id, tgt_slot_data.id)
	_links_layer().add_link(src_slot, tgt_slot, link)
	return link

# ══════════════════════════════════════════════════════════
# TESTS
# ══════════════════════════════════════════════════════════

func test_no_links_at_startup() -> void:
	assert_eq(_link_count(), 0)

func test_standard_figures_exist() -> void:
	assert_gte(_get_standard_figures().size(), 2)

func test_create_link_between_two_figures() -> void:
	var figures := _get_standard_figures()
	var figure_a := figures[0]
	var figure_b := figures[1]
	var link := _create_link_between(figure_a, figure_a.data.output_slots[0], figure_b, figure_b.data.input_slots[0])
	assert_eq(_link_count(), 1)

func test_rule1_output_can_connect_to_different_figures() -> void:
	var figures := _get_standard_figures()
	var figure_a := figures[0]
	var figure_b := figures[1]
	var figure_c = _main.call("_spawn_extra_figure", "BoxC", Vector2(1100, 200), 2, 2) if _main.has_method("_spawn_extra_figure") else _main.call("_spawn_figure", "BoxC", Vector2(1100, 200), 2, 2)
	
	_create_link_between(figure_a, figure_a.data.output_slots[0], figure_b, figure_b.data.input_slots[0])
	_create_link_between(figure_a, figure_a.data.output_slots[0], figure_c, figure_c.data.input_slots[0])
	assert_eq(_link_count(), 2)

func test_rule2_replace_link_same_output_same_target_figure() -> void:
	var figures := _get_standard_figures()
	var figure_a := figures[0]
	var figure_b := figures[1]
	
	if figure_b.data.input_slots.size() < 2:
		figure_b.call("_on_add_slot_pair")
		
	var link1 := _create_link_between(figure_a, figure_a.data.output_slots[0], figure_b, figure_b.data.input_slots[0])
	assert_eq(_link_count(), 1)
	
	var src_slot := figure_a.find_slot_by_id(figure_a.data.output_slots[0].id)
	var new_tgt_slot := figure_b.find_slot_by_id(figure_b.data.input_slots[1].id)
	_main.call("_on_link_replace_requested", src_slot, new_tgt_slot, link1)
	
	assert_eq(_link_count(), 1)
	var remaining = _links_layer().get_all_link_data()[0]
	assert_eq(remaining.target_slot_id, figure_b.data.input_slots[1].id)

func test_remove_link_by_slot_id() -> void:
	var figures := _get_standard_figures()
	_create_link_between(figures[0], figures[0].data.output_slots[0], figures[1], figures[1].data.input_slots[0])
	_links_layer().remove_links_for_slot_id(figures[0].data.output_slots[0].id)
	assert_eq(_link_count(), 0)
