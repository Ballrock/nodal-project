class_name Figure
extends PanelContainer

## Boîte nodale drag & droppable avec titre dynamique et slots dynamiques.

signal drag_started(figure: Figure)
signal drag_ended(figure: Figure)
signal selected(figure: Figure)
signal slot_link_drag_started(slot: Slot, figure: Figure)
signal slots_changed(figure: Figure)
## Émis quand l'utilisateur demande la suppression d'un lien sur un slot via menu contextuel.
signal slot_remove_link_requested(slot: Slot, figure: Figure)
## Émis quand l'utilisateur demande la suppression d'un emplacement via menu contextuel.
signal slot_delete_requested(slot: Slot, figure: Figure)
## Émis quand le menu contextuel d'un slot est demandé.
signal slot_context_menu_requested(slot: Slot, figure: Figure, global_pos: Vector2)
## Émis quand le titre de la figure est modifié par l'utilisateur.
signal title_changed(figure: Figure)

const SLOT_SCENE := preload("res://features/workspace/components/slot.tscn")

@onready var title_label: Label = %TitleLabel
@onready var header: PanelContainer = %Header
@onready var _slots_container: VBoxContainer = %SlotsContainer

var data: FigureData

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_selected: bool = false
var _editing_title: bool = false
var _title_edit: LineEdit = null

## Si true, la boîte est la FleetFigure spéciale (pas de boutons +/−, non supprimable).
var is_fleet_figure: bool = false

# ── Couleurs ──────────────────────────────────────────────
const COLOR_SELECTED := Color("f5c542")
const COLOR_BORDER_DEFAULT := Color("555555")
const BORDER_WIDTH_DEFAULT := 1
const BORDER_WIDTH_SELECTED := 3


func _ready() -> void:
	# La boîte intercepte les events — ses enfants les laissent remonter (PASS)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_filter(self)
	_apply_data()


## Parcourt récursivement tous les enfants et force MOUSE_FILTER_PASS
## pour que les clicks remontent jusqu'au Figure parent.
## Exception : les enfants d'un Slot sont gérés par le Slot lui-même.
func _set_children_mouse_filter(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child != self:
			# Les boutons et champs de saisie doivent rester cliquables
			if child is Button or child is LineEdit:
				continue
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		# Le Slot gère le filtre de son cercle dans _ready() — ne pas y toucher
		if child is Slot:
			continue
		_set_children_mouse_filter(child)


## Initialise la boîte avec un FigureData.
func setup(p_data: FigureData) -> void:
	data = p_data
	if is_node_ready():
		_apply_data()


func _apply_data() -> void:
	if data == null:
		return
	title_label.text = data.title
	position = data.position
	_apply_header_color(data.color)
	_build_slots()
	# Re-applique le filtre sur les slots ajoutés dynamiquement
	_set_children_mouse_filter(self)


## Construit les lignes de slots à partir des données de la boîte.
## Chaque ligne contient : [slot entrée] [spacer] [slot sortie].
func _build_slots() -> void:
	# Vide le contenu existant — remove_child immédiat pour éviter
	# que les anciens nœuds restent visibles dans get_all_slots().
	for child in _slots_container.get_children():
		_slots_container.remove_child(child)
		child.queue_free()

	var in_count := data.input_slots.size()
	var out_count := data.output_slots.size()
	var row_count: int = max(in_count, out_count)

	if row_count == 0 and is_fleet_figure:
		# FleetFigure sans flottes : label discret
		var empty_label := Label.new()
		empty_label.text = "(aucune flotte)"
		empty_label.modulate = Color(1, 1, 1, 0.4)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slots_container.add_child(empty_label)
	elif row_count == 0:
		# Boîte classique sans slots : label discret
		var empty_label := Label.new()
		empty_label.text = "(aucun slot)"
		empty_label.modulate = Color(1, 1, 1, 0.4)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slots_container.add_child(empty_label)

	if row_count > 0:
		for i in row_count:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 0)

			# Slot d'entrée (gauche)
			if i < in_count:
				var slot_input: Slot = SLOT_SCENE.instantiate()
				row.add_child(slot_input)
				slot_input.setup(data.input_slots[i])
				slot_input.owner_figure = self
				slot_input.link_drag_started.connect(_on_slot_link_drag_started)
				slot_input.context_menu_requested.connect(_on_slot_context_menu)
			else:
				# Placeholder vide pour maintenir l'alignement
				var placeholder := Control.new()
				placeholder.custom_minimum_size = Vector2(80, 20)
				row.add_child(placeholder)

			# Spacer central
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spacer)

			# Slot de sortie (droite)
			if i < out_count:
				var slot_output: Slot = SLOT_SCENE.instantiate()
				row.add_child(slot_output)
				slot_output.setup(data.output_slots[i])
				slot_output.owner_figure = self
				slot_output.link_drag_started.connect(_on_slot_link_drag_started)
				slot_output.context_menu_requested.connect(_on_slot_context_menu)
			else:
				# Placeholder vide pour maintenir l'alignement
				var placeholder := Control.new()
				placeholder.custom_minimum_size = Vector2(80, 20)
				row.add_child(placeholder)

			_slots_container.add_child(row)

	# ── Bouton + pour ajouter un emplacement (boîtes classiques uniquement) ──
	if not is_fleet_figure:
		var add_btn := Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(28, 24)
		add_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_btn.pressed.connect(_on_add_slot_pair)
		_slots_container.add_child(add_btn)


