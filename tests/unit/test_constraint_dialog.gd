extends GutTest

## Tests unitaires pour ConstraintDialog.

const ConstraintDialogScene := preload("res://features/fleet/constraint_dialog.tscn")

var _dialog: ConstraintDialog = null
var SettingsManagerClass = load("res://core/settings/settings_manager.gd")
var _sm = null


func before_each() -> void:
	_sm = SettingsManagerClass.new()
	_sm.name = "SettingsManager"
	add_child(_sm)
	await get_tree().process_frame

	_dialog = ConstraintDialogScene.instantiate()
	add_child_autofree(_dialog)
	await get_tree().process_frame


func after_each() -> void:
	if _dialog and is_instance_valid(_dialog):
		_dialog.hide()
	if _sm:
		_sm.queue_free()
		_sm = null


func test_initial_state() -> void:
	assert_false(_dialog.visible, "Le dialogue doit être masqué au départ")


func test_open_create() -> void:
	_dialog.open_create()
	assert_true(_dialog.visible)
	assert_eq(_dialog.title, "Nouvelle contrainte")
	assert_eq(_dialog.get_node("%ConstraintNameEdit").text, "")
	assert_false(_dialog.get_node("%ConstraintDeleteBtn").visible)
	assert_true(_dialog.get_node("%ConstraintValidateBtn").disabled, "Valider doit être désactivé sans sélection")


func test_open_edit() -> void:
	var constraint := DroneConstraint.create("TestProfile", DroneConstraint.ConstraintCategory.PYRO_EFFECT, "effect_pyro::Bengale verte", 50)
	_dialog.open_edit(constraint)
	assert_true(_dialog.visible)
	assert_eq(_dialog.get_node("%ConstraintNameEdit").text, "TestProfile")
	assert_eq(int(_dialog.get_node("%QuantitySpin").value), 50)
	assert_true(_dialog.get_node("%ConstraintDeleteBtn").visible)


func test_validate_create_emits_signal() -> void:
	watch_signals(_dialog)
	_dialog.open_create()

	# Select category "Type drone"
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.DRONE_TYPE:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break

	# Select value "RIFF" (index 1, index 0 is placeholder)
	var value_option: OptionButton = _dialog.get_node("%ValueOption")
	value_option.select(1)
	value_option.item_selected.emit(1)

	_dialog.get_node("%ConstraintNameEdit").text = "Bengales"
	_dialog.get_node("%QuantitySpin").value = 200

	_dialog.get_node("%ConstraintValidateBtn").pressed.emit()

	assert_signal_emitted(_dialog, "constraint_created")
	var args = get_signal_parameters(_dialog, "constraint_created")
	var constraint: DroneConstraint = args[0]
	assert_eq(constraint.name, "Bengales")
	assert_eq(constraint.quantity, 200)
	assert_false(_dialog.visible)


func test_validate_empty_name_does_not_emit() -> void:
	watch_signals(_dialog)
	_dialog.open_create()

	# Select a category and value so only name blocks validation
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.DRONE_TYPE:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break
	var value_option: OptionButton = _dialog.get_node("%ValueOption")
	value_option.select(1)
	value_option.item_selected.emit(1)

	# Clear auto-generated name (emit signal to simulate user edit)
	var name_edit := _dialog.get_node("%ConstraintNameEdit")
	name_edit.text = "  "
	name_edit.text_changed.emit("  ")

	# Validate button should be disabled with empty name
	assert_true(_dialog.get_node("%ConstraintValidateBtn").disabled)
	_dialog.get_node("%ConstraintValidateBtn").pressed.emit()

	assert_signal_not_emitted(_dialog, "constraint_created")
	assert_true(_dialog.visible)


func test_validate_edit_emits_signal() -> void:
	var constraint := DroneConstraint.create("OldName", DroneConstraint.ConstraintCategory.DRONE_TYPE, "0", 1)
	watch_signals(_dialog)
	_dialog.open_edit(constraint)
	_dialog.get_node("%ConstraintNameEdit").text = "NewName"
	_dialog.get_node("%QuantitySpin").value = 300

	_dialog.get_node("%ConstraintValidateBtn").pressed.emit()

	assert_signal_emitted(_dialog, "constraint_updated")
	assert_eq(constraint.name, "NewName")
	assert_eq(constraint.quantity, 300)


func test_delete_emits_signal() -> void:
	var constraint := DroneConstraint.create("ToDelete", DroneConstraint.ConstraintCategory.DRONE_TYPE, "0", 1)
	watch_signals(_dialog)
	_dialog.open_edit(constraint)

	_dialog.get_node("%ConstraintDeleteBtn").pressed.emit()

	assert_signal_emitted(_dialog, "constraint_deleted")
	assert_false(_dialog.visible)


func test_cancel_closes_dialog() -> void:
	_dialog.open_create()
	_dialog.get_node("%ConstraintCancelBtn").pressed.emit()
	assert_false(_dialog.visible)


func test_category_option_populated() -> void:
	_dialog.open_create()
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	assert_gt(category_option.item_count, 0, "Doit avoir des catégories")
	var labels: Array[String] = []
	for i in category_option.item_count:
		labels.append(category_option.get_item_text(i))
	assert_true(labels.has("Type drone"))
	assert_true(labels.has("Nacelle"))
	assert_true(labels.has("Payload"))
	assert_true(labels.has("Effet Pyro"))


func test_value_option_changes_with_category() -> void:
	_dialog.open_create()
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	var value_option: OptionButton = _dialog.get_node("%ValueOption")

	# Select "Nacelle" category
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.NACELLE:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break

	# item_count > 1 means at least one real item beyond the placeholder
	assert_gt(value_option.item_count, 1, "Doit afficher des nacelles (+ placeholder)")
