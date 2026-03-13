class_name ConstraintDialog
extends Window

## Dialogue modal pour créer ou modifier une contrainte de drones.
## Interface filtre générique : Catégorie → Valeur, avec implications affichées.

signal constraint_created(constraint: DroneConstraint)
signal constraint_updated(constraint: DroneConstraint)
signal constraint_deleted(constraint: DroneConstraint)

@onready var _name_edit: LineEdit = %ConstraintNameEdit
@onready var _quantity_spin: SpinBox = %QuantitySpin
@onready var _category_option: OptionButton = %CategoryOption
@onready var _value_option: OptionButton = %ValueOption
@onready var _implications_container: VBoxContainer = %ImplicationsContainer
@onready var _validate_btn: Button = %ConstraintValidateBtn
@onready var _cancel_btn: Button = %ConstraintCancelBtn
@onready var _delete_btn: Button = %ConstraintDeleteBtn
@onready var _pyro_container: VBoxContainer = %PyroEffectContainer
@onready var _effect_search: LineEdit = %EffectSearchEdit
@onready var _effect_tree: Tree = %EffectTree

var _editing_constraint: DroneConstraint = null
var _selected_effect_meta: String = ""
var _nacelles: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _payloads: Array[Dictionary] = []
var _pyro_effects_real: Array[Dictionary] = []
var _auto_name: bool = true  # Track if name was auto-generated


func _ready() -> void:
	visible = false
	force_native = true
	content_scale_factor = DisplayServer.screen_get_scale()
	transient = true
	exclusive = true

	_validate_btn.pressed.connect(_on_validate)
	_cancel_btn.pressed.connect(_close)
	_delete_btn.pressed.connect(_on_delete)
	_category_option.item_selected.connect(_on_category_changed)
	_value_option.item_selected.connect(_on_value_changed)
	_name_edit.text_changed.connect(_on_name_edited)
	_effect_search.text_changed.connect(_on_effect_search_changed)
	_effect_tree.item_selected.connect(_on_effect_tree_selected)

	_category_option.clear()
	_category_option.add_item("Type drone", DroneConstraint.ConstraintCategory.DRONE_TYPE)
	_category_option.add_item("Nacelle", DroneConstraint.ConstraintCategory.NACELLE)
	_category_option.add_item("Payload", DroneConstraint.ConstraintCategory.PAYLOAD)
	_category_option.add_item("Effet Pyro", DroneConstraint.ConstraintCategory.PYRO_EFFECT)

	_quantity_spin.min_value = 1
	_quantity_spin.max_value = 99999
	_quantity_spin.step = 1

	_load_catalogs()


func open_create() -> void:
	_editing_constraint = null
	title = "Nouvelle contrainte"
	_name_edit.text = ""
	_name_edit.placeholder_text = "Nom de la contrainte"
	_auto_name = true
	_category_option.select(-1)
	_quantity_spin.value = 1
	_delete_btn.visible = false
	_value_option.clear()
	_value_option.add_item("-- Choisir une catégorie d'abord --")
	_value_option.set_item_disabled(0, true)
	_value_option.disabled = true
	_set_pyro_mode(false)
	_effect_search.text = ""
	_effect_tree.clear()
	_selected_effect_meta = ""
	for child in _implications_container.get_children():
		child.queue_free()
	_update_validate_enabled()
	_show_dialog()


func open_edit(constraint: DroneConstraint) -> void:
	_editing_constraint = constraint
	title = "Modifier la contrainte : " + constraint.name
	_name_edit.text = constraint.name
	_auto_name = false
	_quantity_spin.value = constraint.quantity
	_delete_btn.visible = true

	# Select category
	for i in _category_option.item_count:
		if _category_option.get_item_id(i) == constraint.category:
			_category_option.select(i)
			break

	var is_pyro := constraint.category == DroneConstraint.ConstraintCategory.PYRO_EFFECT
	_set_pyro_mode(is_pyro)

	_refresh_values(constraint.category)

	if is_pyro:
		_selected_effect_meta = constraint.value
		_select_tree_item_by_metadata(constraint.value)
	else:
		_value_option.disabled = false
		# Select value
		for i in _value_option.item_count:
			if _value_option.get_item_metadata(i) == constraint.value:
				_value_option.select(i)
				break

	_update_implications()
	_show_dialog()


func _show_dialog() -> void:
	popup_centered()
	_name_edit.grab_focus()


func _close() -> void:
	hide()
	_editing_constraint = null
	_effect_search.text = ""


func _load_catalogs() -> void:
	_nacelles.clear()
	_effects.clear()
	_payloads.clear()
	_pyro_effects_real.clear()
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

	var payloads_raw = SettingsManager.get_setting("composition/payloads")
	if payloads_raw is Array:
		for pl in payloads_raw:
			if pl is Dictionary:
				_payloads.append(pl)

	var pyro_effects_raw = SettingsManager.get_setting("composition/pyro_effects")
	if pyro_effects_raw is Array:
		for pe in pyro_effects_raw:
			if pe is Dictionary:
				_pyro_effects_real.append(pe)