func _on_slot_link_drag_started(slot: Slot) -> void:
	slot_link_drag_started.emit(slot, self)


## Renumérorte les index et relabellise les slots séquentiellement.
func relabel_slots() -> void:
	for i in data.input_slots.size():
		data.input_slots[i].index = i
		data.input_slots[i].label = "input_%d" % i
	for i in data.output_slots.size():
		data.output_slots[i].index = i
		data.output_slots[i].label = "output_%d" % i


# ── Ajout d'emplacements (+) ─────────────────────────────

## Ajoute une paire entrée + sortie à la boîte.
func _on_add_slot_pair() -> void:
	if is_fleet_figure:
		return
	var idx := data.input_slots.size()
	data.input_slots.append(
		SlotData.create("input_%d" % idx, SlotData.Direction.SLOT_INPUT, idx)
	)
	data.output_slots.append(
		SlotData.create("output_%d" % idx, SlotData.Direction.SLOT_OUTPUT, idx)
	)
	relabel_slots()
	_build_slots()
	_set_children_mouse_filter(self)
	slots_changed.emit(self)


# ── Menu contextuel sur un slot (clic droit) ─────────────

func _on_slot_context_menu(slot: Slot, at_position: Vector2) -> void:
	if is_fleet_figure:
		return
	slot_context_menu_requested.emit(slot, self, at_position)


## Retourne tous les Slot instanciés dans cette boîte.
func get_all_slots() -> Array[Slot]:
	var result: Array[Slot] = []
	for row in _slots_container.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Slot:
					result.append(child)
	return result


## Trouve un slot par son SlotData.id.
func find_slot_by_id(slot_id: StringName) -> Slot:
	for slot in get_all_slots():
		if slot.data and slot.data.id == slot_id:
			return slot
	return null


func set_title(new_title: String) -> void:
	if data:
		data.title = new_title
	if title_label:
		title_label.text = new_title


func _apply_header_color(color: Color) -> void:
	var style := header.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = color
	header.add_theme_stylebox_override("panel", style)


# ── Sélection ─────────────────────────────────────────────

func set_selected(value: bool) -> void:
	_is_selected = value
	_update_selection_style()


func _update_selection_style() -> void:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if _is_selected:
		style.border_color = COLOR_SELECTED
		style.border_width_left = BORDER_WIDTH_SELECTED
		style.border_width_right = BORDER_WIDTH_SELECTED
		style.border_width_top = BORDER_WIDTH_SELECTED
		style.border_width_bottom = BORDER_WIDTH_SELECTED
	else:
		style.border_color = COLOR_BORDER_DEFAULT
		style.border_width_left = BORDER_WIDTH_DEFAULT
		style.border_width_right = BORDER_WIDTH_DEFAULT
		style.border_width_top = BORDER_WIDTH_DEFAULT
		style.border_width_bottom = BORDER_WIDTH_DEFAULT
	add_theme_stylebox_override("panel", style)


