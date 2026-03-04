extends GutTest

## Tests de défilement et zoom pour le panneau timeline NLE.

const TimelinePanelScene := preload("res://features/timeline/timeline_panel.tscn")
const FigureDataClass := preload("res://core/data/figure_data.gd")

var _panel: TimelinePanel = null

func before_each() -> void:
	_panel = TimelinePanelScene.instantiate()
	add_child_autofree(_panel)
	_panel.size = Vector2(800, 200)
	# On s'assure d'être dans une plage de scale valide pour les tests de zoom.
	_panel.timeline_scale = 5.0
	await get_tree().process_frame

func test_mouse_wheel_horizontal_scroll() -> void:
	var initial_scroll = _panel.get("_scroll_offset_x")
	
	# Simuler WHEEL_RIGHT
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	event.pressed = true
	event.position = Vector2(100, 100)
	
	_panel._gui_input(event)
	
	var new_scroll = _panel.get("_scroll_offset_x")
	assert_gt(new_scroll, initial_scroll, "Le scroll horizontal devrait augmenter avec WHEEL_RIGHT")

func test_mouse_wheel_vertical_scroll_on_windows() -> void:
	_panel.set("_is_macos", false)
	var initial_scroll = _panel.get("_scroll_offset_x")
	
	# Simuler WHEEL_DOWN (vertical) -> devrait défiler horizontalement sur Windows
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = Vector2(100, 100)
	
	_panel._gui_input(event)
	
	var new_scroll = _panel.get("_scroll_offset_x")
	assert_gt(new_scroll, initial_scroll, "Sur Windows, WHEEL_DOWN devrait défiler horizontalement")

func test_mouse_wheel_vertical_scroll_on_macos() -> void:
	_panel.set("_is_macos", true)
	var initial_scroll = _panel.get("_scroll_offset_x")
	
	# Simuler WHEEL_DOWN (vertical) -> ne devrait RIEN faire sur macOS (selon spec)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = Vector2(100, 100)
	
	_panel._gui_input(event)
	
	var new_scroll = _panel.get("_scroll_offset_x")
	assert_eq(new_scroll, initial_scroll, "Sur macOS, WHEEL_DOWN seul ne devrait pas défiler horizontalement")

func test_pan_gesture_scroll() -> void:
	var initial_scroll = _panel.get("_scroll_offset_x")
	
	# Simuler un PanGesture (ex: trackpad macOS)
	var event = InputEventPanGesture.new()
	event.delta = Vector2(5.0, 0.0) # Déplacement vers la droite
	event.position = Vector2(100, 100)
	
	_panel._gui_input(event)
	
	var new_scroll = _panel.get("_scroll_offset_x")
	assert_gt(new_scroll, initial_scroll, "Le PanGesture horizontal devrait faire défiler la timeline")

func test_magnify_gesture_zoom() -> void:
	var initial_scale = _panel.timeline_scale
	
	# Simuler un MagnifyGesture (pinch-to-zoom)
	var event = InputEventMagnifyGesture.new()
	event.factor = 1.5
	event.position = Vector2(100, 100)
	
	_panel._gui_input(event)
	
	assert_gt(_panel.timeline_scale, initial_scale, "Le MagnifyGesture factor > 1 devrait zoomer (augmenter scale)")

func test_timeline_zoom_ctrl_wheel() -> void:
	var initial_scale = _panel.timeline_scale
	
	# Simuler Ctrl + WHEEL_UP (Zoom in)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.ctrl_pressed = true
	event.position = Vector2(100, 100)
	
	_panel._gui_input(event)
	
	assert_gt(_panel.timeline_scale, initial_scale, "Ctrl + Molette UP devrait augmenter le scale (zoom in)")
