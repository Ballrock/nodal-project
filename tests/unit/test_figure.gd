extends GutTest

## Tests unitaires pour la scène Figure (boîte nodale).

const FigureScene := preload("res://features/workspace/components/figure.tscn")

var _figure: Figure = null

func before_each() -> void:
	_figure = FigureScene.instantiate()
	add_child_autofree(_figure)
	# On attend que @onready soit prêt
	await get_tree().process_frame


func test_setup_initializes_ui() -> void:
	var data := FigureData.create("My Figure", Vector2(100, 100), 2, 3)
	_figure.setup(data)
	
	assert_eq(_figure.get_node("%TitleLabel").text, "My Figure")
	assert_eq(_figure.position, Vector2(100, 100))
	# 2 entrées + 3 sorties = 3 rangées (le max) + 1 bouton add
	# Mais _build_slots est appelé dans setup.
	var slots := _figure.get_all_slots()
	assert_eq(slots.size(), 5, "Doit avoir 2 entrées + 3 sorties")


func test_add_slot_pair() -> void:
	var data := FigureData.create("Classic", Vector2.ZERO, 1, 1)
	_figure.setup(data)
	watch_signals(_figure)
	
	# Simule clic sur bouton "+"
	# Le bouton est le dernier enfant de SlotsContainer
	var container := _figure.get_node("%SlotsContainer")
	var add_btn: Button = null
	for child in container.get_children():
		if child is Button and child.text == "+":
			add_btn = child
			break
	
	assert_not_null(add_btn, "Le bouton + doit exister")
	add_btn.pressed.emit()
	
	assert_eq(data.input_slots.size(), 2)
	assert_eq(data.output_slots.size(), 2)
	assert_signal_emitted(_figure, "slots_changed")
	
	var slots := _figure.get_all_slots()
	assert_eq(slots.size(), 4, "Doit avoir 2 paires = 4 slots")


func test_fleet_figure_no_add_button() -> void:
	var data := FigureData.create("Fleet", Vector2.ZERO, 0, 1)
	_figure.is_fleet_figure = true
	_figure.setup(data)
	
	var container := _figure.get_node("%SlotsContainer")
	var add_btn_found := false
	for child in container.get_children():
		if child is Button and child.text == "+":
			add_btn_found = true
			break
	
	assert_false(add_btn_found, "La FleetFigure ne doit pas avoir de bouton +")


func test_set_selected_updates_style() -> void:
	_figure.set_selected(true)
	var style := _figure.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.border_color, Color("f5c542"))
	
	_figure.set_selected(false)
	style = _figure.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.border_color, Color("555555"))


func test_title_edit_commit() -> void:
	var data := FigureData.create("Original", Vector2.ZERO)
	_figure.setup(data)
	watch_signals(_figure)
	
	_figure.call("_start_title_edit")
	var edit: LineEdit = _figure.get_node("%Header").get_child(-1) as LineEdit
	assert_not_null(edit, "LineEdit doit être présent")
	
	edit.text = "New Title"
	_figure.call("_commit_title_edit")
	
	assert_eq(data.title, "New Title")
	assert_eq(_figure.get_node("%TitleLabel").text, "New Title")
	assert_signal_emitted(_figure, "title_changed")
	assert_true(edit.is_queued_for_deletion(), "LineEdit doit être en cours de suppression")


func test_find_slot_by_id() -> void:
	var data := FigureData.create("Search", Vector2.ZERO, 1, 1)
	_figure.setup(data)
	
	var target_id := data.input_slots[0].id
	var found := _figure.find_slot_by_id(target_id)
	assert_not_null(found)
	assert_eq(found.data.id, target_id)
	
	assert_null(_figure.find_slot_by_id(&"non_existent"))
