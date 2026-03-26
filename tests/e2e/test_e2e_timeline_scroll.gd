extends "res://tests/unit/e2e_test_base.gd"

## Tests E2E : scroll et zoom dans la timeline.
## Simule de vraies interactions utilisateur (molette, trackpad, pinch-to-zoom)
## sur le panneau timeline intégré dans l'application complète.


# ══════════════════════════════════════════════════════════
# SCROLL HORIZONTAL VIA MOLETTE
# ══════════════════════════════════════════════════════════

func test_wheel_right_scrolls_timeline() -> void:
	var timeline := _timeline_panel()
	var initial_scroll: float = timeline.get("_scroll_offset_x")
	await _take_screenshot("before_scroll_right")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	event.pressed = true
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	var new_scroll: float = timeline.get("_scroll_offset_x")
	await _take_screenshot("after_scroll_right")
	assert_gt(new_scroll, initial_scroll, "WHEEL_RIGHT doit faire défiler la timeline vers la droite")


func test_wheel_left_scrolls_timeline() -> void:
	var timeline := _timeline_panel()

	# D'abord scroller à droite pour avoir de la marge
	var scroll_right := InputEventMouseButton.new()
	scroll_right.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	scroll_right.pressed = true
	scroll_right.position = Vector2(100, 50)
	for i in 5:
		timeline._gui_input(scroll_right)
	await _wait_frames(1)

	var scroll_before: float = timeline.get("_scroll_offset_x")
	assert_gt(scroll_before, 0.0, "Precondition: timeline doit être scrollée à droite")
	await _take_screenshot("before_scroll_left")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_LEFT
	event.pressed = true
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	var new_scroll: float = timeline.get("_scroll_offset_x")
	await _take_screenshot("after_scroll_left")
	assert_lt(new_scroll, scroll_before, "WHEEL_LEFT doit faire défiler la timeline vers la gauche")


# ══════════════════════════════════════════════════════════
# SCROLL VERTICAL (WINDOWS/LINUX) → PAN HORIZONTAL
# ══════════════════════════════════════════════════════════

func test_wheel_down_scrolls_on_windows() -> void:
	var timeline := _timeline_panel()
	timeline.set("_is_macos", false)
	var initial_scroll: float = timeline.get("_scroll_offset_x")
	await _take_screenshot("before_wheel_down_windows")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	var new_scroll: float = timeline.get("_scroll_offset_x")
	await _take_screenshot("after_wheel_down_windows")
	assert_gt(new_scroll, initial_scroll, "Sur Windows, WHEEL_DOWN doit défiler horizontalement")


func test_wheel_down_does_not_scroll_on_macos() -> void:
	var timeline := _timeline_panel()
	timeline.set("_is_macos", true)
	var initial_scroll: float = timeline.get("_scroll_offset_x")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	var new_scroll: float = timeline.get("_scroll_offset_x")
	assert_eq(new_scroll, initial_scroll, "Sur macOS, WHEEL_DOWN seul ne doit pas défiler")


# ══════════════════════════════════════════════════════════
# SCROLL CLAMPING (LIMITES)
# ══════════════════════════════════════════════════════════

func test_scroll_clamps_at_zero() -> void:
	var timeline := _timeline_panel()
	assert_eq(timeline.get("_scroll_offset_x"), 0.0, "Precondition: scroll initial à 0")

	# Tenter de scroller vers la gauche (au-delà de 0)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_LEFT
	event.pressed = true
	event.position = Vector2(100, 50)
	for i in 10:
		timeline._gui_input(event)
	await _wait_frames(1)

	var scroll_val: float = timeline.get("_scroll_offset_x")
	assert_eq(scroll_val, 0.0, "Le scroll ne doit pas descendre en dessous de 0")


func test_scroll_clamps_at_max() -> void:
	var timeline := _timeline_panel()

	# Scroller massivement vers la droite
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	event.pressed = true
	event.position = Vector2(100, 50)
	for i in 500:
		timeline._gui_input(event)
	await _wait_frames(1)

	var scroll_val: float = timeline.get("_scroll_offset_x")

	# Le scroll doit être clampé à la valeur max (pas infini)
	var max_scroll := maxf(
		SnapHelper.time_to_pixel(3600.0, timeline.timeline_scale) - timeline.call("_get_track_area_width"),
		0.0
	)
	assert_lte(scroll_val, max_scroll, "Le scroll ne doit pas dépasser la limite max")
	assert_gte(scroll_val, 0.0, "Le scroll doit rester positif")


# ══════════════════════════════════════════════════════════
# PAN GESTURE (TRACKPAD macOS)
# ══════════════════════════════════════════════════════════

func test_pan_gesture_scrolls_timeline() -> void:
	var timeline := _timeline_panel()
	var initial_scroll: float = timeline.get("_scroll_offset_x")
	await _take_screenshot("before_pan_gesture")

	var event := InputEventPanGesture.new()
	event.delta = Vector2(5.0, 0.0)
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	var new_scroll: float = timeline.get("_scroll_offset_x")
	await _take_screenshot("after_pan_gesture")
	assert_gt(new_scroll, initial_scroll, "PanGesture vers la droite doit faire défiler la timeline")


func test_pan_gesture_negative_scrolls_back() -> void:
	var timeline := _timeline_panel()

	# D'abord scroller vers la droite
	var scroll_right := InputEventPanGesture.new()
	scroll_right.delta = Vector2(10.0, 0.0)
	scroll_right.position = Vector2(100, 50)
	for i in 5:
		timeline._gui_input(scroll_right)
	await _wait_frames(1)

	var scroll_before: float = timeline.get("_scroll_offset_x")
	assert_gt(scroll_before, 0.0, "Precondition: timeline scrollée")

	var event := InputEventPanGesture.new()
	event.delta = Vector2(-5.0, 0.0)
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	var new_scroll: float = timeline.get("_scroll_offset_x")
	assert_lt(new_scroll, scroll_before, "PanGesture négatif doit revenir en arrière")