func _on_name_edited(_new_text: String) -> void:
	_auto_name = false
	_update_validate_enabled()


func _on_category_changed(_index: int) -> void:
	var cat: int = _category_option.get_selected_id()
	var is_pyro := cat == DroneConstraint.ConstraintCategory.PYRO_EFFECT
	_set_pyro_mode(is_pyro)
	if not is_pyro:
		_value_option.disabled = false
	_selected_effect_meta = ""
	_effect_search.text = ""
	_refresh_values(cat)


func _refresh_values(cat: int) -> void:
	_value_option.clear()

	# Placeholder item
	_value_option.add_item("-- Choisir --")
	_value_option.set_item_metadata(0, "")

	match cat:
		DroneConstraint.ConstraintCategory.DRONE_TYPE:
			var drone_idx := _value_option.item_count
			_value_option.add_item("RIFF")
			_value_option.set_item_metadata(drone_idx, "0")
			_value_option.add_item("EMO")
			_value_option.set_item_metadata(drone_idx + 1, "1")

		DroneConstraint.ConstraintCategory.NACELLE:
			for n in _nacelles:
				var idx := _value_option.item_count
				_value_option.add_item(str(n.get("name", "")))
				_value_option.set_item_metadata(idx, str(n.get("id", "")))

		DroneConstraint.ConstraintCategory.PAYLOAD:
			for pl in _payloads:
				var idx := _value_option.item_count
				_value_option.add_item(str(pl.get("name", "")))
				_value_option.set_item_metadata(idx, str(pl.get("id", "")))

		DroneConstraint.ConstraintCategory.PYRO_EFFECT:
			_populate_effect_tree("")
			_update_validate_enabled()
			return

	if _value_option.item_count > 0:
		_value_option.select(0)
	_on_value_changed(0)
	_update_validate_enabled()


func _on_value_changed(_index: int) -> void:
	_update_auto_name()
	_update_implications()
	_update_validate_enabled()


func _update_auto_name() -> void:
	if not _auto_name:
		return
	var cat: int = _category_option.get_selected_id()
	if cat == DroneConstraint.ConstraintCategory.PYRO_EFFECT:
		var selected_item := _effect_tree.get_selected()
		if selected_item and not _selected_effect_meta.is_empty():
			_name_edit.text = selected_item.get_text(0)
		return
	if _value_option.selected <= 0 or _value_option.item_count <= 1:
		return
	var display := _value_option.get_item_text(_value_option.selected)
	_name_edit.text = display


func _update_implications() -> void:
	for child in _implications_container.get_children():
		child.queue_free()

	if not _is_value_selected():
		return

	var cat: int = _category_option.get_selected_id()
	var val: String = _get_selected_value()

	var temp := DroneConstraint.new()
	temp.category = cat
	temp.value = val
	var merged_effects := _effects + _pyro_effects_real
	var implications := temp.resolve_implications(_nacelles, merged_effects)

	# Show nacelle implications (skip for DRONE_TYPE and NACELLE)
	if cat != DroneConstraint.ConstraintCategory.DRONE_TYPE and cat != DroneConstraint.ConstraintCategory.NACELLE:
		var nacelle_names: Array = implications.get("implied_nacelle_names", [])
		if nacelle_names.size() > 0:
			var nacelle_label := Label.new()
			var resolved: bool = implications.get("nacelle_resolved", false)
			if resolved:
				nacelle_label.text = "↳ Nacelle : %s  ⚡" % str(nacelle_names[0])
				nacelle_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			else:
				nacelle_label.text = "↳ Nacelle : %s  ⚠ %d options" % [" / ".join(nacelle_names), nacelle_names.size()]
				nacelle_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			nacelle_label.add_theme_font_size_override("font_size", 12)
			_implications_container.add_child(nacelle_label)

	# Show drone type implications (skip for DRONE_TYPE)
	if cat != DroneConstraint.ConstraintCategory.DRONE_TYPE:
		var type_labels: Array = implications.get("implied_drone_type_labels", [])
		if type_labels.size() > 0:
			var type_label := Label.new()
			var resolved: bool = implications.get("type_resolved", false)
			if resolved:
				type_label.text = "↳ Type drone : %s  ⚡" % str(type_labels[0])
				type_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			else:
				type_label.text = "↳ Type drone : %s  ⚠ %d options" % [" / ".join(type_labels), type_labels.size()]
				type_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			type_label.add_theme_font_size_override("font_size", 12)
			_implications_container.add_child(type_label)

	# Payload — no implications message
	if cat == DroneConstraint.ConstraintCategory.PAYLOAD:
		var info_label := Label.new()
		info_label.text = "Aucune implication déduite (extensible)"
		info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		info_label.add_theme_font_size_override("font_size", 12)
		_implications_container.add_child(info_label)


