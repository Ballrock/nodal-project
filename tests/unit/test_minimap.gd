extends GutTest

## Tests unitaires pour le Workspace Dynamique et la Minimap.

const WorkspaceScene := preload("res://features/workspace/workspace.tscn")
var _workspace: Control = null

func before_each() -> void:
	_workspace = WorkspaceScene.instantiate()
	add_child_autofree(_workspace)
	await get_tree().process_frame

func _get_minimap() -> Control:
	return _workspace.get_node("%Minimap") as Control

# ── Tests Workspace Dynamique ─────────────────────────────

func test_workspace_initial_size() -> void:
	var rect: Rect2 = _workspace.call("get_workspace_rect")
	assert_eq(rect.size, Vector2(3000, 2000), "La taille initiale doit être 3000x2000")
	assert_eq(rect.position, Vector2(-1500, -1000), "Le workspace doit être centré sur (0,0)")

func test_workspace_expansion() -> void:
	# On ajoute une figure loin sur la droite
	var fig_data := FigureData.create("Test", Vector2(2000, 0))
	var figure = _workspace.spawn_figure_from_data(fig_data)
	
	_workspace.call("_update_workspace_rect")
	
	var rect: Rect2 = _workspace.call("get_workspace_rect")
	# La figure est à 2000, sa taille par défaut est (200, 100), donc bord droit à 2200.
	# Avec une marge de 200, le workspace doit atteindre au moins 2400.
	assert_gt(rect.end.x, 2200.0, "Le workspace doit s'être agrandi vers la droite")

func test_workspace_shrinking() -> void:
	# On ajoute une figure au centre
	var fig_data := FigureData.create("Test", Vector2.ZERO)
	var figure = _workspace.spawn_figure_from_data(fig_data)
	
	_workspace.call("_update_workspace_rect")
	var rect: Rect2 = _workspace.call("get_workspace_rect")
	
	assert_eq(rect.size, Vector2(3000, 2000), "Le workspace doit rester à sa taille minimale")

# ── Tests Minimap ─────────────────────────────────────────

func test_minimap_exists() -> void:
	var minimap := _get_minimap()
	assert_not_null(minimap, "La minimap doit exister dans la scène")
	assert_true(minimap.visible, "La minimap doit être visible")

func test_minimap_navigation() -> void:
	var minimap := _get_minimap()
	var canvas_content: Control = _workspace.get_node("%CanvasContent")
	var canvas_area: Control = _workspace.get_node("%CanvasArea")
	var canvas_zoom: float = _workspace.call("get_canvas_zoom")
	
	# Forcer un update du workspace rect
	_workspace.call("_update_workspace_rect")
	var workspace_rect: Rect2 = _workspace.call("get_workspace_rect")
	
	# Simuler un clic au centre de la minimap
	var center_click = minimap.size / 2.0
	minimap.call("_handle_minimap_click", center_click)
	
	# Le clic au centre de la minimap doit correspondre au centre du workspace_rect
	var workspace_center = workspace_rect.get_center()
	var expected_pos = (canvas_area.size / 2.0) - (workspace_center * canvas_zoom)
	
	assert_between(canvas_content.position.x, expected_pos.x - 1.0, expected_pos.x + 1.0, "Le clic minimap doit déplacer le canvas au centre X")
	assert_between(canvas_content.position.y, expected_pos.y - 1.0, expected_pos.y + 1.0, "Le clic minimap doit déplacer le canvas au centre Y")

func test_minimap_draw_no_crash() -> void:
	var minimap := _get_minimap()
	# On s'assure qu'on a au moins deux figures et un lien
	var fig_data1 := FigureData.create("A", Vector2(-100, 0), 1, 1)
	var fig_data2 := FigureData.create("B", Vector2(100, 0), 1, 1)
	var f1 = _workspace.spawn_figure_from_data(fig_data1)
	var f2 = _workspace.spawn_figure_from_data(fig_data2)
	
	# On force la création des liens via LinksLayer
	var out_slot = f1.get_all_slots().filter(func(s): return s.data.direction == SlotData.Direction.SLOT_OUTPUT)[0]
	var in_slot = f2.get_all_slots().filter(func(s): return s.data.direction == SlotData.Direction.SLOT_INPUT)[0]
	
	var link_data := LinkData.create(f1.data.id, out_slot.data.id, f2.data.id, in_slot.data.id)
	_workspace.links_layer.add_link(out_slot, in_slot, link_data)
	
	# Forcer le redraw et vérifier qu'il n'y a pas d'erreur
	minimap.queue_redraw()
	await get_tree().process_frame
	pass
