class_name Slot
extends HBoxContainer

## Emplacement de liaison (entrée ou sortie) d'une boîte nodale.
## Affiche un cercle coloré et un label, orientés selon la direction du slot.

## Émis quand l'utilisateur commence à tirer un câble depuis ce slot.
signal link_drag_started(slot: Slot)
## Émis quand l'utilisateur fait un clic droit sur le cercle du slot.
signal context_menu_requested(slot: Slot, at_position: Vector2)

const CIRCLE_SIZE := 14.0
const SNAP_RADIUS := 30.0
const COLOR_UNCONNECTED := Color("888888")
const COLOR_CONNECTED := Color("f5c542")
const COLOR_HOVER := Color("ffffff")

var data: SlotData
var _is_connected: bool = false
var _is_hovered: bool = false

## Référence vers la boîte parente (renseignée par Box._build_slots).
var owner_box: Box = null

@onready var _circle: PanelContainer = %SlotCircle
@onready var _label: Label = %SlotLabel


func setup(p_data: SlotData) -> void:
	data = p_data
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	# Le cercle doit capturer les clics pour initier/recevoir les câbles
	_circle.mouse_filter = Control.MOUSE_FILTER_STOP
	_circle.gui_input.connect(_on_circle_gui_input)
	_circle.mouse_entered.connect(_on_circle_mouse_entered)
	_circle.mouse_exited.connect(_on_circle_mouse_exited)
	if data:
		_apply_data()


func _apply_data() -> void:
	if data == null:
		return

	_label.text = data.label

	if data.direction == SlotData.Direction.SLOT_OUTPUT:
		# OUTPUT : label à gauche, cercle à droite
		move_child(_circle, get_child_count() - 1)
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		# INPUT : cercle à gauche, label à droite (ordre par défaut de la scène)
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_update_circle_color()


# ── Interactions cercle ───────────────────────────────────

func _on_circle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			link_drag_started.emit(self)
			_circle.accept_event()  # Empêche la box de démarrer un drag
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			context_menu_requested.emit(self, mb.global_position)
			_circle.accept_event()


func _on_circle_mouse_entered() -> void:
	_is_hovered = true
	_update_circle_color()


func _on_circle_mouse_exited() -> void:
	_is_hovered = false
	_update_circle_color()


## Met à jour l'apparence du cercle selon l'état de connexion.
func set_connected(value: bool) -> void:
	_is_connected = value
	if is_node_ready():
		_update_circle_color()


func set_highlight(value: bool) -> void:
	_is_hovered = value
	if is_node_ready():
		_update_circle_color()


func _update_circle_color() -> void:
	var color: Color
	if _is_hovered:
		color = COLOR_HOVER
	elif _is_connected:
		color = COLOR_CONNECTED
	else:
		color = COLOR_UNCONNECTED
	var style := StyleBoxFlat.new()
	style.bg_color = color
	var radius := int(CIRCLE_SIZE / 2)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	_circle.add_theme_stylebox_override("panel", style)


## Retourne le centre global du cercle (point d'attache pour les câbles).
func get_circle_global_center() -> Vector2:
	return _circle.global_position + _circle.size / 2.0
