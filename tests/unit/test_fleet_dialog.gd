extends GutTest

## Tests unitaires pour FleetDialog.

const FleetDialogScene := preload("res://features/fleet/fleet_dialog.tscn")

var _dialog: FleetDialog = null

func before_each() -> void:
	_dialog = FleetDialogScene.instantiate()
	add_child_autofree(_dialog)
	# On attend un frame pour que @onready soit prêt
	await get_tree().process_frame


func test_initial_state() -> void:
	assert_false(_dialog.visible, "Le dialogue doit être masqué au départ")
	assert_eq(_dialog.get_node("%TypeOption").item_count, 2, "Doit avoir 2 types de drones")


func test_open_create() -> void:
	_dialog.open_create()
	assert_true(_dialog.visible, "Doit être visible")
	assert_eq(_dialog.get_node("%DialogTitle").text, "Nouvelle flotte")
	assert_eq(_dialog.get_node("%NameEdit").text, "")
	assert_false(_dialog.get_node("%DeleteBtn").visible, "Bouton supprimer masqué en création")


func test_open_edit() -> void:
	var fleet := FleetData.create("Alpha", FleetData.DroneType.DRONE_EMO, 10)
	_dialog.open_edit(fleet)
	assert_true(_dialog.visible)
	assert_eq(_dialog.get_node("%DialogTitle").text, "Modifier la flotte")
	assert_eq(_dialog.get_node("%NameEdit").text, "Alpha")
	assert_eq(_dialog.get_node("%CountSpin").value, 10)
	assert_true(_dialog.get_node("%DeleteBtn").visible, "Bouton supprimer visible en édition")


func test_validate_create_emits_signal() -> void:
	watch_signals(_dialog)
	_dialog.open_create()
	_dialog.get_node("%NameEdit").text = "NewFleet"
	_dialog.get_node("%TypeOption").select(1) # EMO
	_dialog.get_node("%CountSpin").value = 5
	
	_dialog.get_node("%ValidateBtn").pressed.emit()
	
	assert_signal_emitted(_dialog, "fleet_created")
	var args = get_signal_parameters(_dialog, "fleet_created")
	var fleet: FleetData = args[0]
	assert_eq(fleet.name, "NewFleet")
	assert_eq(fleet.drone_type, FleetData.DroneType.DRONE_EMO)
	assert_eq(fleet.drone_count, 5)
	assert_false(_dialog.visible, "Le dialogue doit se fermer après validation")


func test_validate_edit_emits_signal() -> void:
	var fleet := FleetData.create("OldName", FleetData.DroneType.DRONE_RIFF, 1)
	watch_signals(_dialog)
	_dialog.open_edit(fleet)
	_dialog.get_node("%NameEdit").text = "UpdatedName"
	
	_dialog.get_node("%ValidateBtn").pressed.emit()
	
	assert_signal_emitted(_dialog, "fleet_updated")
	assert_eq(fleet.name, "UpdatedName")


func test_validate_empty_name_does_not_emit_signal() -> void:
	watch_signals(_dialog)
	_dialog.open_create()
	_dialog.get_node("%NameEdit").text = "  " # Vide après strip
	
	_dialog.get_node("%ValidateBtn").pressed.emit()
	
	assert_signal_not_emitted(_dialog, "fleet_created")
	assert_true(_dialog.visible, "Le dialogue doit rester ouvert")


func test_delete_emits_signal() -> void:
	var fleet := FleetData.create("ToKill", FleetData.DroneType.DRONE_RIFF, 1)
	watch_signals(_dialog)
	_dialog.open_edit(fleet)
	
	_dialog.get_node("%DeleteBtn").pressed.emit()
	
	assert_signal_emitted(_dialog, "fleet_deleted")
	assert_false(_dialog.visible)


func test_cancel_closes_dialog() -> void:
	_dialog.open_create()
	_dialog.get_node("%CancelBtn").pressed.emit()
	assert_false(_dialog.visible)


func test_overlay_click_closes_dialog() -> void:
	_dialog.open_create()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_dialog.get_node("%Overlay").gui_input.emit(event)
	assert_false(_dialog.visible)


func test_esc_closes_dialog() -> void:
	_dialog.open_create()
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	_dialog._input(event)
	assert_false(_dialog.visible)
