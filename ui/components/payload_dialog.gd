class_name PayloadDialog
extends Window

## Dialogue modal pour creer ou modifier un payload.

signal payload_saved(data: Dictionary, index: int)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _riff_check: CheckBox = %RiffCheck
@onready var _emo_check: CheckBox = %EmoCheck
@onready var _nacelle_flow: HFlowContainer = %NacelleFlow
@onready var _validate_btn: Button = %ValidateBtn
@onready var _cancel_btn: Button = %CancelBtn

var _editing_index: int = -1
var _nacelle_checks: Array[CheckBox] = []


func _ready() -> void:
	visible = false
	force_native = true
	content_scale_factor = DisplayServer.screen_get_scale()
	transient = true
	exclusive = true

	_validate_btn.pressed.connect(_on_validate)
	_cancel_btn.pressed.connect(_close)


func open_create(nacelles_catalog: Array) -> void:
	_editing_index = -1
	title = "Nouveau payload"
	_name_edit.text = ""
	_riff_check.button_pressed = false
	_emo_check.button_pressed = false
	_build_nacelle_checks(nacelles_catalog, [])
	_show_dialog()


func open_edit(index: int, pl: Dictionary, nacelles_catalog: Array) -> void:
	_editing_index = index
	title = "Modifier : %s" % str(pl.get("name", ""))
	_name_edit.text = str(pl.get("name", ""))

	var compat_types = pl.get("compatible_drone_types", [])
	_riff_check.button_pressed = (0 in compat_types)
	_emo_check.button_pressed = (1 in compat_types)

	var compat_nacelles = pl.get("compatible_nacelle_ids", [])
	_build_nacelle_checks(nacelles_catalog, compat_nacelles)
	_show_dialog()


func _build_nacelle_checks(nacelles_catalog: Array, selected_ids: Variant) -> void:
	for child in _nacelle_flow.get_children():
		child.queue_free()
	_nacelle_checks.clear()

	if selected_ids == null:
		selected_ids = []

	for n in nacelles_catalog:
		var nid := str(n.get("id", ""))
		var nname := str(n.get("name", nid))
		var check := CheckBox.new()
		check.text = nname
		check.button_pressed = (nid in selected_ids)
		check.set_meta("nacelle_id", nid)
		_nacelle_flow.add_child(check)
		_nacelle_checks.append(check)


func _on_validate() -> void:
	var new_name := _name_edit.text.strip_edges()
	if new_name.is_empty():
		return

	var new_types: Array = []
	if _riff_check.button_pressed:
		new_types.append(0)
	if _emo_check.button_pressed:
		new_types.append(1)

	var new_nacelles: Array = []
	for check: CheckBox in _nacelle_checks:
		if check.button_pressed:
			new_nacelles.append(check.get_meta("nacelle_id"))

	var entry := {
		"name": new_name,
		"compatible_drone_types": new_types,
		"compatible_nacelle_ids": new_nacelles,
	}

	payload_saved.emit(entry, _editing_index)
	_close()


func _close() -> void:
	hide()


func _show_dialog() -> void:
	WindowHelper.popup_fitted(self, 0.85, false)
