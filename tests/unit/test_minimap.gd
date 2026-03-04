extends GutTest

## Tests unitaires pour le Workspace Dynamique et la Minimap.

const MainScene := preload("res://main.tscn")
var _main: Control = null

func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame

func _get_minimap() -> Control:
	return _main.get("minimap") as Control

# ── Tests Workspace Dynamique ─────────────────────────────

func test_workspace_initial_size() -> void:
	var rect: Rect2 = _main.call("get_workspace_rect")
	assert_eq(rect.size, Vector2(3000, 2000), "La taille initiale doit être 3000x2000")
	assert_eq(rect.position, Vector2(-1500, -1000), "Le workspace doit être centré sur (0,0)")

func test_workspace_expansion() -> void:
	# On déplace une figure loin sur la droite
	var figures: Dictionary = _main.get("_figures_by_id")
	var first_id = figures.keys()[0]
	var figure: Figure = figures[first_id]
	
	figure.position = Vector2(2000, 0)
	_main.call("_update_workspace_rect")
	
	var rect: Rect2 = _main.call("get_workspace_rect")
	# La figure est à 2000, sa taille est ~200, donc bord droit à ~2200.
	# Avec une marge de 200, le workspace doit atteindre au moins 2400.
	assert_gt(rect.end.x, 2200.0, "Le workspace doit s'être agrandi vers la droite")

func test_workspace_shrinking() -> void:
	# On déplace tout vers le centre
	var figures: Dictionary = _main.get("_figures_by_id")
	for id in figures:
		var figure: Figure = figures[id]
		figure.position = Vector2.ZERO
	
	_main.call("_update_workspace_rect")
	var rect: Rect2 = _main.call("get_workspace_rect")
	
	assert_eq(rect.size, Vector2(3000, 2000), "Le workspace doit revenir à sa taille minimale")

# ── Tests Minimap ─────────────────────────────────────────

func test_minimap_exists() -> void:
	var minimap := _get_minimap()
	assert_not_null(minimap, "La minimap doit exister dans la scène")
	assert_true(minimap.visible, "La minimap doit être visible")

func test_minimap_navigation() -> void:
	var minimap := _get_minimap()
	var canvas_content: Control = _main.get("canvas_content")
	var canvas_area: Control = _main.get("canvas_area")
	var canvas_zoom: float = _main.call("get_canvas_zoom")
	
	# Forcer un update du workspace rect
	_main.call("_update_workspace_rect")
	var workspace_rect: Rect2 = _main.call("get_workspace_rect")
	
	# Simuler un clic au centre de la minimap
	var center_click = minimap.size / 2.0
	minimap.call("_handle_minimap_click", center_click)
	
	# Le clic au centre de la minimap doit correspondre au centre du workspace_rect
	var workspace_center = workspace_rect.get_center()
	var expected_pos = (canvas_area.size / 2.0) - (workspace_center * canvas_zoom)
	
	assert_between(canvas_content.position.x, expected_pos.x - 1.0, expected_pos.x + 1.0, "Le clic minimap doit déplacer le canvas au centre X")
	assert_between(canvas_content.position.y, expected_pos.y - 1.0, expected_pos.y + 1.0, "Le clic minimap doit déplacer le canvas au centre Y")

func test_minimap_draw_links() -> void:
	var minimap := _get_minimap()
	assert_has_signal(minimap, "draw", "La minimap doit pouvoir être redessinée")
	
	# On s'assure qu'on a au moins deux figures et un lien
	var figures: Dictionary = _main.get("_figures_by_id")
	if figures.size() < 2:
		_main.call("_add_figure")
		_main.call("_add_figure")
		figures = _main.get("_figures_by_id")
	
	var keys = figures.keys()
	var fig1: Figure = figures[keys[0]]
	var fig2: Figure = figures[keys[1]]
	
	# On s'assure qu'ils ont des slots
	if fig1.data.output_slots.is_empty():
		fig1.call("_on_add_slot_pair")
	if fig2.data.input_slots.is_empty():
		fig2.call("_on_add_slot_pair")
	
	# Forcer la création de slots "mockés" pour le test si build_slots a échoué
	if fig1.get_all_slots().is_empty():
		var row := HBoxContainer.new()
		fig1.get_node("%SlotsContainer").add_child(row)
		var slot := SlotData.create("out", SlotData.Direction.SLOT_OUTPUT, 0)
		var s_node = preload("res://scenes/slot.tscn").instantiate()
		row.add_child(s_node)
		s_node.setup(slot)
		s_node.owner_figure = fig1
	
	if fig2.get_all_slots().is_empty():
		var row := HBoxContainer.new()
		fig2.get_node("%SlotsContainer").add_child(row)
		var slot := SlotData.create("in", SlotData.Direction.SLOT_INPUT, 0)
		var s_node = preload("res://scenes/slot.tscn").instantiate()
		row.add_child(s_node)
		s_node.setup(slot)
		s_node.owner_figure = fig2
	
	# Attendre que les slots soient instanciés dans le SceneTree
	await get_tree().process_frame
	
	var out_slots = fig1.get_all_slots().filter(func(s): return s.data.direction == SlotData.Direction.SLOT_OUTPUT)
	assert_gt(out_slots.size(), 0, "Fig1 devrait avoir au moins un slot de sortie")
	var out_slot: Slot = out_slots[0]
	
	var in_slots = fig2.get_all_slots().filter(func(s): return s.data.direction == SlotData.Direction.SLOT_INPUT)
	assert_gt(in_slots.size(), 0, "Fig2 devrait avoir au moins un slot d'entrée")
	var in_slot: Slot = in_slots[0]
	
	# Créer un lien
	_main.call("_on_link_created", out_slot, in_slot)
	
	# Forcer le redraw
	minimap.queue_redraw()
	await get_tree().process_frame
	
	# On ne peut pas facilement tester le contenu du draw() sans mocker draw_line,
	# mais on vérifie au moins que le code de dessin ne crash pas.
	pass
