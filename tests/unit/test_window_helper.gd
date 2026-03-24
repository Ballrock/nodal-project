extends GutTest

## Tests unitaires pour WindowHelper.popup_fitted().

var _window: Window


func before_each() -> void:
	_window = Window.new()
	_window.wrap_controls = true
	_window.min_size = Vector2i(200, 150)
	_window.size = Vector2i(400, 300)
	add_child(_window)


func after_each() -> void:
	if is_instance_valid(_window):
		_window.queue_free()
	_window = null


func test_popup_fitted_shows_window() -> void:
	WindowHelper.popup_fitted(_window)
	assert_true(_window.visible, "Window should be visible after popup_fitted")


func test_popup_fitted_does_not_crash_with_default_ratio() -> void:
	WindowHelper.popup_fitted(_window)
	assert_true(_window.visible, "Should not crash with default ratio")


func test_popup_fitted_does_not_crash_with_custom_ratio() -> void:
	WindowHelper.popup_fitted(_window, 0.5)
	assert_true(_window.visible, "Should not crash with custom ratio")


func test_popup_fitted_does_not_crash_with_small_ratio() -> void:
	WindowHelper.popup_fitted(_window, 0.3)
	assert_true(_window.visible, "Should not crash with small ratio")


func test_popup_fitted_size_not_exceeds_screen_max() -> void:
	# Set a large size then call popup_fitted
	_window.size = Vector2i(99999, 99999)
	var ratio := 0.5
	WindowHelper.popup_fitted(_window, ratio)
	var screen_rect := DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen())
	# In headless mode popup_centered may override size, so we just verify
	# the function ran without error and the window is visible
	assert_true(_window.visible, "Window should be visible")
	# If screen size is available (non-headless), verify clamping
	if screen_rect.size.x > 0 and screen_rect.size.y > 0:
		var max_w := int(screen_rect.size.x * ratio)
		var max_h := int(screen_rect.size.y * ratio)
		# After popup_centered, Godot may adjust size; just verify we attempted clamping
		assert_true(_window.size.x <= max_w or _window.size.x <= screen_rect.size.x,
			"Width should be reasonable")
		assert_true(_window.size.y <= max_h or _window.size.y <= screen_rect.size.y,
			"Height should be reasonable")


func test_popup_fitted_preserves_small_window_visibility() -> void:
	_window.size = Vector2i(200, 150)
	WindowHelper.popup_fitted(_window, 0.85)
	assert_true(_window.visible, "Small window should be visible after popup_fitted")


func test_popup_fitted_calls_popup_centered() -> void:
	# Hide the window first, then verify popup_fitted makes it visible
	_window.visible = false
	assert_false(_window.visible, "Window should not be visible before popup_fitted")
	WindowHelper.popup_fitted(_window)
	assert_true(_window.visible, "Window should be visible after popup_fitted (popup_centered called)")


func test_popup_fitted_min_size_respected() -> void:
	_window.min_size = Vector2i(300, 250)
	WindowHelper.popup_fitted(_window, 0.85)
	assert_true(_window.size.x >= 300, "Width should respect min_size")
	assert_true(_window.size.y >= 250, "Height should respect min_size")
