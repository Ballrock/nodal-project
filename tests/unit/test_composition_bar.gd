extends GutTest

## Tests unitaires pour CompositionBar.

var _bar: CompositionBar = null


func before_each() -> void:
	_bar = CompositionBar.new()
	_bar.custom_minimum_size = Vector2(200, 16)
	add_child_autofree(_bar)
	await get_tree().process_frame


func test_initial_values() -> void:
	assert_eq(_bar.riff_count, 0)
	assert_eq(_bar.emo_count, 0)
	assert_eq(_bar.unresolved_count, 0)
	assert_eq(_bar.total, 0)


func test_update_bar_stores_values() -> void:
	_bar.update_bar(100, 50, 10, 500)
	assert_eq(_bar.riff_count, 100)
	assert_eq(_bar.emo_count, 50)
	assert_eq(_bar.unresolved_count, 10)
	assert_eq(_bar.total, 500)


func test_update_bar_triggers_redraw() -> void:
	# Calling update_bar should not crash and should update values
	_bar.update_bar(10, 20, 5, 100)
	await get_tree().process_frame
	assert_eq(_bar.riff_count, 10)
	assert_eq(_bar.emo_count, 20)


func test_update_bar_zero_total() -> void:
	_bar.update_bar(0, 0, 0, 0)
	await get_tree().process_frame
	assert_eq(_bar.total, 0)
	assert_eq(_bar.riff_count, 0)


func test_update_bar_overflow() -> void:
	_bar.update_bar(300, 200, 100, 500)
	await get_tree().process_frame
	# allocated (600) > total (500)
	var allocated := _bar.riff_count + _bar.emo_count + _bar.unresolved_count
	assert_gt(allocated, _bar.total)


func test_color_constants_exist() -> void:
	assert_eq(CompositionBar.COLOR_RIFF, Color(0.29, 0.56, 0.85))
	assert_eq(CompositionBar.COLOR_EMO, Color(0.49, 0.78, 0.89))
	assert_eq(CompositionBar.COLOR_UNRESOLVED, Color(0.75, 0.65, 0.3))
	assert_eq(CompositionBar.COLOR_UNALLOCATED, Color(0.3, 0.3, 0.35))
	assert_eq(CompositionBar.COLOR_OVERFLOW, Color(0.8, 0.25, 0.25))


func test_draw_does_not_crash_with_zero_size() -> void:
	var small_bar := CompositionBar.new()
	small_bar.size = Vector2.ZERO
	add_child_autofree(small_bar)
	small_bar.update_bar(10, 20, 5, 100)
	await get_tree().process_frame
	assert_true(true, "Draw with zero size should not crash")


func test_multiple_updates() -> void:
	_bar.update_bar(10, 20, 5, 100)
	_bar.update_bar(50, 30, 0, 200)
	_bar.update_bar(0, 0, 0, 0)
	await get_tree().process_frame
	assert_eq(_bar.riff_count, 0)
	assert_eq(_bar.emo_count, 0)
	assert_eq(_bar.total, 0)
