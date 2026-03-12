class_name ProfileDialog
extends Window

## Dialogue modal pour créer ou modifier un profil de drones.
## Gère les cascades : type drone → nacelles → effets.

signal profile_created(profile: DroneProfile)
signal profile_updated(profile: DroneProfile)
signal profile_deleted(profile: DroneProfile)

@onready var _name_edit: LineEdit = %ProfileNameEdit
@onready var _quantity_spin: SpinBox = %QuantitySpin
@onready var _type_option: OptionButton = %DroneTypeOption
@onready var _nacelle_option: OptionButton = %NacelleOption
@onready var _effects_container: VBoxContainer = %EffectsContainer
@onready var _validate_btn: Button = %ProfileValidateBtn
@onready var _cancel_btn: Button = %ProfileCancelBtn
@onready var _delete_btn: Button = %ProfileDeleteBtn

var _editing_profile: DroneProfile = null
var _nacelles: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _effect_checks: Array[Dictionary] = [] # [{check: CheckBox, variant_option: OptionButton, effect_dict: Dictionary}]


func _ready() -> void:
	visible = false
	force_native = true
	content_scale_factor = DisplayServer.screen_get_scale()
	transient = true
	exclusive = true

	_validate_btn.pressed.connect(_on_validate)
	_cancel_btn.pressed.connect(_close)
	_delete_btn.pressed.connect(_on_delete)
	_type_option.item_selected.connect(_on_type_changed)
	_nacelle_option.item_selected.connect(_on_nacelle_changed)

	_type_option.clear()
	_type_option.add_item("RIFF", FleetData.DroneType.DRONE_RIFF)
	_type_option.add_item("EMO", FleetData.DroneType.DRONE_EMO)

	_quantity_spin.min_value = 1
	_quantity_spin.max_value = 99999
	_quantity_spin.step = 1

	_load_catalogs()


func open_create() -> void:
	_editing_profile = null
	title = "Nouveau profil"
	_name_edit.text = ""
	_type_option.select(0)
	_quantity_spin.value = 1
	_delete_btn.visible = false
	_refresh_nacelles(FleetData.DroneType.DRONE_RIFF)
	_show_dialog()


func open_edit(profile: DroneProfile) -> void:
	_editing_profile = profile
	title = "Modifier le profil : " + profile.name
	_name_edit.text = profile.name
	_quantity_spin.value = profile.quantity
	_delete_btn.visible = true

	for i in _type_option.item_count:
		if _type_option.get_item_id(i) == profile.drone_type:
			_type_option.select(i)
			break

	_refresh_nacelles(profile.drone_type)

	# Select nacelle
	for i in _nacelle_option.item_count:
		if _nacelle_option.get_item_metadata(i) == str(profile.nacelle_id):
			_nacelle_option.select(i)
			break

	var sel_nacelle_id := _get_selected_nacelle_id()
	_refresh_effects(sel_nacelle_id)

	# Restore checked effects
	for ec in _effect_checks:
		var eid: String = str(ec["effect_dict"].get("id", ""))
		for pe in profile.effects:
			if str(pe.get("effect_id", "")) == eid:
				ec["check"].button_pressed = true
				if ec.has("variant_option") and ec["variant_option"] != null:
					var variant_str: String = str(pe.get("variant", ""))
					for vi in ec["variant_option"].item_count:
						if ec["variant_option"].get_item_text(vi) == variant_str:
							ec["variant_option"].select(vi)
							break
				break

	_show_dialog()


func _show_dialog() -> void:
	popup_centered()
	_name_edit.grab_focus()


func _close() -> void:
	hide()
	_editing_profile = null


func _load_catalogs() -> void:
	_nacelles.clear()
	_effects.clear()
	var nacelles_raw = SettingsManager.get_setting("composition/nacelles")
	if nacelles_raw is Array:
		for n in nacelles_raw:
			if n is Dictionary:
				_nacelles.append(n)

	var effects_raw = SettingsManager.get_setting("composition/effects")
	if effects_raw is Array:
		for e in effects_raw:
			if e is Dictionary:
				_effects.append(e)


