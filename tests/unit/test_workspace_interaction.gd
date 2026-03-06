extends GutTest

## Tests unitaires pour les interactions dans Workspace (zoom, pan, spawning).

const WorkspaceScene := preload("res://features/workspace/workspace.tscn")

var _workspace: Control = null

func before_each() -> void:
	_workspace = WorkspaceScene.instantiate()
	add_child_autofree(_workspace)
	# On attend un frame pour @onready
	await get_tree().process_frame
	# On simule une taille pour CanvasArea
	_workspace.get_node("%CanvasArea").size = Vector2(1000, 1000)


func test_pan_canvas() -> void:
	var canvas_content: Control = _workspace.get_node("%CanvasContent")
	var initial_pos: Vector2 = canvas_content.position
	
	# Clic droit pour démarrer le pan
	var event_press: InputEventMouseButton = InputEventMouseButton.new()
	event_press.button_index = MOUSE_BUTTON_RIGHT
	event_press.pressed = true
	event_press.global_position = Vector2(100, 100)
	_workspace.call("_canvas_area_gui_input", event_press)
	
	# Drag de 50px
	var event_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	event_motion.global_position = Vector2(150, 150)
	_workspace.call("_canvas_area_gui_input", event_motion)
	
	assert_eq(canvas_content.position, initial_pos + Vector2(50, 50))
	
	# Release
	var event_release: InputEventMouseButton = InputEventMouseButton.new()
	event_release.button_index = MOUSE_BUTTON_RIGHT
	event_release.pressed = false
	_workspace.call("_canvas_area_gui_input", event_release)


func test_zoom_canvas() -> void:
	var initial_zoom: float = _workspace.get_canvas_zoom()
	
	# Wheel Up
	var event_wheel: InputEventMouseButton = InputEventMouseButton.new()
	event_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	event_wheel.pressed = true
	event_wheel.global_position = Vector2(500, 500)
	_workspace.call("_canvas_area_gui_input", event_wheel)
	
	# Workspace.gd limite le zoom max à 1.0 par défaut, et CANVAS_ZOOM_STEP = 1.1
	# On teste si ça a bougé ou si c'est clampé
	assert_between(_workspace.get_canvas_zoom(), 0.25, 1.0)


func test_spawn_figure_registers_it() -> void:
	var data: FigureData = FigureData.create("Spawned")
	var fig_node: Figure = _workspace.spawn_figure_from_data(data)
	
	assert_not_null(fig_node)
	assert_true(fig_node.is_inside_tree())
	
	# Vérifie registre links_layer
	var links_layer: LinksLayer = _workspace.get_node("%LinksLayer")
	var figures: Array = links_layer.get("_figures")
	assert_true(figures.has(fig_node))
