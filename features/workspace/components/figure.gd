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
## Émis quand l'utilisateur demande la configuration de la figure.
signal config_requested(figure: Figure)
## Émis quand le titre de la figure est modifié par l'utilisateur.
signal title_changed(figure: Figure)
## Émis quand la couleur de la figure est modifiée.
signal color_changed(figure: Figure)

const SLOT_SCENE := preload("res://features/workspace/components/slot.tscn")
const MODAL_WINDOW_SCENE := preload("res://ui/components/modal_window.tscn")

@onready var title_label: Label = %TitleLabel
@onready var header: PanelContainer = %Header
@onready var _slots_container: VBoxContainer = %SlotsContainer
@onready var details_btn: Button = %DetailsBtn

var data: FigureData

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_selected: bool = false

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
	
	details_btn.pressed.connect(_on_details_btn_pressed)


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
	
	# Contraste pour le texte et les boutons du header
	var text_color := Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE
	title_label.add_theme_color_override("font_color", text_color)
	details_btn.add_theme_color_override("font_color", text_color)
	details_btn.add_theme_color_override("font_hover_color", text_color)
	details_btn.add_theme_color_override("font_pressed_color", text_color)
	details_btn.add_theme_color_override("font_focus_color", text_color)


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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					config_requested.emit(self)
					accept_event()
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


func _process(_delta: float) -> void:
	if _dragging:
		global_position = get_global_mouse_position() - _drag_offset


func _sync_position_to_data() -> void:
	if data:
		data.position = position


# ── Menu de détails ───────────────────────────────────────

func _on_details_btn_pressed() -> void:
	var popup := PopupMenu.new()
	popup.add_item("Configurer", 0)
	popup.add_separator()
	popup.add_item("Renommer la figure", 1)
	popup.add_item("Changer la couleur", 2)
	
	popup.id_pressed.connect(_on_details_menu_id_pressed)
	add_child(popup)
	
	# Positionne le menu sous le bouton
	var btn_rect: Rect2 = details_btn.get_global_rect()
	popup.position = Vector2i(btn_rect.position.x, btn_rect.end.y)
	popup.popup()


func _on_details_menu_id_pressed(id: int) -> void:
	match id:
		0: config_requested.emit(self)
		1: _show_rename_dialog()
		2: _show_color_dialog()


func _show_rename_dialog() -> void:
	var modal = MODAL_WINDOW_SCENE.instantiate()
	get_tree().root.add_child(modal)
	modal.setup("Renommer la figure")
	
	var edit := LineEdit.new()
	edit.text = data.title
	edit.placeholder_text = "Nouveau nom..."
	edit.select_all_on_focus = true
	modal.add_content(edit)
	
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	
	var cancel_btn := Button.new()
	cancel_btn.text = "Annuler"
	cancel_btn.pressed.connect(modal.close)
	btn_row.add_child(cancel_btn)
	
	var ok_btn := Button.new()
	ok_btn.text = "Valider"
	ok_btn.pressed.connect(func():
		var new_title := edit.text.strip_edges()
		if not new_title.is_empty():
			set_title(new_title)
			title_changed.emit(self)
		modal.close()
	)
	btn_row.add_child(ok_btn)
	
	modal.add_content(btn_row)
	edit.grab_focus()
	edit.text_submitted.connect(func(_t): ok_btn.pressed.emit())


func _show_color_dialog() -> void:
	var modal = MODAL_WINDOW_SCENE.instantiate()
	get_tree().root.add_child(modal)
	modal.setup("Changer la couleur")
	
	var picker := ColorPicker.new()
	picker.color = data.color
	picker.edit_alpha = false
	picker.sampler_visible = false
	picker.color_modes_visible = false
	picker.sliders_visible = false
	picker.presets_visible = true
	modal.add_content(picker)
	
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	
	var cancel_btn := Button.new()
	cancel_btn.text = "Annuler"
	cancel_btn.pressed.connect(modal.close)
	btn_row.add_child(cancel_btn)
	
	var ok_btn := Button.new()
	ok_btn.text = "Valider"
	ok_btn.pressed.connect(func():
		data.color = picker.color
		_apply_header_color(data.color)
		color_changed.emit(self)
		modal.close()
	)
	btn_row.add_child(ok_btn)
	
	modal.add_content(btn_row)