func _on_type_changed(_index: int) -> void:
	var drone_type: int = _type_option.get_selected_id()
	_refresh_nacelles(drone_type)


func _refresh_nacelles(drone_type: int) -> void:
	_nacelle_option.clear()
	for n in _nacelles:
		var compatible_types = n.get("compatible_drone_types", [])
		var is_compatible := false
		for t in compatible_types:
			if int(t) == drone_type:
				is_compatible = true
				break
		if is_compatible:
			var idx := _nacelle_option.item_count
			_nacelle_option.add_item(str(n.get("name", "")))
			_nacelle_option.set_item_metadata(idx, str(n.get("id", "")))

	if _nacelle_option.item_count > 0:
		_nacelle_option.select(0)
		_refresh_effects(_get_selected_nacelle_id())
	else:
		_refresh_effects(&"")


func _on_nacelle_changed(_index: int) -> void:
	_refresh_effects(_get_selected_nacelle_id())


func _get_selected_nacelle_id() -> StringName:
	if _nacelle_option.selected < 0 or _nacelle_option.item_count == 0:
		return &""
	return StringName(str(_nacelle_option.get_item_metadata(_nacelle_option.selected)))


func _refresh_effects(nacelle_id: StringName) -> void:
	for child in _effects_container.get_children():
		child.queue_free()
	_effect_checks.clear()

	for e in _effects:
		var eid: String = str(e.get("id", ""))
		var ename: String = str(e.get("name", ""))
		var compatible_nacelle_ids = e.get("compatible_nacelle_ids", [])
		var is_compatible := false
		for nid in compatible_nacelle_ids:
			if StringName(str(nid)) == nacelle_id:
				is_compatible = true
				break

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var check := CheckBox.new()
		check.text = ename
		check.disabled = not is_compatible
		if not is_compatible:
			check.tooltip_text = "Incompatible avec la nacelle sélectionnée"
			check.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(check)

		var entry: Dictionary = {"check": check, "effect_dict": e, "variant_option": null}

		var variants = e.get("variants", [])
		if variants.size() > 0:
			var variant_option := OptionButton.new()
			variant_option.custom_minimum_size.x = 140
			for v in variants:
				variant_option.add_item(str(v))
			if variant_option.item_count > 0:
				variant_option.select(0)
			variant_option.disabled = not is_compatible
			row.add_child(variant_option)
			entry["variant_option"] = variant_option

		_effects_container.add_child(row)
		_effect_checks.append(entry)


func _on_validate() -> void:
	var profile_name := _name_edit.text.strip_edges()
	if profile_name.is_empty():
		_name_edit.grab_focus()
		return

	var effects_arr: Array[Dictionary] = []
	for ec in _effect_checks:
		if ec["check"].button_pressed and not ec["check"].disabled:
			var eid: String = str(ec["effect_dict"].get("id", ""))
			var variant := ""
			if ec["variant_option"] != null:
				variant = ec["variant_option"].get_item_text(ec["variant_option"].selected) if ec["variant_option"].selected >= 0 else ""
			effects_arr.append({"effect_id": StringName(eid), "variant": variant})

	if _editing_profile:
		_editing_profile.name = profile_name
		_editing_profile.quantity = int(_quantity_spin.value)
		_editing_profile.drone_type = _type_option.get_selected_id()
		_editing_profile.nacelle_id = _get_selected_nacelle_id()
		_editing_profile.effects = effects_arr
		profile_updated.emit(_editing_profile)
	else:
		var profile := DroneProfile.create(
			profile_name,
			_type_option.get_selected_id(),
			_get_selected_nacelle_id(),
			effects_arr,
			int(_quantity_spin.value),
		)
		profile_created.emit(profile)

	_close()


func _on_delete() -> void:
	if _editing_profile:
		profile_deleted.emit(_editing_profile)
		_close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
