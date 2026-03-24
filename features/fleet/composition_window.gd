class_name CompositionWindow
extends Window

## Fenêtre native d'édition de la composition (total drones + contraintes).
## Ouverte depuis le bouton "Éditer" du panneau Composition.

signal composition_changed

const ConstraintDialogScene := preload("res://features/fleet/constraint_dialog.tscn")

@onready var _icon_font: Font = load("res://assets/fonts/material_symbols_rounded.ttf")
@onready var _total_spin: SpinBox = %TotalSpin
@onready var _summary_bar: CompositionBar = %SummaryBar
@onready var _summary_label: Label = %SummaryLabel
@onready var _constraints_container: VBoxContainer = %ConstraintsContainer
@onready var _add_constraint_btn: Button = %AddConstraintBtn
@onready var _apply_btn: Button = %ApplyBtn
@onready var _cancel_btn: Button = %CancelBtn

var _draft_total: int = 0
var _draft_constraints: Array[DroneConstraint] = []


func _ready() -> void:
	visible = false
	force_native = true
	content_scale_factor = DisplayServer.screen_get_scale()
	transient = false
	exclusive = false

	close_requested.connect(_close)
	_apply_btn.pressed.connect(_on_apply)
	_cancel_btn.pressed.connect(_close)
	_add_constraint_btn.pressed.connect(_on_add_constraint)
	_total_spin.value_changed.connect(_on_total_changed)
	# Live update: react to each keystroke in the SpinBox's inner LineEdit
	_total_spin.get_line_edit().text_changed.connect(_on_total_text_changed)


func open() -> void:
	_load_draft()
	_refresh()
	WindowHelper.popup_fitted(self, 0.85, false)


func _close() -> void:
	hide()


func _load_draft() -> void:
	_draft_total = int(SettingsManager.get_setting("composition/total_drones"))
	_draft_constraints.clear()
	var constraints_raw = SettingsManager.get_setting("composition/constraints")
	if constraints_raw is Array:
		for d in constraints_raw:
			if d is Dictionary:
				_draft_constraints.append(DroneConstraint.from_dict(d))


func _refresh() -> void:
	_total_spin.value = _draft_total
	_update_summary()
	_rebuild_constraint_list()


func _on_total_changed(val: float) -> void:
	_draft_total = int(val)
	_update_summary()


func _on_total_text_changed(new_text: String) -> void:
	var val := int(new_text) if new_text.is_valid_int() else 0
	_total_spin.value = val


func _update_summary() -> void:
	var nacelles_catalog := _get_nacelles_catalog()
	var effects_catalog := _get_effects_catalog()

	var riff_count := 0
	var emo_count := 0
	var unresolved := 0
	var allocated := 0

	for p in _draft_constraints:
		allocated += p.quantity
		var implications := p.resolve_implications(nacelles_catalog, effects_catalog)
		var types: Array = implications.get("implied_drone_types", [])
		if types.size() == 1:
			if int(types[0]) == FleetData.DroneType.DRONE_RIFF:
				riff_count += p.quantity
			else:
				emo_count += p.quantity
		elif types.size() > 1:
			unresolved += p.quantity
		else:
			# No type resolved (payload, etc.)
			unresolved += p.quantity

	_summary_bar.update_bar(riff_count, emo_count, unresolved, _draft_total)

	if unresolved > 0:
		_summary_label.text = "RIFF: %d  |  EMO: %d  |  Non résolu: %d  |  Alloués: %d / %d" % [riff_count, emo_count, unresolved, allocated, _draft_total]
	else:
		_summary_label.text = "RIFF: %d  |  EMO: %d  |  Alloués: %d / %d" % [riff_count, emo_count, allocated, _draft_total]
	if allocated == _draft_total:
		_summary_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	elif allocated > _draft_total:
		_summary_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		_summary_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))


func _rebuild_constraint_list() -> void:
	for child in _constraints_container.get_children():
		child.queue_free()

	var nacelles_catalog := _get_nacelles_catalog()
	var effects_catalog := _get_effects_catalog()

	for i in _draft_constraints.size():
		var constraint := _draft_constraints[i]
		var row := _create_constraint_row(constraint, i, nacelles_catalog, effects_catalog)
		_constraints_container.add_child(row)

	if _draft_constraints.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucune contrainte. Cliquez + Contrainte pour commencer."
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_constraints_container.add_child(empty_label)


