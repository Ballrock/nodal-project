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


func test_details_button_exists() -> void:
	var data := FigureData.create("My Figure", Vector2(100, 100), 1, 1)
	_figure.setup(data)
	
	var btn := _figure.get_node("%DetailsBtn")
	assert_not_null(btn, "Le bouton détails doit exister")
	assert_eq(btn.text, "more_vert")


func test_details_button_opens_menu() -> void:
	var data := FigureData.create("My Figure", Vector2(100, 100), 1, 1)
	_figure.setup(data)
	
	var btn := _figure.get_node("%DetailsBtn")
	btn.pressed.emit()
	
	# Le PopupMenu est ajouté comme enfant de la figure dans _on_details_btn_pressed
	var found_popup := false
	for child in _figure.get_children():
		if child is PopupMenu:
			found_popup = true
			break
	
	assert_true(found_popup, "Un PopupMenu doit être créé lors du clic sur le bouton détails")


func test_set_title_updates_data_and_ui() -> void:
	var data := FigureData.create("Old", Vector2.ZERO)
	_figure.setup(data)
	
	_figure.set_title("New")
	assert_eq(data.title, "New")
	assert_eq(_figure.get_node("%TitleLabel").text, "New")


func test_find_slot_by_id() -> void:
	var data := FigureData.create("Search", Vector2.ZERO, 1, 1)
	_figure.setup(data)
	
	var target_id := data.input_slots[0].id
	var found := _figure.find_slot_by_id(target_id)
	assert_not_null(found)
	assert_eq(found.data.id, target_id)
	
	assert_null(_figure.find_slot_by_id(&"non_existent"))
