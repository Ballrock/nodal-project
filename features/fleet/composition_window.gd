class_name CompositionWindow
extends Window

## Fenêtre native d'édition de la composition (total drones + profils).
## Ouverte depuis le bouton "Éditer" du panneau Composition.

signal composition_changed

const ProfileDialogScene := preload("res://features/fleet/profile_dialog.tscn")

@onready var _total_spin: SpinBox = %TotalSpin
@onready var _summary_bar: ProgressBar = %SummaryBar
@onready var _summary_label: Label = %SummaryLabel
@onready var _profiles_container: VBoxContainer = %ProfilesContainer
@onready var _add_profile_btn: Button = %AddProfileBtn
@onready var _apply_btn: Button = %ApplyBtn
@onready var _cancel_btn: Button = %CancelBtn

var _draft_total: int = 0
var _draft_profiles: Array[DroneProfile] = []


func _ready() -> void:
	visible = false
	force_native = true
	content_scale_factor = DisplayServer.screen_get_scale()
	transient = false
	exclusive = false

	close_requested.connect(_close)
	_apply_btn.pressed.connect(_on_apply)
	_cancel_btn.pressed.connect(_close)
	_add_profile_btn.pressed.connect(_on_add_profile)
	_total_spin.value_changed.connect(_on_total_changed)


func open() -> void:
	_load_draft()
	_refresh()
	popup_centered()


func _close() -> void:
	hide()


func _load_draft() -> void:
	_draft_total = int(SettingsManager.get_setting("composition/total_drones"))
	_draft_profiles.clear()
	var profiles_raw = SettingsManager.get_setting("composition/profiles")
	if profiles_raw is Array:
		for d in profiles_raw:
			if d is Dictionary:
				_draft_profiles.append(DroneProfile.from_dict(d))


func _refresh() -> void:
	_total_spin.value = _draft_total
	_update_summary()
	_rebuild_profile_list()


func _on_total_changed(val: float) -> void:
	_draft_total = int(val)
	_update_summary()


func _update_summary() -> void:
	var riff_count := 0
	var emo_count := 0
	var allocated := 0
	for p in _draft_profiles:
		allocated += p.quantity
		if p.drone_type == FleetData.DroneType.DRONE_RIFF:
			riff_count += p.quantity
		else:
			emo_count += p.quantity

	if _draft_total > 0:
		_summary_bar.value = float(riff_count) / float(_draft_total) * 100.0
	else:
		_summary_bar.value = 0.0

	_summary_label.text = "RIFF: %d  |  EMO: %d  |  Alloués: %d / %d" % [riff_count, emo_count, allocated, _draft_total]
	if allocated == _draft_total:
		_summary_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	elif allocated > _draft_total:
		_summary_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		_summary_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))


func _rebuild_profile_list() -> void:
	for child in _profiles_container.get_children():
		child.queue_free()

	var nacelle_map := _build_nacelle_map()

	for i in _draft_profiles.size():
		var profile := _draft_profiles[i]
		var row := _create_profile_row(profile, i, nacelle_map)
		_profiles_container.add_child(row)

	if _draft_profiles.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucun profil. Cliquez + Profil pour commencer."
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_profiles_container.add_child(empty_label)


func _create_profile_row(profile: DroneProfile, index: int, nacelle_map: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.22, 1.0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var title_label := Label.new()
	title_label.text = "%s  ×%d" % [profile.name, profile.quantity]
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	info_vbox.add_child(title_label)

	var nacelle_name: String = nacelle_map.get(str(profile.nacelle_id), "—")
	var effects_parts: Array[String] = []
	for e in profile.effects:
		var v: String = str(e.get("variant", ""))
		if v != "":
			effects_parts.append(v)
	var effects_str := ", ".join(effects_parts) if effects_parts.size() > 0 else "aucun effet"

	var sub_label := Label.new()
	sub_label.text = "%s · %s · %s" % [profile.get_drone_type_label(), nacelle_name, effects_str]
	sub_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	sub_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(sub_label)

	var edit_btn := Button.new()
	edit_btn.text = "✏️"
	edit_btn.flat = true
	var idx := index
	edit_btn.pressed.connect(func(): _on_edit_profile(idx))
	hbox.add_child(edit_btn)

	var del_btn := Button.new()
	del_btn.text = "🗑"
	del_btn.flat = true
	del_btn.pressed.connect(func(): _on_delete_profile(idx))
	hbox.add_child(del_btn)

	return panel


func _on_add_profile() -> void:
	var dialog := ProfileDialogScene.instantiate()
	add_child(dialog)
	dialog.open_create()
	dialog.profile_created.connect(func(p: DroneProfile):
		_draft_profiles.append(p)
		_refresh()
		dialog.queue_free()
	)
	dialog.close_requested.connect(func(): dialog.queue_free())


func _on_edit_profile(index: int) -> void:
	if index < 0 or index >= _draft_profiles.size():
		return
	var profile := _draft_profiles[index]
	var dialog := ProfileDialogScene.instantiate()
	add_child(dialog)
	dialog.open_edit(profile)
	dialog.profile_updated.connect(func(_p: DroneProfile):
		_refresh()
		dialog.queue_free()
	)
	dialog.profile_deleted.connect(func(_p: DroneProfile):
		_draft_profiles.remove_at(index)
		_refresh()
		dialog.queue_free()
	)
	dialog.close_requested.connect(func(): dialog.queue_free())


func _on_delete_profile(index: int) -> void:
	if index < 0 or index >= _draft_profiles.size():
		return
	_draft_profiles.remove_at(index)
	_refresh()


func _on_apply() -> void:
	SettingsManager.set_setting("composition/total_drones", float(_draft_total))
	var profiles_arr: Array = []
	for p in _draft_profiles:
		profiles_arr.append(p.to_dict())
	SettingsManager.set_setting("composition/profiles", profiles_arr)
	composition_changed.emit()
	_close()


func _build_nacelle_map() -> Dictionary:
	var nacelle_map: Dictionary = {}
	var nacelles_raw = SettingsManager.get_setting("composition/nacelles")
	if nacelles_raw is Array:
		for n in nacelles_raw:
			if n is Dictionary:
				nacelle_map[str(n.get("id", ""))] = str(n.get("name", ""))
	return nacelle_map


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_close()
		get_viewport().set_input_as_handled()
