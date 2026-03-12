extends GutTest

## Tests unitaires pour ProfileDialog.

const ProfileDialogScene := preload("res://features/fleet/profile_dialog.tscn")

var _dialog: ProfileDialog = null
var SettingsManagerClass = load("res://core/settings/settings_manager.gd")
var _sm = null


func before_each() -> void:
	_sm = SettingsManagerClass.new()
	_sm.name = "SettingsManager"
	add_child(_sm)
	await get_tree().process_frame

	_dialog = ProfileDialogScene.instantiate()
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
	assert_eq(_dialog.title, "Nouveau profil")
	assert_eq(_dialog.get_node("%ProfileNameEdit").text, "")
	assert_false(_dialog.get_node("%ProfileDeleteBtn").visible)


func test_open_edit() -> void:
	var effects: Array[Dictionary] = [{"effect_id": &"effect_pyro", "variant": "Bengale verte"}]
	var profile := DroneProfile.create("TestProfile", FleetData.DroneType.DRONE_RIFF, &"nacelle_standard", effects, 50)
	_dialog.open_edit(profile)
	assert_true(_dialog.visible)
	assert_eq(_dialog.get_node("%ProfileNameEdit").text, "TestProfile")
	assert_eq(int(_dialog.get_node("%QuantitySpin").value), 50)
	assert_true(_dialog.get_node("%ProfileDeleteBtn").visible)


func test_validate_create_emits_signal() -> void:
	watch_signals(_dialog)
	_dialog.open_create()
	_dialog.get_node("%ProfileNameEdit").text = "Bengales"
	_dialog.get_node("%QuantitySpin").value = 200

	_dialog.get_node("%ProfileValidateBtn").pressed.emit()

	assert_signal_emitted(_dialog, "profile_created")
	var args = get_signal_parameters(_dialog, "profile_created")
	var profile: DroneProfile = args[0]
	assert_eq(profile.name, "Bengales")
	assert_eq(profile.quantity, 200)
	assert_false(_dialog.visible)


func test_validate_empty_name_does_not_emit() -> void:
	watch_signals(_dialog)
	_dialog.open_create()
	_dialog.get_node("%ProfileNameEdit").text = "  "

	_dialog.get_node("%ProfileValidateBtn").pressed.emit()

	assert_signal_not_emitted(_dialog, "profile_created")
	assert_true(_dialog.visible)


func test_validate_edit_emits_signal() -> void:
	var profile := DroneProfile.create("OldName", 0, &"nacelle_standard", [], 1)
	watch_signals(_dialog)
	_dialog.open_edit(profile)
	_dialog.get_node("%ProfileNameEdit").text = "NewName"
	_dialog.get_node("%QuantitySpin").value = 300

	_dialog.get_node("%ProfileValidateBtn").pressed.emit()

	assert_signal_emitted(_dialog, "profile_updated")
	assert_eq(profile.name, "NewName")
	assert_eq(profile.quantity, 300)


func test_delete_emits_signal() -> void:
	var profile := DroneProfile.create("ToDelete", 0, &"", [], 1)
	watch_signals(_dialog)
	_dialog.open_edit(profile)

	_dialog.get_node("%ProfileDeleteBtn").pressed.emit()

	assert_signal_emitted(_dialog, "profile_deleted")
	assert_false(_dialog.visible)


func test_cancel_closes_dialog() -> void:
	_dialog.open_create()
	_dialog.get_node("%ProfileCancelBtn").pressed.emit()
	assert_false(_dialog.visible)


func test_nacelle_filter_by_drone_type() -> void:
	_dialog.open_create()
	var nacelle_option: OptionButton = _dialog.get_node("%NacelleOption")

	# Default is RIFF (type 0) — should show Standard and PyroLight (not LaserMount)
	var nacelle_names: Array[String] = []
	for i in nacelle_option.item_count:
		nacelle_names.append(nacelle_option.get_item_text(i))

	assert_true(nacelle_names.has("Standard"), "Standard doit être compatible RIFF")
	assert_true(nacelle_names.has("PyroLight"), "PyroLight doit être compatible RIFF")
	assert_false(nacelle_names.has("LaserMount"), "LaserMount ne doit PAS être compatible RIFF")


func test_nacelle_filter_emo() -> void:
	_dialog.open_create()
	# Switch to EMO
	var type_option: OptionButton = _dialog.get_node("%DroneTypeOption")
	for i in type_option.item_count:
		if type_option.get_item_id(i) == FleetData.DroneType.DRONE_EMO:
			type_option.select(i)
			type_option.item_selected.emit(i)
			break

	var nacelle_option: OptionButton = _dialog.get_node("%NacelleOption")
	var nacelle_names: Array[String] = []
	for i in nacelle_option.item_count:
		nacelle_names.append(nacelle_option.get_item_text(i))

	assert_true(nacelle_names.has("Standard"), "Standard doit être compatible EMO")
	assert_true(nacelle_names.has("LaserMount"), "LaserMount doit être compatible EMO")
	assert_false(nacelle_names.has("PyroLight"), "PyroLight ne doit PAS être compatible EMO")


func test_effects_shown_for_nacelle() -> void:
	_dialog.open_create()
	# Default nacelle is first compatible (Standard for RIFF)
	var effects_container: VBoxContainer = _dialog.get_node("%EffectsContainer")
	assert_gt(effects_container.get_child_count(), 0, "Doit afficher au moins un effet")
