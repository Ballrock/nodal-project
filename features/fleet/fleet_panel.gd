class_name FleetPanel
extends PanelContainer

## Volet latéral gauche collapsible : résumé Composition.
## Affiche un résumé des contraintes de drones et permet d'ouvrir
## la fenêtre d'édition de la composition.

signal composition_edit_requested

const PANEL_WIDTH := 250.0
const COLLAPSED_WIDTH := 36.0

@onready var _header: HBoxContainer = %FleetPanelHeader
@onready var _collapse_btn: Button = %CollapseBtn
@onready var _title_label: Label = %FleetPanelTitle
@onready var _edit_btn: Button = %EditBtn
@onready var _content: VBoxContainer = %FleetContent
@onready var _composition_summary: VBoxContainer = %CompositionSummary
@onready var _total_label: Label = %TotalLabel
@onready var _riff_emo_bar: CompositionBar = %RiffEmoBar
@onready var _alloc_label: Label = %AllocLabel
@onready var _constraint_list: VBoxContainer = %ConstraintList

var _collapsed: bool = false


func _ready() -> void:
	_collapse_btn.pressed.connect(_toggle_collapse)
	_edit_btn.pressed.connect(func() -> void: composition_edit_requested.emit())
	custom_minimum_size.x = PANEL_WIDTH
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_update_collapse_visual()
	refresh_composition_summary()


func _toggle_collapse() -> void:
	_collapsed = not _collapsed
	_update_collapse_visual()


func _update_collapse_visual() -> void:
	if _collapsed:
		_collapse_btn.text = "chevron_right"
		_title_label.visible = false
		_edit_btn.visible = false
		_composition_summary.visible = false
		custom_minimum_size.x = COLLAPSED_WIDTH
	else:
		_collapse_btn.text = "chevron_left"
		_title_label.visible = true
		_edit_btn.visible = true
		_composition_summary.visible = true
		custom_minimum_size.x = PANEL_WIDTH


## Rafraîchit le résumé Composition dans le panneau.
func refresh_composition_summary() -> void:
	var total: int = int(SettingsManager.get_setting("composition/total_drones"))
	var constraints_raw = SettingsManager.get_setting("composition/constraints")
	var constraints: Array[DroneConstraint] = []
	if constraints_raw is Array:
		for d in constraints_raw:
			if d is Dictionary:
				constraints.append(DroneConstraint.from_dict(d))

	_total_label.text = "Total : %d drones" % total

	var nacelles_catalog := _get_nacelles_catalog()
	var effects_catalog := _get_effects_catalog()

	var riff_count := 0
	var emo_count := 0
	var unresolved := 0
	var allocated := 0
	for p in constraints:
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
			unresolved += p.quantity

	_riff_emo_bar.update_bar(riff_count, emo_count, unresolved, total)

	_alloc_label.text = "Alloués : %d / %d" % [allocated, total]
	if allocated == total:
		_alloc_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	elif allocated < total:
		_alloc_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	else:
		_alloc_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

	# Rebuild compiled summary
	for child in _constraint_list.get_children():
		child.queue_free()

	# Show compiled drone counts
	if riff_count > 0:
		var riff_label := Label.new()
		riff_label.text = "RIFF : %d drones" % riff_count
		riff_label.add_theme_color_override("font_color", CompositionBar.COLOR_RIFF)
		riff_label.add_theme_font_size_override("font_size", 12)
		_constraint_list.add_child(riff_label)

	if emo_count > 0:
		var emo_label := Label.new()
		emo_label.text = "EMO : %d drones" % emo_count
		emo_label.add_theme_color_override("font_color", CompositionBar.COLOR_EMO)
		emo_label.add_theme_font_size_override("font_size", 12)
		_constraint_list.add_child(emo_label)

	if unresolved > 0:
		var unresolved_label := Label.new()
		unresolved_label.text = "Non résolu : %d drones" % unresolved
		unresolved_label.add_theme_color_override("font_color", CompositionBar.COLOR_UNRESOLVED)
		unresolved_label.add_theme_font_size_override("font_size", 12)
		_constraint_list.add_child(unresolved_label)

	var non_allocated := total - allocated
	if non_allocated > 0:
		var na_label := Label.new()
		na_label.text = "Non alloués : %d drones" % non_allocated
		na_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		na_label.add_theme_font_size_override("font_size", 12)
		_constraint_list.add_child(na_label)

	if allocated > total and total > 0:
		var overflow_label := Label.new()
		overflow_label.text = "Surplus : %d drones" % (allocated - total)
		overflow_label.add_theme_color_override("font_color", CompositionBar.COLOR_OVERFLOW)
		overflow_label.add_theme_font_size_override("font_size", 12)
		_constraint_list.add_child(overflow_label)

	if constraints.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucune contrainte définie"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_constraint_list.add_child(empty_label)


func _get_nacelles_catalog() -> Array:
	var raw = SettingsManager.get_setting("composition/nacelles")
	if raw is Array:
		return raw
	return []


func _get_effects_catalog() -> Array:
	var raw = SettingsManager.get_setting("composition/effects")
	if raw is Array:
		return raw
	return []