func _create_constraint_row(constraint: DroneConstraint, index: int, nacelles_catalog: Array, effects_catalog: Array) -> PanelContainer:
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

	# Title: name × quantity
	var title_label := Label.new()
	title_label.text = "%s  ×%d" % [constraint.name, constraint.quantity]
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	info_vbox.add_child(title_label)

	# Category + value display
	var value_display := constraint.get_value_display_label(nacelles_catalog, effects_catalog)
	var cat_label := Label.new()
	cat_label.text = "%s: %s" % [constraint.get_category_label(), value_display]
	cat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	cat_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(cat_label)

	# Implications
	var implications := constraint.resolve_implications(nacelles_catalog, effects_catalog)

	# Nacelle implication (for PYRO_EFFECT)
	if constraint.category == DroneConstraint.ConstraintCategory.PYRO_EFFECT:
		var nacelle_names: Array = implications.get("implied_nacelle_names", [])
		if nacelle_names.size() > 0:
			var impl_label := Label.new()
			if implications.get("nacelle_resolved", false):
				impl_label.text = "  ↳ Nacelle : %s" % str(nacelle_names[0])
				impl_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			else:
				impl_label.text = "  ↳ Nacelle : %s" % " / ".join(nacelle_names)
				impl_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			impl_label.add_theme_font_size_override("font_size", 11)
			info_vbox.add_child(impl_label)

	# Drone type implication (for NACELLE and PYRO_EFFECT)
	if constraint.category in [DroneConstraint.ConstraintCategory.NACELLE, DroneConstraint.ConstraintCategory.PYRO_EFFECT]:
		var type_labels: Array = implications.get("implied_drone_type_labels", [])
		if type_labels.size() > 0:
			var type_impl := Label.new()
			if implications.get("type_resolved", false):
				type_impl.text = "  ↳ Type drone : %s" % str(type_labels[0])
				type_impl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			else:
				type_impl.text = "  ↳ Type drone : %s" % " / ".join(type_labels)
				type_impl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			type_impl.add_theme_font_size_override("font_size", 11)
			info_vbox.add_child(type_impl)

	# Info button for NACELLE constraints (hover to see nacelle details)
	if constraint.category == DroneConstraint.ConstraintCategory.NACELLE:
		var info_btn := Button.new()
		info_btn.text = "i"
		info_btn.flat = true
		info_btn.custom_minimum_size = Vector2(28, 28)
		info_btn.add_theme_font_size_override("font_size", 14)
		info_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		info_btn.tooltip_text = ""
		info_btn.mouse_default_cursor_shape = Control.CURSOR_HELP

		var nacelle_def := _find_nacelle_definition(constraint.value)
		if nacelle_def:
			info_btn.mouse_entered.connect(func(): _show_nacelle_popup(info_btn, nacelle_def))
			info_btn.mouse_exited.connect(func(): _hide_nacelle_popup())
		hbox.add_child(info_btn)

	var edit_btn := Button.new()
	edit_btn.text = "edit"
	edit_btn.flat = true
	edit_btn.add_theme_font_override("font", _icon_font)
	var idx := index
	edit_btn.pressed.connect(func(): _on_edit_constraint(idx))
	hbox.add_child(edit_btn)

	var del_btn := Button.new()
	del_btn.text = "delete"
	del_btn.flat = true
	del_btn.add_theme_font_override("font", _icon_font)
	del_btn.pressed.connect(func(): _on_delete_constraint(idx))
	hbox.add_child(del_btn)

	return panel


func _on_add_constraint() -> void:
	var dialog := ConstraintDialogScene.instantiate()
	add_child(dialog)
	dialog.open_create()
	dialog.constraint_created.connect(func(p: DroneConstraint):
		_draft_constraints.append(p)
		_refresh()
		dialog.queue_free()
	)
	dialog.close_requested.connect(func(): dialog.queue_free())


func _on_edit_constraint(index: int) -> void:
	if index < 0 or index >= _draft_constraints.size():
		return
	var constraint := _draft_constraints[index]
	var dialog := ConstraintDialogScene.instantiate()
	add_child(dialog)
	dialog.open_edit(constraint)
	dialog.constraint_updated.connect(func(_p: DroneConstraint):
		_refresh()
		dialog.queue_free()
	)
	dialog.constraint_deleted.connect(func(_p: DroneConstraint):
		_draft_constraints.remove_at(index)
		_refresh()
		dialog.queue_free()
	)
	dialog.close_requested.connect(func(): dialog.queue_free())


func _on_delete_constraint(index: int) -> void:
	if index < 0 or index >= _draft_constraints.size():
		return
	_draft_constraints.remove_at(index)
	_refresh()