# ── Drag & Drop ───────────────────────────────────────────
# _gui_input  → démarre le drag (souris sur le nœud)
# _input      → arrête le drag (relâchement global, même hors bounds)
# _process    → déplace le nœud via get_global_mouse_position() pour ne pas
#               perdre les events quand la souris sort des bounds du Control.

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if mb.double_click:
				# Double-clic sur le header → éditer le titre
				var local_pos := header.get_local_mouse_position()
				if header.get_rect().size != Vector2.ZERO and local_pos.y >= 0 and local_pos.y <= header.size.y:
					_start_title_edit()
					accept_event()
					return
			# Ne pas démarrer un drag si on est en édition de titre
			if _editing_title:
				return
			_dragging = true
			# Offset entre la position globale du nœud et la souris au moment du clic
			_drag_offset = get_global_mouse_position() - global_position
			# Passe au-dessus des autres boîtes pendant le drag
			move_to_front()
			set_selected(true)
			selected.emit(self)
			drag_started.emit(self)
			accept_event()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton

	# Capture le relâchement même si la souris a quitté les bounds du nœud
	if _dragging and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_dragging = false
		_sync_position_to_data()
		drag_ended.emit(self)

	# Si on est en édition de titre et qu'un clic survient en dehors du LineEdit → valider
	if _editing_title and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if _title_edit and is_instance_valid(_title_edit):
			var edit_rect := Rect2(_title_edit.global_position, _title_edit.size)
			if not edit_rect.has_point(mb.global_position):
				_commit_title_edit()


func _process(_delta: float) -> void:
	if _dragging:
		global_position = get_global_mouse_position() - _drag_offset


# ── Édition du titre (double-clic) ───────────────────────

## Démarre l'édition du titre : remplace le Label par un LineEdit.
func _start_title_edit() -> void:
	if _editing_title:
		return
	_editing_title = true
	# Annule un éventuel drag en cours (déclenché par le 1er clic du double-clic)
	if _dragging:
		_dragging = false
		drag_ended.emit(self)

	title_label.visible = false

	_title_edit = LineEdit.new()
	_title_edit.text = data.title
	_title_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_edit.select_all_on_focus = true
	# Style transparent pour s'intégrer dans le header
	_title_edit.add_theme_color_override("font_color", title_label.get_theme_color("font_color"))
	var flat_style := StyleBoxFlat.new()
	flat_style.bg_color = Color(0, 0, 0, 0.2)
	flat_style.set_content_margin_all(2)
	_title_edit.add_theme_stylebox_override("normal", flat_style)
	_title_edit.add_theme_stylebox_override("focus", flat_style)

	header.add_child(_title_edit)
	_title_edit.grab_focus()
	_title_edit.select_all()

	# Validation par Enter
	_title_edit.text_submitted.connect(_on_title_edit_submitted)
	# Annulation par Escape (géré dans _title_edit_input)
	_title_edit.gui_input.connect(_on_title_edit_input)


## Valide la modification du titre.
func _commit_title_edit() -> void:
	if not _editing_title:
		return
	var new_title := _title_edit.text.strip_edges()
	if new_title.is_empty():
		new_title = data.title  # Garde l'ancien titre si vide
	data.title = new_title
	title_label.text = new_title
	_end_title_edit()
	title_changed.emit(self)


## Annule la modification du titre.
func _cancel_title_edit() -> void:
	if not _editing_title:
		return
	_end_title_edit()


## Nettoie le LineEdit et restaure le Label.
func _end_title_edit() -> void:
	_editing_title = false
	if _title_edit and is_instance_valid(_title_edit):
		_title_edit.queue_free()
		_title_edit = null
	title_label.visible = true


func _on_title_edit_submitted(_text: String) -> void:
	_commit_title_edit()


func _on_title_edit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Empêche le clic dans le LineEdit de démarrer un drag
			accept_event()
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_cancel_title_edit()
			accept_event()


func _sync_position_to_data() -> void:
	if data:
		data.position = position
