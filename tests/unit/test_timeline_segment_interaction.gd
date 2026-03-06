extends GutTest

## Tests unitaires pour les interactions sur TimelineSegment (drag/resize).

var _segment: TimelineSegment = null
var _data: FigureData = null

func before_each() -> void:
	_segment = TimelineSegment.new()
	add_child_autofree(_segment)
	_data = FigureData.create("Test", Vector2.ZERO, 1, 1, 10.0, 20.0) # Durée 10s
	_segment.setup(_data, 100.0) # 100px/s -> start=1000px, end=2000px
	await get_tree().process_frame


func test_setup_geometry() -> void:
	assert_eq(_segment.position.x, 1000.0)
	assert_eq(_segment.size.x, 1000.0)


func test_drag_segment() -> void:
	watch_signals(_segment)
	
	# Simule clic au milieu du segment
	var event_press := InputEventMouseButton.new()
	event_press.button_index = MOUSE_BUTTON_LEFT
	event_press.pressed = true
	event_press.position = Vector2(500, 10) # Milieu
	event_press.global_position = Vector2(1500, 10)
	_segment._gui_input(event_press)
	
	# Simule mouvement de +100px (+1s)
	var event_motion := InputEventMouseMotion.new()
	event_motion.global_position = Vector2(1600, 10)
	# On doit forcer _dragging car _gui_input l'a activé
	_segment._gui_input(event_motion)
	
	assert_eq(_data.start_time, 11.0, "start_time doit être à 11s")
	assert_eq(_data.end_time, 21.0, "end_time doit être à 21s")
	
	# Simule relâchement
	var event_release := InputEventMouseButton.new()
	event_release.button_index = MOUSE_BUTTON_LEFT
	event_release.pressed = false
	_segment._gui_input(event_release)
	
	assert_signal_emitted(_segment, "segment_moved")


func test_resize_right() -> void:
	watch_signals(_segment)
	
	# Clic sur le grip droit (size.x = 1000)
	var event_press := InputEventMouseButton.new()
	event_press.button_index = MOUSE_BUTTON_LEFT
	event_press.pressed = true
	event_press.position = Vector2(998, 10)
	event_press.global_position = Vector2(1998, 10)
	_segment._gui_input(event_press)
	
	# Mouvement +200px (+2s)
	var event_motion := InputEventMouseMotion.new()
	event_motion.global_position = Vector2(2198, 10)
	_segment._gui_input(event_motion)
	
	assert_eq(_data.start_time, 10.0, "start_time inchangé")
	assert_eq(_data.end_time, 22.0, "end_time doit être à 22s")
	
	var event_release := InputEventMouseButton.new()
	event_release.button_index = MOUSE_BUTTON_LEFT
	event_release.pressed = false
	_segment._gui_input(event_release)
	
	assert_signal_emitted(_segment, "segment_resized")


func test_resize_left() -> void:
	# Clic sur le grip gauche
	var event_press := InputEventMouseButton.new()
	event_press.button_index = MOUSE_BUTTON_LEFT
	event_press.pressed = true
	event_press.position = Vector2(2, 10)
	event_press.global_position = Vector2(1002, 10)
	_segment._gui_input(event_press)
	
	# Mouvement +300px (+3s)
	var event_motion := InputEventMouseMotion.new()
	event_motion.global_position = Vector2(1302, 10)
	_segment._gui_input(event_motion)
	
	assert_eq(_data.start_time, 13.0, "start_time doit être à 13s")
	assert_eq(_data.end_time, 20.0, "end_time inchangé")


func test_update_cursor_on_hover() -> void:
	# Grip gauche
	var event_motion := InputEventMouseMotion.new()
	event_motion.position = Vector2(2, 10)
	_segment._gui_input(event_motion)
	assert_eq(_segment.mouse_default_cursor_shape, Control.CURSOR_HSIZE)
	
	# Milieu
	event_motion.position = Vector2(500, 10)
	_segment._gui_input(event_motion)
	assert_eq(_segment.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
	
	# Grip droit
	event_motion.position = Vector2(998, 10)
	_segment._gui_input(event_motion)
	assert_eq(_segment.mouse_default_cursor_shape, Control.CURSOR_HSIZE)
