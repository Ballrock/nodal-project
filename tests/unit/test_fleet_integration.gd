extends GutTest

## Tests d'intégration : ajout/suppression de flottes, mise à jour de la FleetFigure,
## nettoyage des liens associés.

const MainScene := preload("res://ui/main/main.tscn")

var _main: Control = null

func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame

func _fleet_figure() -> Figure:
	return _main.get("_fleet_figure") as Figure

func _fleet_to_slot() -> Dictionary:
	return _main.get("_fleet_to_slot") as Dictionary

func _workspace() -> Node:
	return _main.get_node("%Workspace")

func _links_layer() -> LinksLayer:
	return _workspace().get_node("%LinksLayer") as LinksLayer

func _fleet_panel() -> FleetPanel:
	return _main.get_node("%FleetPanel") as FleetPanel

func _figures_by_id() -> Dictionary:
	return _main.get("_figures_by_id") as Dictionary

func _create_fleet(p_name: String, p_type: int = FleetData.DroneType.DRONE_RIFF, p_count: int = 1) -> FleetData:
	var fleet := FleetData.create(p_name, p_type, p_count)
	_main.call("_on_fleet_created", fleet)
	return fleet

func _delete_fleet(fleet: FleetData) -> void:
	_main.call("_on_fleet_deleted", fleet)

func _update_fleet(fleet: FleetData) -> void:
	_main.call("_on_fleet_updated", fleet)

func _link_count() -> int:
	return _links_layer().get_all_link_data().size()

# ══════════════════════════════════════════════════════════
# TESTS
# ══════════════════════════════════════════════════════════

func test_fleet_figure_exists_at_startup() -> void:
	assert_not_null(_fleet_figure(), "La FleetFigure doit exister au démarrage")

func test_fleet_figure_is_marked_as_fleet() -> void:
	assert_true(_fleet_figure().is_fleet_figure, "La FleetFigure doit être marquée is_fleet_figure")

func test_fleet_figure_has_no_inputs() -> void:
	assert_eq(_fleet_figure().data.input_slots.size(), 0)

func test_add_fleet_creates_output_slot() -> void:
	_create_fleet("Alpha")
	assert_eq(_fleet_figure().data.output_slots.size(), 1)

func test_add_fleet_slot_has_fleet_name_as_label() -> void:
	_create_fleet("Bravo")
	assert_eq(_fleet_figure().data.output_slots[0].label, "Bravo")

func test_add_fleet_registers_in_fleet_to_slot_map() -> void:
	var fleet := _create_fleet("Delta")
	assert_true(_fleet_to_slot().has(fleet.id))

func test_update_fleet_renames_slot_label() -> void:
	var fleet := _create_fleet("OldName")
	fleet.name = "NewName"
	_update_fleet(fleet)
	var slot_data: SlotData = _fleet_to_slot()[fleet.id]
	assert_eq(slot_data.label, "NewName")

func test_remove_fleet_removes_slot() -> void:
	var fleet := _create_fleet("ToRemove")
	_delete_fleet(fleet)
	assert_eq(_fleet_figure().data.output_slots.size(), 0)

func test_remove_fleet_with_link_cleans_up_link() -> void:
	var fleet := _create_fleet("Linked")
	var fleet_slot_data: SlotData = _fleet_to_slot()[fleet.id]
	
	var target_figure: Figure = null
	for figure_id in _figures_by_id():
		var figure: Figure = _figures_by_id()[figure_id]
		if not figure.is_fleet_figure and figure.data.input_slots.size() > 0:
			target_figure = figure
			break
	
	var link := LinkData.create(_fleet_figure().data.id, fleet_slot_data.id,
		target_figure.data.id, target_figure.data.input_slots[0].id)
	
	var source_slot := _fleet_figure().find_slot_by_id(fleet_slot_data.id)
	var target_slot := target_figure.find_slot_by_id(target_figure.data.input_slots[0].id)
	
	_links_layer().add_link(source_slot, target_slot, link)
	assert_eq(_link_count(), 1)
	
	_delete_fleet(fleet)
	assert_eq(_link_count(), 0)
