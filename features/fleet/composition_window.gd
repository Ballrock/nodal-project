class_name CompositionWindow
extends Window

## Fenêtre native d'édition de la composition (total drones + contraintes).
## Ouverte depuis le bouton "Éditer" du panneau Composition.

signal composition_changed

const ConstraintDialogScene := preload("res://features/fleet/constraint_dialog.tscn")

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
	popup_centered()


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
				impl_label.text = "  ↳ Nacelle : %s  ⚡" % str(nacelle_names[0])
				impl_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			else:
				impl_label.text = "  ↳ Nacelle : %s  ⚠" % " / ".join(nacelle_names)
				impl_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			impl_label.add_theme_font_size_override("font_size", 11)
			info_vbox.add_child(impl_label)

	# Drone type implication (for NACELLE and PYRO_EFFECT)
	if constraint.category in [DroneConstraint.ConstraintCategory.NACELLE, DroneConstraint.ConstraintCategory.PYRO_EFFECT]:
		var type_labels: Array = implications.get("implied_drone_type_labels", [])
		if type_labels.size() > 0:
			var type_impl := Label.new()
			if implications.get("type_resolved", false):
				type_impl.text = "  ↳ Type drone : %s  ⚡" % str(type_labels[0])
				type_impl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			else:
				type_impl.text = "  ↳ Type drone : %s  ⚠" % " / ".join(type_labels)
				type_impl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			type_impl.add_theme_font_size_override("font_size", 11)
			info_vbox.add_child(type_impl)

	var edit_btn := Button.new()
	edit_btn.text = "✏️"
	edit_btn.flat = true
	var idx := index
	edit_btn.pressed.connect(func(): _on_edit_constraint(idx))
	hbox.add_child(edit_btn)

	var del_btn := Button.new()
	del_btn.text = "🗑"
	del_btn.flat = true
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
		effects = raw
	return effects


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_close()
		get_viewport().set_input_as_handled()
