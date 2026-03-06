extends GutTest

## Tests de la logique d'orchestration de Main (spawning, deletion logic).

const MainScene := preload("res://ui/main/main.tscn")

var _main: Control = null

func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame


func _get_figures_by_id() -> Dictionary:
	return _main.get("_figures_by_id") as Dictionary


func _get_links_layer() -> LinksLayer:
	return _main.get_node("%Workspace/%LinksLayer") as LinksLayer


func test_spawn_figure_adds_to_registry() -> void:
	var count_before := _get_figures_by_id().size()
	_main.call("_add_figure")
	assert_eq(_get_figures_by_id().size(), count_before + 1)


func test_slot_deletion_removes_symmetric_pair() -> void:
	# Spawn une figure avec 2 paires (2 in, 2 out)
	var fig: Figure = _main.call("_spawn_figure", "DelTest", Vector2.ZERO, 2, 2)
	assert_eq(fig.data.input_slots.size(), 2)
	assert_eq(fig.data.output_slots.size(), 2)
	
	# Supprime l'input à l'index 0
	var slot_to_del = fig.get_all_slots()[0] # [0]=in0, [1]=in1, [2]=out0, [3]=out1
	assert_eq(slot_to_del.data.direction, SlotData.Direction.SLOT_INPUT)
	
	_main.call("_on_slot_delete", slot_to_del, fig)
	
	assert_eq(fig.data.input_slots.size(), 1, "Doit rester 1 input")
	assert_eq(fig.data.output_slots.size(), 1, "Doit rester 1 output (suppression symétrique)")
	assert_eq(fig.data.input_slots[0].label, "input_0", "Renumérotation")


func test_slot_deletion_cleans_links() -> void:
	var fig_a: Figure = _main.call("_spawn_figure", "A", Vector2.ZERO, 1, 1)
	var fig_b: Figure = _main.call("_spawn_figure", "B", Vector2(200, 0), 1, 1)
	
	var out_a = fig_a.get_all_slots()[1]
	var in_b = fig_b.get_all_slots()[0]
	
	var ld = LinkData.create(fig_a.data.id, out_a.data.id, fig_b.data.id, in_b.data.id)
	_get_links_layer().add_link(out_a, in_b, ld)
	assert_eq(_get_links_layer().get_all_link_data().size(), 1)
	
	# Supprime le slot out de A
	_main.call("_on_slot_delete", out_a, fig_a)
	assert_eq(_get_links_layer().get_all_link_data().size(), 0, "Le lien doit être supprimé")


func test_selection_synchronization() -> void:
	var figs := _get_figures_by_id()
	var first_fig: Figure = figs.values()[0]
	
	# Sélectionne via workspace
	_main.call("_on_figure_selected", first_fig)
	assert_eq(_main.get("_selected_figure"), first_fig)
	
	# Sélectionne via timeline (sync inverse)
	var second_fig: Figure = figs.values()[1]
	_main.call("_on_timeline_segment_selected", second_fig.data)
	assert_eq(_main.get("_selected_figure"), second_fig)


func test_load_graph_full() -> void:
	var data = {
		"version": 1,
		"canvas_zoom": 0.5,
		"timeline_scale": 200.0,
		"figures": [
			{
				"id": "fig1", "title": "Box1", "position_x": 100, "position_y": 100,
				"color_r": 1, "color_g": 1, "color_b": 1, "color_a": 1,
				"start_time": 0, "end_time": 1, "track": 0,
				"input_slots": [{"id": "fig1_in0", "label": "in", "direction": 0, "index": 0}],
				"output_slots": [],
				"is_fleet_figure": false
			},
			{
				"id": "fleet_fig", "title": "Flottes", "position_x": 0, "position_y": 0,
				"color_r": 0.33, "color_g": 0.75, "color_b": 0.42, "color_a": 1,
				"start_time": 0, "end_time": 0, "track": 0,
				"input_slots": [], "output_slots": [{"id": "slot_f1", "label": "Fleet1", "direction": 1, "index": 0}],
				"is_fleet_figure": true
			}
		],
		"fleets": [
			{"id": "f1", "name": "Fleet1", "drone_type": 0, "drone_count": 10}
		],
		"fleet_to_slot": {
			"f1": "slot_f1"
		},
		"links": [
			{
				"id": "link1", "source_figure_id": "fleet_fig", "source_slot_id": "slot_f1",
				"target_figure_id": "fig1", "target_slot_id": "fig1_in0", "is_locked": false
			}
		]
	}
	
	_main.call("_load_graph", data)
	# Wait for refresh() in _load_graph
	await get_tree().process_frame
	
	assert_eq(_main.get_node("%Workspace").get_canvas_zoom(), 0.5)
	assert_eq(_main.get_node("%TimelinePanel").timeline_scale, 200.0)
	assert_eq(_get_figures_by_id().size(), 2)
	assert_eq(_main.get_node("%FleetPanel").get_fleets().size(), 1)
	assert_eq(_get_links_layer().get_all_link_data().size(), 1)
