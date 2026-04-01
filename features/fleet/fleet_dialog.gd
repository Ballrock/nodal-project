class_name FleetDialog
extends Window

## Dialogue modal centré pour créer ou modifier une flotte de drones.
## Masqué par défaut. Ouvert via open_create() ou open_edit(fleet).

signal fleet_created(fleet: FleetData)
signal fleet_updated(fleet: FleetData)
signal fleet_deleted(fleet: FleetData)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _type_option: OptionButton = %TypeOption
@onready var _count_spin: SpinBox = %CountSpin
@onready var _validate_btn: Button = %ValidateBtn
@onready var _cancel_btn: Button = %CancelBtn
@onready var _delete_btn: Button = %DeleteBtn

## Flotte en cours d'édition (null = mode création).
var _editing_fleet: FleetData = null

func _ready() -> void:
	visible = false
	WindowHelper.setup_window(self)
	close_requested.connect(_close)
	_validate_btn.pressed.connect(_on_validate)
	_cancel_btn.pressed.connect(_close)
	_delete_btn.pressed.connect(_on_delete)

	# Remplir les types de drones
	_type_option.clear()
	_type_option.add_item("RIFF", FleetData.DroneType.DRONE_RIFF)
	_type_option.add_item("EMO", FleetData.DroneType.DRONE_EMO)

	_count_spin.min_value = 1
	_count_spin.max_value = 9999
	_count_spin.step = 1
	_count_spin.value = 1

func _show() -> void:
	WindowHelper.popup_fitted(self)
	_name_edit.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

## Ouvre le dialogue en mode création.
func open_create() -> void:
	_editing_fleet = null
	title = "Nouvelle flotte"
	_name_edit.text = ""
	_type_option.select(0)
	_count_spin.value = 1
	_delete_btn.visible = false
	_show()

## Ouvre le dialogue en mode édition d'une flotte existante.
func open_edit(fleet: FleetData) -> void:
	_editing_fleet = fleet
	title = "Modifier la flotte : " + fleet.name
	_name_edit.text = fleet.name
	# Sélectionne le bon type
	for i in _type_option.item_count:
		if _type_option.get_item_id(i) == fleet.drone_type:
			_type_option.select(i)
			break
	_count_spin.value = fleet.drone_count
	_delete_btn.visible = true
	_show()

func _close() -> void:
	hide()
	_editing_fleet = null

func _on_validate() -> void:
	var fleet_name := _name_edit.text.strip_edges()
	if fleet_name.is_empty():
		# Flash le champ nom pour indiquer l'erreur
		_name_edit.grab_focus()
		return

	if _editing_fleet:
		# Mode édition
		_editing_fleet.name = fleet_name
		_editing_fleet.drone_type = _type_option.get_selected_id()
		_editing_fleet.drone_count = int(_count_spin.value)
		fleet_updated.emit(_editing_fleet)
	else:
		# Mode création
		var fleet: FleetData = FleetData.create(
			fleet_name,
			_type_option.get_selected_id(),
			int(_count_spin.value),
		)
		fleet_created.emit(fleet)

	_close()

func _on_delete() -> void:
	if _editing_fleet:
		fleet_deleted.emit(_editing_fleet)
		_close()
