class_name FleetPanel
extends PanelContainer

## Volet latéral gauche collapsible affichant la liste des flottes.
## Émet des signaux pour demander la création/édition via le FleetDialog.

signal add_fleet_requested
signal edit_fleet_requested(fleet: FleetData)

const PANEL_WIDTH := 250.0
const COLLAPSED_WIDTH := 36.0

@onready var _header: HBoxContainer = %FleetPanelHeader
@onready var _collapse_btn: Button = %CollapseBtn
@onready var _add_btn: Button = %AddBtn
@onready var _title_label: Label = %FleetPanelTitle
@onready var _fleet_list: VBoxContainer = %FleetList
@onready var _scroll: ScrollContainer = %FleetScroll
@onready var _content: VBoxContainer = %FleetContent

var _collapsed: bool = false
var _fleets: Array[FleetData] = []


func _ready() -> void:
	_collapse_btn.pressed.connect(_toggle_collapse)
	_add_btn.pressed.connect(func() -> void: add_fleet_requested.emit())
	custom_minimum_size.x = PANEL_WIDTH
	_update_collapse_visual()


## Ajoute une flotte à la liste et rafraîchit l'affichage.
func add_fleet(fleet: FleetData) -> void:
	_fleets.append(fleet)
	_rebuild_list()


## Met à jour l'affichage après modification d'une flotte.
func update_fleet(_fleet: FleetData) -> void:
	_rebuild_list()


## Supprime une flotte de la liste.
func remove_fleet(fleet: FleetData) -> void:
	_fleets.erase(fleet)
	_rebuild_list()


## Retourne la liste des flottes.
func get_fleets() -> Array[FleetData]:
	return _fleets


func _toggle_collapse() -> void:
	_collapsed = not _collapsed
	_update_collapse_visual()


func _update_collapse_visual() -> void:
	if _collapsed:
		_collapse_btn.text = "▶"
		_title_label.visible = false
		_add_btn.visible = false
		_scroll.visible = false
		custom_minimum_size.x = COLLAPSED_WIDTH
		size.x = COLLAPSED_WIDTH
	else:
		_collapse_btn.text = "◀"
		_title_label.visible = true
		_add_btn.visible = true
		_scroll.visible = true
		custom_minimum_size.x = PANEL_WIDTH
		size.x = PANEL_WIDTH


## Reconstruit la liste visuelle des flottes.
func _rebuild_list() -> void:
	for child in _fleet_list.get_children():
		child.queue_free()

	for fleet in _fleets:
		var btn := Button.new()
		btn.text = fleet.name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Style flat pour garder la cohérence visuelle
		btn.flat = true
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		# Capture de la flotte dans la closure
		var fleet_ref: FleetData = fleet
		btn.pressed.connect(func() -> void: edit_fleet_requested.emit(fleet_ref))
		_fleet_list.add_child(btn)
