# res://ui/components/config_window.gd
extends Window

## Fenêtre flottante de configuration pour une Figure.
## Permet de modifier le titre, la couleur et les slots en temps réel.

signal closed(figure_id: StringName)

var figure: Figure
var figure_data: FigureData

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _color_picker: ColorPickerButton = %ColorPicker
@onready var _input_slots_container: VBoxContainer = %InputSlotsContainer
@onready var _output_slots_container: VBoxContainer = %OutputSlotsContainer
@onready var _add_slot_btn: Button = %AddSlotBtn

func _ready() -> void:
	close_requested.connect(_on_close_requested)

	visible = false
	WindowHelper.setup_window(self)
	
	if _title_edit:
		_title_edit.text_changed.connect(_on_title_changed)
	if _color_picker:
		_color_picker.color_changed.connect(_on_color_changed)
	if _add_slot_btn:
		_add_slot_btn.pressed.connect(_on_add_slot_pressed)


func setup(p_figure: Figure) -> void:
	figure = p_figure
	figure_data = figure.data
	title = "Configuration : " + figure_data.title
	
	# Attendre que les nodes soient prêts
	if not is_inside_tree():
		await ready
		
	_title_edit.text = figure_data.title
	_color_picker.color = figure_data.color
	
	_refresh_slots()
	
	# Afficher la fenêtre après configuration complète (elle démarre cachée pour force_native)
	show()


func _on_close_requested() -> void:
	closed.emit(figure_data.id)
	queue_free()


func _on_title_changed(new_text: String) -> void:
	figure.set_title(new_text)
	title = "Configuration : " + new_text
	figure.title_changed.emit(figure)


func _on_color_changed(new_color: Color) -> void:
	figure_data.color = new_color
	figure._apply_header_color(new_color)
	figure.color_changed.emit(figure)


func _on_add_slot_pressed() -> void:
	figure._on_add_slot_pair()
	_refresh_slots()


func _refresh_slots() -> void:
	_clear_container(_input_slots_container)
	_clear_container(_output_slots_container)
	
	for i in figure_data.input_slots.size():
		_add_slot_editor(_input_slots_container, figure_data.input_slots[i], i)
		
	for i in figure_data.output_slots.size():
		_add_slot_editor(_output_slots_container, figure_data.output_slots[i], i)


func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_slot_editor(container: Control, slot_data: SlotData, index: int) -> void:
	var h_box := HBoxContainer.new()
	container.add_child(h_box)
	
	var edit := LineEdit.new()
	edit.text = slot_data.label
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(new_text: String):
		slot_data.label = new_text
		figure._build_slots()
		figure.slots_changed.emit(figure)
	)
	h_box.add_child(edit)
	
	var delete_btn := Button.new()
	delete_btn.text = "✕"
	delete_btn.modulate = Color(1, 0.4, 0.4)
	delete_btn.pressed.connect(func():
		_delete_slot_pair(index)
	)
	h_box.add_child(delete_btn)


func _delete_slot_pair(index: int) -> void:
	# On utilise la même logique que dans main.gd mais adaptée
	# Idéalement cette logique devrait être dans Figure ou FigureData
	
	# Pour l'instant on demande à Figure de gérer ou on le fait ici
	# Le problème est que Figure._on_slot_delete attend un nœud Slot.
	# On va simplifier pour le POC :
	
	if index < figure_data.input_slots.size():
		figure_data.input_slots.remove_at(index)
	if index < figure_data.output_slots.size():
		figure_data.output_slots.remove_at(index)
	
	figure.relabel_slots()
	figure._build_slots()
	figure.slots_changed.emit(figure)
	_refresh_slots()