# ══════════════════════════════════════════════════════════
# ZOOM (CTRL + MOLETTE)
# ══════════════════════════════════════════════════════════

func test_ctrl_wheel_up_zooms_in() -> void:
	var timeline := _timeline_panel()
	# Placer le scale au milieu de la plage pour pouvoir zoomer dans les deux sens
	var limits: Vector2 = timeline.call("get_timeline_scale_limits")
	timeline.timeline_scale = (limits.x + limits.y) / 2.0
	var initial_scale: float = timeline.timeline_scale
	await _take_screenshot("before_zoom_in")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.ctrl_pressed = true
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	await _take_screenshot("after_zoom_in")
	assert_gt(timeline.timeline_scale, initial_scale, "Ctrl+WHEEL_UP doit zoomer (augmenter scale)")


func test_ctrl_wheel_down_zooms_out() -> void:
	var timeline := _timeline_panel()
	var limits: Vector2 = timeline.call("get_timeline_scale_limits")
	timeline.timeline_scale = (limits.x + limits.y) / 2.0
	var initial_scale: float = timeline.timeline_scale
	await _take_screenshot("before_zoom_out")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.ctrl_pressed = true
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	await _take_screenshot("after_zoom_out")
	assert_lt(timeline.timeline_scale, initial_scale, "Ctrl+WHEEL_DOWN doit dézoomer (diminuer scale)")


# ══════════════════════════════════════════════════════════
# MAGNIFY GESTURE (PINCH-TO-ZOOM)
# ══════════════════════════════════════════════════════════

func test_magnify_zoom_in() -> void:
	var timeline := _timeline_panel()
	var limits: Vector2 = timeline.call("get_timeline_scale_limits")
	timeline.timeline_scale = (limits.x + limits.y) / 2.0
	var initial_scale: float = timeline.timeline_scale

	var event := InputEventMagnifyGesture.new()
	event.factor = 1.5
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	assert_gt(timeline.timeline_scale, initial_scale, "Pinch zoom in (factor > 1) doit augmenter le scale")


func test_magnify_zoom_out() -> void:
	var timeline := _timeline_panel()
	var limits: Vector2 = timeline.call("get_timeline_scale_limits")
	timeline.timeline_scale = (limits.x + limits.y) / 2.0
	var initial_scale: float = timeline.timeline_scale

	var event := InputEventMagnifyGesture.new()
	event.factor = 0.5
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	assert_lt(timeline.timeline_scale, initial_scale, "Pinch zoom out (factor < 1) doit diminuer le scale")


# ══════════════════════════════════════════════════════════
# SCROLLBAR VISUELLE
# ══════════════════════════════════════════════════════════

func test_scroll_shows_scrollbar() -> void:
	var timeline := _timeline_panel()

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	event.pressed = true
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	var opacity: float = timeline.get("_scrollbar_opacity")
	assert_eq(opacity, 1.0, "La scrollbar doit être visible après un scroll")


func test_scrollbar_fades_after_delay() -> void:
	var timeline := _timeline_panel()

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	event.pressed = true
	event.position = Vector2(100, 50)
	timeline._gui_input(event)
	await _wait_frames(1)

	# Simuler directement l'expiration du timer au lieu d'attendre des frames
	# car le delta en headless peut être très petit
	timeline.set("_scrollbar_visible_timer", 0.0)
	# Appeler _process manuellement avec un delta suffisant pour déclencher le fade
	timeline._process(0.2)

	var opacity: float = timeline.get("_scrollbar_opacity")
	assert_lt(opacity, 1.0, "La scrollbar doit commencer à s'estomper après le délai")


# ══════════════════════════════════════════════════════════
# SCROLL + ZOOM COMBINÉ
# ══════════════════════════════════════════════════════════

func test_zoom_preserves_time_under_cursor() -> void:
	var timeline := _timeline_panel()
	# Placer le scale au milieu de la plage
	var limits: Vector2 = timeline.call("get_timeline_scale_limits")
	timeline.timeline_scale = (limits.x + limits.y) / 2.0

	# Scroller à une position non-zéro
	var scroll_event := InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	scroll_event.pressed = true
	scroll_event.position = Vector2(200, 50)
	for i in 10:
		timeline._gui_input(scroll_event)
	await _wait_frames(1)

	var scroll_before: float = timeline.get("_scroll_offset_x")
	var scale_before: float = timeline.timeline_scale
	var cursor_x := 200.0
	var time_before: float = SnapHelper.pixel_to_time(scroll_before + cursor_x, scale_before)
	await _take_screenshot("before_zoom_preserve")

	# Zoomer sous le curseur
	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_event.pressed = true
	zoom_event.ctrl_pressed = true
	zoom_event.position = Vector2(cursor_x, 50)
	timeline._gui_input(zoom_event)
	await _wait_frames(1)

	var scroll_after: float = timeline.get("_scroll_offset_x")
	var scale_after: float = timeline.timeline_scale
	var time_after: float = SnapHelper.pixel_to_time(scroll_after + cursor_x, scale_after)
	await _take_screenshot("after_zoom_preserve")

	assert_almost_eq(time_after, time_before, 0.5,
		"Le temps sous le curseur doit rester stable après un zoom")
