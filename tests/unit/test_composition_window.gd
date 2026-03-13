extends GutTest

## Tests unitaires pour CompositionWindow.

const CompositionWindowScene := preload("res://features/fleet/composition_window.tscn")

var _window: CompositionWindow = null
var _saved_total: float = 0.0
var _saved_constraints = null


func before_each() -> void:
	# Save original autoload settings to restore later
	_saved_total = SettingsManager.get_setting("composition/total_drones")
	_saved_constraints = SettingsManager.get_setting("composition/constraints")

	# Reset to known state
	SettingsManager.set_setting("composition/total_drones", 0.0)
	SettingsManager.set_setting("composition/constraints", [])

	_window = CompositionWindowScene.instantiate()
	add_child_autofree(_window)
	await get_tree().process_frame


func after_each() -> void:
	if _window and is_instance_valid(_window):
		_window.hide()
	# Restore original settings
	SettingsManager.set_setting("composition/total_drones", _saved_total)
	SettingsManager.set_setting("composition/constraints", _saved_constraints if _saved_constraints != null else [])


func test_initial_state() -> void:
	assert_false(_window.visible, "La fenêtre doit être masquée au départ")


func test_open_loads_draft() -> void:
	SettingsManager.set_setting("composition/total_drones", 500.0)
	_window.open()
	assert_true(_window.visible, "La fenêtre doit être visible après open()")
	assert_eq(int(_window.get_node("%TotalSpin").value), 500)


func test_apply_saves_settings() -> void:
	_window.open()
	_window.get_node("%TotalSpin").value = 1000
	watch_signals(_window)
	_window.get_node("%ApplyBtn").pressed.emit()
	assert_signal_emitted(_window, "composition_changed")
	assert_eq(int(SettingsManager.get_setting("composition/total_drones")), 1000)
	assert_false(_window.visible)


func test_cancel_does_not_save() -> void:
	SettingsManager.set_setting("composition/total_drones", 100.0)
	_window.open()
	_window.get_node("%TotalSpin").value = 999
	_window.get_node("%CancelBtn").pressed.emit()
	assert_false(_window.visible)
	assert_eq(int(SettingsManager.get_setting("composition/total_drones")), 100)


func test_summary_label_updates() -> void:
	var constraints: Array = [
		DroneConstraint.create("A", DroneConstraint.ConstraintCategory.DRONE_TYPE, "0", 300).to_dict(),
		DroneConstraint.create("B", DroneConstraint.ConstraintCategory.DRONE_TYPE, "1", 200).to_dict(),
	]
	SettingsManager.set_setting("composition/total_drones", 1000.0)
	SettingsManager.set_setting("composition/constraints", constraints)
	_window.open()
	var summary: String = _window.get_node("%SummaryLabel").text
	assert_string_contains(summary, "RIFF: 300")
	assert_string_contains(summary, "EMO: 200")
	assert_string_contains(summary, "500 / 1000")


func test_delete_constraint_removes_from_draft() -> void:
	var constraints: Array = [
		DroneConstraint.create("OnlyOne", DroneConstraint.ConstraintCategory.DRONE_TYPE, "0", 100).to_dict(),
	]
	SettingsManager.set_setting("composition/constraints", constraints)
	_window.open()

	# Il doit y avoir au moins un enfant dans ConstraintsContainer
	var container = _window.get_node("%ConstraintsContainer")
	assert_gt(container.get_child_count(), 0)

	# Simuler la suppression interne
	_window._on_delete_constraint(0)
	assert_eq(_window._draft_constraints.size(), 0)
