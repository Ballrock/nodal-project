class_name FleetPanel
extends PanelContainer

## Volet latéral gauche collapsible : résumé Composition.
## Affiche un résumé des profils de drones et permet d'ouvrir
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
@onready var _riff_emo_bar: ProgressBar = %RiffEmoBar
@onready var _alloc_label: Label = %AllocLabel
@onready var _profile_list: VBoxContainer = %ProfileList

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
		_collapse_btn.text = "▶"
		_title_label.visible = false
		_edit_btn.visible = false
		_composition_summary.visible = false
		custom_minimum_size.x = COLLAPSED_WIDTH
	else:
		_collapse_btn.text = "◀"
		_title_label.visible = true
		_edit_btn.visible = true
		_composition_summary.visible = true
		custom_minimum_size.x = PANEL_WIDTH


## Rafraîchit le résumé Composition dans le panneau.
func refresh_composition_summary() -> void:
	var total: int = int(SettingsManager.get_setting("composition/total_drones"))
	var profiles_raw = SettingsManager.get_setting("composition/profiles")
	var profiles: Array[DroneProfile] = []
	if profiles_raw is Array:
		for d in profiles_raw:
			if d is Dictionary:
				profiles.append(DroneProfile.from_dict(d))

	_total_label.text = "Total : %d drones" % total

	var riff_count := 0
	var emo_count := 0
	var allocated := 0
	for p in profiles:
		allocated += p.quantity
		if p.drone_type == FleetData.DroneType.DRONE_RIFF:
			riff_count += p.quantity
		else:
			emo_count += p.quantity

	if total > 0:
		_riff_emo_bar.value = float(riff_count) / float(total) * 100.0
	else:
		_riff_emo_bar.value = 0.0

	_alloc_label.text = "Alloués : %d / %d" % [allocated, total]
	if allocated == total:
		_alloc_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	elif allocated < total:
		_alloc_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	else:
		_alloc_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

	# Rebuild profile list
	for child in _profile_list.get_children():
		child.queue_free()

	var nacelles_raw = SettingsManager.get_setting("composition/nacelles")
	var nacelle_map: Dictionary = {}
	if nacelles_raw is Array:
		for n in nacelles_raw:
			if n is Dictionary:
				nacelle_map[str(n.get("id", ""))] = str(n.get("name", ""))

	for p in profiles:
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		var top := Label.new()
		top.text = "%s  ×%d" % [p.name, p.quantity]
		top.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		line.add_child(top)

		var nacelle_name: String = nacelle_map.get(str(p.nacelle_id), "—")
		var effects_str := ""
		if p.effects.size() > 0:
			var names: Array[String] = []
			for e in p.effects:
				var v: String = str(e.get("variant", ""))
				if v != "":
					names.append(v)
			if names.size() > 0:
				effects_str = " · " + ", ".join(names)

		var sub := Label.new()
		sub.text = "  %s · %s%s" % [p.get_drone_type_label(), nacelle_name, effects_str]
		sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		sub.add_theme_font_size_override("font_size", 11)
		line.add_child(sub)
		_profile_list.add_child(line)

	if profiles.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucun profil défini"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_profile_list.add_child(empty_label)