func _on_apply() -> void:
	SettingsManager.set_setting("composition/total_drones", float(_draft_total))
	var constraints_arr: Array = []
	for p in _draft_constraints:
		constraints_arr.append(p.to_dict())
	SettingsManager.set_setting("composition/constraints", constraints_arr)
	composition_changed.emit()
	_close()


func _get_nacelles_catalog() -> Array:
	var nacelles: Array = []
	var raw = SettingsManager.get_setting("composition/nacelles")
	if raw is Array:
		nacelles = raw
	return nacelles


func _get_effects_catalog() -> Array:
	var effects: Array = []
	var raw = SettingsManager.get_setting("composition/effects")
	if raw is Array:
		effects.append_array(raw)
	var pyro_raw = SettingsManager.get_setting("composition/pyro_effects")
	if pyro_raw is Array:
		effects.append_array(pyro_raw)
	return effects


## Popup flottante pour les details nacelle
var _nacelle_popup: PopupPanel = null


func _find_nacelle_definition(nacelle_value: String) -> NacelleDefinition:
	if not NacelleManager.is_loaded():
		return null
	for n in NacelleManager.get_nacelles():
		if n.name == nacelle_value or str(n.id) == nacelle_value:
			return n
	return null


func _show_nacelle_popup(anchor: Control, nacelle_def: NacelleDefinition) -> void:
	_hide_nacelle_popup()

	_nacelle_popup = PopupPanel.new()
	_nacelle_popup.transparent = true
	_nacelle_popup.popup_window = false
	add_child(_nacelle_popup)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	style.border_color = Color(0.35, 0.45, 0.6, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_nacelle_popup.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_nacelle_popup.add_child(content)

	# Titre
	var title_label := Label.new()
	title_label.text = nacelle_def.name
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	content.add_child(title_label)

	content.add_child(HSeparator.new())

	# Infos generales
	var info_parts: PackedStringArray = []
	if not nacelle_def.type_drone.is_empty():
		info_parts.append("Drone : %s" % nacelle_def.type_drone)
	if not nacelle_def.mount_type.is_empty():
		info_parts.append("Montage : %s" % nacelle_def.get_mount_type_label())
	if nacelle_def.weight > 0:
		info_parts.append("Poids : %d g" % nacelle_def.weight)

	if not info_parts.is_empty():
		var info_label := Label.new()
		info_label.text = " | ".join(info_parts)
		info_label.add_theme_font_size_override("font_size", 12)
		info_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		content.add_child(info_label)

	# Channels
	if not nacelle_def.effects.is_empty():
		var ch_title := Label.new()
		ch_title.text = "Channels (%d)" % nacelle_def.effects.size()
		ch_title.add_theme_font_size_override("font_size", 13)
		ch_title.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
		content.add_child(ch_title)

		# Header
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		content.add_child(header)

		for col_text in ["Channel", "Angle H", "Angle P"]:
			var col := Label.new()
			col.text = col_text
			col.custom_minimum_size.x = 75
			col.add_theme_font_size_override("font_size", 11)
			col.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
			header.add_child(col)

		# Rows
		for effect in nacelle_def.effects:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			content.add_child(row)

			var ch_label := Label.new()
			ch_label.text = "Ch %d" % int(effect.get("channel", 0))
			ch_label.custom_minimum_size.x = 75
			ch_label.add_theme_font_size_override("font_size", 12)
			ch_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			row.add_child(ch_label)

			var ah_label := Label.new()
			ah_label.text = "%.1f°" % float(effect.get("angleH", 0.0))
			ah_label.custom_minimum_size.x = 75
			ah_label.add_theme_font_size_override("font_size", 12)
			ah_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
			row.add_child(ah_label)

			var ap_label := Label.new()
			ap_label.text = "%.1f°" % float(effect.get("angleP", 0.0))
			ap_label.custom_minimum_size.x = 75
			ap_label.add_theme_font_size_override("font_size", 12)
			ap_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
			row.add_child(ap_label)
	else:
		var no_ch := Label.new()
		no_ch.text = "Aucun channel"
		no_ch.add_theme_font_size_override("font_size", 12)
		no_ch.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(no_ch)

	# Position the popup near the anchor
	var anchor_rect := anchor.get_global_rect()
	var popup_pos := Vector2i(int(anchor_rect.position.x - 250), int(anchor_rect.end.y + 4))
	_nacelle_popup.popup(Rect2i(popup_pos, Vector2i(0, 0)))


func _hide_nacelle_popup() -> void:
	if _nacelle_popup and is_instance_valid(_nacelle_popup):
		_nacelle_popup.queue_free()
		_nacelle_popup = null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_close()
		get_viewport().set_input_as_handled()
