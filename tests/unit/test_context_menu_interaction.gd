extends GutTest

## Test de l'interaction du menu contextuel (clic droit multiple).

const MainScene := preload("res://ui/main/main.tscn")
const LinkData := preload("res://core/data/link_data.gd")
const FigureData := preload("res://core/data/figure_data.gd")

var _main: Control = null

func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame

func _workspace() -> Node:
	return _main.get_node("%Workspace")

func _links_layer() -> LinksLayer:
	return _workspace().get_node("%LinksLayer") as LinksLayer

func test_right_click_on_another_link_reopens_menu() -> void:
	var ws = _workspace()
	var layer := _links_layer()
	
	# Nettoyer et créer des figures propres pour le test
	ws.clear()
	var fig_a = ws.spawn_figure_from_data(FigureData.create("A", Vector2(0, 0), 1, 1))
	var fig_b = ws.spawn_figure_from_data(FigureData.create("B", Vector2(400, 0), 1, 1))
	var fig_c = ws.spawn_figure_from_data(FigureData.create("C", Vector2(800, 0), 1, 1))
	
	await get_tree().process_frame # Attendre le build des slots
	
	# Créer deux liens
	var link1 := LinkData.create(fig_a.data.id, fig_a.data.output_slots[0].id, fig_b.data.id, fig_b.data.input_slots[0].id)
	var link2 := LinkData.create(fig_b.data.id, fig_b.data.output_slots[0].id, fig_c.data.id, fig_c.data.input_slots[0].id)
	layer.add_link_from_data(link1)
	layer.add_link_from_data(link2)
	layer.refresh()
	
	# Positions approximatives pour le clic
	var pos1: Vector2 = (fig_a.find_slot_by_id(fig_a.data.output_slots[0].id).get_circle_global_center() + 
				 fig_b.find_slot_by_id(fig_b.data.input_slots[0].id).get_circle_global_center()) / 2.0
	var pos2: Vector2 = (fig_b.find_slot_by_id(fig_b.data.output_slots[0].id).get_circle_global_center() + 
				 fig_c.find_slot_by_id(fig_c.data.input_slots[0].id).get_circle_global_center()) / 2.0

	# 1. Premier clic droit sur Link 1
	var ev1 := InputEventMouseButton.new()
	ev1.button_index = MOUSE_BUTTON_RIGHT
	ev1.pressed = true
	ev1.global_position = pos1
	layer._input(ev1)
	
	assert_eq(layer._ctx_link, link1, "Le menu devrait être ouvert pour le lien 1")
	var popup1 = layer._ctx_popup
	assert_not_null(popup1, "Le popup devrait exister")
	
	# 2. Deuxième clic droit sur Link 2 (alors que le menu 1 est ouvert)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_RIGHT
	ev2.pressed = true
	ev2.global_position = pos2
	layer._input(ev2)
	
	assert_eq(layer._ctx_link, link2, "Le menu devrait être ouvert pour le lien 2")
	# Dans l'implémentation actuelle, le popup1 est queue_freed mais peut-être pas encore nul au frame même
	assert_ne(layer._ctx_popup, popup1, "Le popup devrait avoir été remplacé")
	
	# 3. Troisième clic droit dans le vide (doit fermer le menu)
	var ev3 := InputEventMouseButton.new()
	ev3.button_index = MOUSE_BUTTON_RIGHT
	ev3.pressed = true
	ev3.global_position = Vector2(-2000, -2000) # Loin de tout lien
	layer._input(ev3)
	
	assert_null(layer._ctx_link, "Le lien contextuel devrait être nul")
	assert_null(layer._ctx_popup, "Le popup devrait être fermé")