func _is_value_selected() -> bool:
	var cat: int = _category_option.get_selected_id()
	if cat == DroneConstraint.ConstraintCategory.PYRO_EFFECT:
		return not _selected_effect_meta.is_empty()
	# Index 0 is always the placeholder '-- Choisir --'
	return _value_option.selected > 0 and _value_option.item_count > 1


func _update_validate_enabled() -> void:
	var name_ok := not _name_edit.text.strip_edges().is_empty()
	var category_ok := _category_option.selected >= 0
	var value_ok := _is_value_selected()
	_validate_btn.disabled = not (name_ok and category_ok and value_ok)


func _on_validate() -> void:
	var constraint_name := _name_edit.text.strip_edges()
	if constraint_name.is_empty():
		_name_edit.grab_focus()
		return

	if not _is_value_selected():
		return

	var cat: int = _category_option.get_selected_id()
	var val: String = _get_selected_value()

	if _editing_constraint:
		_editing_constraint.name = constraint_name
		_editing_constraint.quantity = int(_quantity_spin.value)
		_editing_constraint.category = cat
		_editing_constraint.value = val
		constraint_updated.emit(_editing_constraint)
	else:
		var constraint := DroneConstraint.create(
			constraint_name,
			cat,
			val,
			int(_quantity_spin.value),
		)
		constraint_created.emit(constraint)

	_close()


func _on_delete() -> void:
	if _editing_constraint:
		constraint_deleted.emit(_editing_constraint)
		_close()


func _set_pyro_mode(enabled: bool) -> void:
	_pyro_container.visible = enabled
	_value_option.visible = not enabled


func _get_selected_value() -> String:
	var cat: int = _category_option.get_selected_id()
	if cat == DroneConstraint.ConstraintCategory.PYRO_EFFECT:
		return _selected_effect_meta
	return str(_value_option.get_item_metadata(_value_option.selected))


func _populate_effect_tree(filter: String) -> void:
	_effect_tree.clear()
	var root := _effect_tree.create_item()

	var pyro_catalog := _pyro_effects_real if not _pyro_effects_real.is_empty() else _effects

	# Group by type
	var grouped: Dictionary = {}
	for e in pyro_catalog:
		var etype: String = str(e.get("type", ""))
		if etype.is_empty():
			etype = "Sans catégorie"
		if not grouped.has(etype):
			grouped[etype] = []
		grouped[etype].append(e)

	# Sort types alphabetically
	var types: Array = grouped.keys()
	types.sort()

	var filter_lower := filter.to_lower()

	for t in types:
		var effects_in_type: Array = grouped[t]

		# Filter effects
		var filtered: Array = []
		for e in effects_in_type:
			var ename: String = str(e.get("name", ""))
			if filter_lower.is_empty() or ename.to_lower().find(filter_lower) >= 0:
				filtered.append(e)

		if filtered.is_empty():
			continue

		# Sort filtered effects by name
		filtered.sort_custom(func(a, b): return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower())

		# Create type parent item
		var type_item := _effect_tree.create_item(root)
		type_item.set_text(0, t)
		type_item.set_selectable(0, false)
		type_item.set_custom_color(0, Color(0.6, 0.6, 0.6))

		for e in filtered:
			var ename: String = str(e.get("name", ""))
			var eid: String = str(e.get("id", ""))
			var variants = e.get("variants", [])

			if variants is Array and variants.size() > 0:
				# Sub-parent for effect with variants
				var effect_parent := _effect_tree.create_item(type_item)
				effect_parent.set_text(0, ename)
				effect_parent.set_selectable(0, false)
				effect_parent.set_custom_color(0, Color(0.75, 0.75, 0.75))
				for v in variants:
					var variant_item := _effect_tree.create_item(effect_parent)
					variant_item.set_text(0, "%s — %s" % [ename, str(v)])
					variant_item.set_metadata(0, "%s::%s" % [eid, str(v)])
			else:
				var effect_item := _effect_tree.create_item(type_item)
				effect_item.set_text(0, ename)
				effect_item.set_metadata(0, eid)

	# Try to restore previous selection
	if not _selected_effect_meta.is_empty():
		_select_tree_item_by_metadata(_selected_effect_meta)


func _on_effect_search_changed(text: String) -> void:
	_populate_effect_tree(text)


func _on_effect_tree_selected() -> void:
	var selected := _effect_tree.get_selected()
	if selected:
		_selected_effect_meta = str(selected.get_metadata(0))
	else:
		_selected_effect_meta = ""
	_update_auto_name()
	_update_implications()
	_update_validate_enabled()


func _select_tree_item_by_metadata(meta: String) -> bool:
	var root := _effect_tree.get_root()
	if not root:
		return false
	return _select_tree_item_recursive(root, meta)


func _select_tree_item_recursive(item: TreeItem, meta: String) -> bool:
	if item.get_metadata(0) == meta and item.is_selectable(0):
		item.select(0)
		_effect_tree.ensure_cursor_is_visible()
		return true
	var child := item.get_first_child()
	while child:
		if _select_tree_item_recursive(child, meta):
			return true
		child = child.get_next()
	return false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
