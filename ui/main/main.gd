extends Control

## Script principal : orchestre le workspace, les flottes, la timeline
## et la sérialisation.

const FigureData := preload("res://core/data/figure_data.gd")
const FleetData := preload("res://core/data/fleet_data.gd")
const LinkData := preload("res://core/data/link_data.gd")
const GraphSerializer := preload("res://core/serialization/graph_serializer.gd")
const MenuManager := preload("res://core/utils/menu_manager.gd")
const CONFIG_WINDOW_SCENE := preload("res://ui/components/config_window.tscn")

## Couleur d'en-tête de la boîte Flotte (verte, cf. spec §14.3).
const FLEET_FIGURE_COLOR := Color(0.33, 0.75, 0.42)

@onready var workspace: Node = %Workspace
@onready var fleet_panel: Node = %FleetPanel
@onready var fleet_dialog: Node = %FleetDialog
@onready var settings_window: Node = %SettingsWindow
@onready var timeline_panel: Node = %TimelinePanel
@onready var _toolbar: MenuBar = %Toolbar

## Registre des boîtes par id pour résoudre les liens (pour la sérialisation/logique métier).
var _figures_by_id: Dictionary = {}

## Registre des fenêtres de configuration ouvertes (figure_id -> Window).
var _config_windows: Dictionary = {}

## La boîte Flotte spéciale (non supprimable, 0 entrées, N sorties = flottes).
var _fleet_figure: Node = null
## Correspondance stable fleet.id → SlotData.
var _fleet_to_slot: Dictionary = {}

## La figure actuellement sélectionnée.
var _selected_figure: Figure = null

## Garde pour éviter la récursion infinie lors de la synchronisation de sélection.
var _syncing_selection: bool = false

## Compteur pour nommer les figures séquentiellement.
var _figure_counter: int = 0

# ── Menu ──────────────────────────────────────────────────
@onready var _fichier_menu: PopupMenu = %Fichier
@onready var _scenographie_menu: PopupMenu = %"Scénographie"
@onready var _tolz_menu: PopupMenu = %"Tolz"
@onready var _element_menu: PopupMenu = %"Élément"
var _menu_manager: MenuManager

func _ready() -> void:
	# ── Workspace Signals ──
	workspace.figure_selected.connect(_on_figure_selected)
	workspace.link_created.connect(_on_link_created)
	workspace.link_replace_requested.connect(_on_link_replace_requested)

	# ── Menus ──
	_menu_manager = MenuManager.new()
	_menu_manager.setup(_fichier_menu, _scenographie_menu, _tolz_menu, _element_menu)
	_menu_manager.save_requested.connect(_on_save_requested)
	_menu_manager.load_requested.connect(_on_load_requested)
	_menu_manager.global_settings_requested.connect(settings_window.open_global)
	_menu_manager.quit_requested.connect(func(): get_tree().quit())
	_menu_manager.scenography_settings_requested.connect(settings_window.open_project)
	_menu_manager.add_figure_requested.connect(_add_figure)

	_style_toolbar()

	# ── Volet Flottes ──
	fleet_panel.add_fleet_requested.connect(_on_add_fleet_requested)
	fleet_panel.edit_fleet_requested.connect(_on_edit_fleet_requested)

	# ── Dialog Flotte ──
	fleet_dialog.fleet_created.connect(_on_fleet_created)
	fleet_dialog.fleet_updated.connect(_on_fleet_updated)
	fleet_dialog.fleet_deleted.connect(_on_fleet_deleted)

	# ── Timeline Panel ──
	timeline_panel.segment_selected.connect(_on_timeline_segment_selected)
	timeline_panel.segment_moved.connect(_on_timeline_segment_moved)
	timeline_panel.segment_resized.connect(_on_timeline_segment_resized)

	# ── Initialisation par défaut ──
	_setup_default_scene()

func _setup_default_scene() -> void:
	# Boîte Flotte spéciale
	var fleet_fig_data := FigureData.create("Flottes", Vector2(-400, -100), 0, 0)
	fleet_fig_data.color = FLEET_FIGURE_COLOR
	_fleet_figure = _spawn_figure_from_data(fleet_fig_data, true)

	# Boîtes de test initiales
	_spawn_figure("Démarrage", Vector2(-150, -150), 2, 2, 0.5, 2.5)
	_spawn_figure("Traitement", Vector2(150, -50), 3, 3, 3.0, 5.0)
	_spawn_figure("Fin", Vector2(450, -150), 2, 2, 6.0, 8.0)

	workspace.center_view()
	_sync_timeline()

func _style_toolbar() -> void:
	# (Logic preserved from original main.gd)
	var bg_color := Color(0.11, 0.11, 0.13, 1.0)
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.set_corner_radius_all(0)
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 4
	style_normal.content_margin_bottom = 4
	_toolbar.add_theme_stylebox_override("normal", style_normal)

func _add_figure() -> void:
	_figure_counter += 1
	var title := "Figure %d" % _figure_counter
	var canvas_area = workspace.canvas_area
	var canvas_content = workspace.canvas_content
	var canvas_center_screen: Vector2 = canvas_area.size / 2.0
	var canvas_center_local: Vector2 = (canvas_center_screen - canvas_content.position) / workspace.get_canvas_zoom()
	_spawn_figure(title, canvas_center_local, 0, 0)
	_sync_timeline()

func _spawn_figure(title: String, pos: Vector2, inputs: int = 1, outputs: int = 1, p_start_time: float = 0.0, p_end_time: float = 1.0, p_track: int = 0) -> Node:
	var figure_data := FigureData.create(title, pos, inputs, outputs, p_start_time, p_end_time, p_track)
	return _spawn_figure_from_data(figure_data)

func _spawn_figure_from_data(figure_data: FigureData, p_is_fleet_figure: bool = false) -> Node:
	var figure_node = workspace.spawn_figure_from_data(figure_data, p_is_fleet_figure)
	_figures_by_id[figure_data.id] = figure_node
	
	# Connect figure specific requests that main still needs to handle (like slot deletion)
	figure_node.slot_delete_requested.connect(_on_slot_delete)
	figure_node.slot_remove_link_requested.connect(_on_slot_remove_link)
	figure_node.slot_context_menu_requested.connect(_on_slot_context_menu_requested)
	figure_node.config_requested.connect(_on_config_requested)
	figure_node.title_changed.connect(func(_f): _sync_timeline())
	figure_node.color_changed.connect(func(_f): _sync_timeline())
	
	return figure_node

# ── Files I/O ──

func _on_save_requested() -> void:
	DisplayServer.file_dialog_show(
		"Sauvegarder le schéma",
		"",
		"schema.json",
		false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		PackedStringArray(["*.json ; Schéma JSON"]),
		func(status: bool, selected_paths: PackedStringArray, _filter_index: int):
			if status and selected_paths.size() > 0:
				_on_save_file_selected(selected_paths[0])
	)

func _on_load_requested() -> void:
	DisplayServer.file_dialog_show(
		"Ouvrir un schéma",
		"",
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.json ; Schéma JSON"]),
		func(status: bool, selected_paths: PackedStringArray, _filter_index: int):
			if status and selected_paths.size() > 0:
				_on_load_file_selected(selected_paths[0])
	)

func _on_save_file_selected(path: String) -> void:
	var data := GraphSerializer.serialize_graph(
		_figures_by_id,
		workspace.links_layer,
		fleet_panel,
		_fleet_to_slot,
		workspace.get_canvas_zoom(),
		timeline_panel.timeline_scale,
	)
	GraphSerializer.save_to_file(path, data)

func _on_load_file_selected(path: String) -> void:
	var data := GraphSerializer.load_from_file(path)
	if not data.is_empty(): _load_graph(data)

func _clear_graph() -> void:
	workspace.clear()
	_figures_by_id.clear()
	_fleet_figure = null
	_fleet_to_slot.clear()
	fleet_panel.clear_fleets()
	_figure_counter = 0
	_sync_timeline()

func _load_graph(data: Dictionary) -> void:
	_clear_graph()
	workspace.set_canvas_zoom(float(data.get("canvas_zoom", 1.0)))
	timeline_panel.timeline_scale = float(data.get("timeline_scale", 100.0))

	# Paramètres du projet
	if data.has("project_settings"):
		SettingsManager.load_project_settings_dict(data["project_settings"])

	var figures_data: Array = data.get("figures", [])
	for fig_dict: Dictionary in figures_data:
		var figure_data := GraphSerializer.dict_to_figure_data(fig_dict)
		var is_fleet := bool(fig_dict.get("is_fleet_figure", false))
		if is_fleet:
			_fleet_figure = _spawn_figure_from_data(figure_data, true)
		else:
			_spawn_figure_from_data(figure_data)
			_figure_counter += 1

	if _fleet_figure == null:
		var fleet_fig_data := FigureData.create("Flottes", Vector2(270, 150), 0, 0)
		fleet_fig_data.color = FLEET_FIGURE_COLOR
		_fleet_figure = _spawn_figure_from_data(fleet_fig_data, true)

	var fleets_data: Array = data.get("fleets", [])
	var loaded_fleets: Array[FleetData] = []
	for fleet_dict: Dictionary in fleets_data:
		loaded_fleets.append(GraphSerializer.dict_to_fleet_data(fleet_dict))
	fleet_panel.set_fleets(loaded_fleets)

	var saved_mapping: Dictionary = data.get("fleet_to_slot", {})
	for fleet_id_str: String in saved_mapping:
		var fleet_id := StringName(fleet_id_str)
		var slot_id := StringName(str(saved_mapping[fleet_id_str]))
		if _fleet_figure:
			for slot_data: SlotData in _fleet_figure.data.output_slots:
				if slot_data.id == slot_id:
					_fleet_to_slot[fleet_id] = slot_data
					break

	var links_data: Array = data.get("links", [])
	for link_dict: Dictionary in links_data:
		var link_data := GraphSerializer.dict_to_link_data(link_dict)
		workspace.links_layer.add_link_from_data(link_data)

	_sync_timeline()
	await get_tree().process_frame
	workspace.links_layer.refresh()

# ── Signals Handlers ──

func _on_config_requested(figure: Figure) -> void:
	var figure_id := figure.data.id
	
	if _config_windows.has(figure_id):
		var window = _config_windows[figure_id]
		if is_instance_valid(window):
			window.grab_focus()
			return
		else:
			_config_windows.erase(figure_id)
	
	var window = CONFIG_WINDOW_SCENE.instantiate()
	get_tree().root.add_child(window)
	window.setup(figure)
	_config_windows[figure_id] = window
	
	# Centrer par rapport à la fenêtre principale
	var root_pos = get_window().position
	var root_size = get_window().size
	window.position = root_pos + (root_size - window.size) / 2
	
	window.closed.connect(func(id: StringName):
		_config_windows.erase(id)
	)

func _on_figure_selected(figure: Node) -> void:
	if _syncing_selection: return
	_syncing_selection = true
	
	_selected_figure = figure as Figure
	
	for id in _figures_by_id:
		var node = _figures_by_id[id]
		if node != figure: node.set_selected(false)
	
	if figure:
		figure.set_selected(true)
		timeline_panel.select_segment_for_figure(figure.data)
	else:
		timeline_panel.deselect_all()
	
	_syncing_selection = false

func _on_link_created(source_slot: Node, target_slot: Node) -> void:
	var out_slot := source_slot
	var in_slot := target_slot
	if source_slot.data.direction == 0: # SlotData.Direction.SLOT_INPUT (assuming 0 from FigureData)
		out_slot = target_slot
		in_slot = source_slot

	var link_data := LinkData.create(
		out_slot.owner_figure.data.id,
		out_slot.data.id,
		in_slot.owner_figure.data.id,
		in_slot.data.id,
	)
	workspace.links_layer.add_link(out_slot, in_slot, link_data)

func _on_link_replace_requested(source_slot: Node, target_slot: Node, old_link: LinkData) -> void:
	workspace.links_layer.remove_link(old_link)
	_on_link_created(source_slot, target_slot)

func _on_slot_remove_link(slot: Node, _figure: Node) -> void:
	workspace.links_layer.remove_links_for_slot_id(slot.data.id)
	workspace.links_layer.refresh()

func _on_slot_context_menu_requested(slot: Node, figure: Figure, global_pos: Vector2) -> void:
	var links: Array[LinkData] = workspace.links_layer.find_links_for_slot(slot.data.id)
	if not links.is_empty():
		# Pour l'instant on prend le premier lien si plusieurs existent (cas sortie N:1)
		# Dans l'idéal on pourrait lister les liens, mais restons sur 1:1 pour le moment.
		workspace.links_layer.open_context_menu_for_link(links[0], global_pos)
	else:
		# Pas de lien : menu simple pour l'emplacement
		var popup := PopupMenu.new()
		popup.add_item("Supprimer l'emplacement", 0)
		popup.set_item_icon_modulate(0, Color(0.9, 0.25, 0.25))
		popup.id_pressed.connect(func(id):
			if id == 0: _on_slot_delete(slot, figure)
			popup.queue_free()
		)
		add_child(popup)
		popup.position = Vector2i(global_pos)
		popup.popup()

func _on_slot_delete(slot: Node, figure: Node) -> void:
	# Logic preserved from main.gd
	if figure.is_fleet_figure: return
	# ... (I should move this logic to Figure but for now I keep it here to avoid breaking things)
	# For brevity I'll keep the full logic if possible or move it.
	# Let's assume it stays here as it's "business logic" of how figures are modified.
	# (Actually it's very UI/Model coupled, but let's keep it functional)
	_handle_slot_deletion(slot, figure)

func _handle_slot_deletion(slot: Node, figure: Node) -> void:
	var direction: int = slot.data.direction
	var pos := -1
	if direction == 0: # INPUT
		for i in figure.data.input_slots.size():
			if figure.data.input_slots[i] == slot.data:
				pos = i
				break
	else: # OUTPUT
		for i in figure.data.output_slots.size():
			if figure.data.output_slots[i] == slot.data:
				pos = i
				break
	if pos < 0: return

	var sym_slot_data = null
	if direction == 0:
		if pos < figure.data.output_slots.size(): sym_slot_data = figure.data.output_slots[pos]
	else:
		if pos < figure.data.input_slots.size(): sym_slot_data = figure.data.input_slots[pos]

	workspace.links_layer.remove_links_for_slot_id(slot.data.id)
	if sym_slot_data: workspace.links_layer.remove_links_for_slot_id(sym_slot_data.id)

	if direction == 0:
		figure.data.input_slots.remove_at(pos)
		if pos < figure.data.output_slots.size(): figure.data.output_slots.remove_at(pos)
	else:
		figure.data.output_slots.remove_at(pos)
		if pos < figure.data.input_slots.size(): figure.data.input_slots.remove_at(pos)

	figure.relabel_slots()
	figure._build_slots()
	workspace.links_layer.refresh()

# ── Fleet Handlers ──
func _on_add_fleet_requested() -> void: fleet_dialog.open_create()
func _on_edit_fleet_requested(fleet: FleetData) -> void: fleet_dialog.open_edit(fleet)
func _on_fleet_created(fleet: FleetData) -> void:
	fleet_panel.add_fleet(fleet)
	_fleet_figure_add_slot(fleet)

func _on_fleet_updated(fleet: FleetData) -> void:
	fleet_panel.update_fleet(fleet)
	_fleet_figure_rename_slot(fleet)

func _on_fleet_deleted(fleet: FleetData) -> void:
	fleet_panel.remove_fleet(fleet)
	_fleet_figure_remove_slot(fleet)

func _fleet_figure_add_slot(fleet: FleetData) -> void:
	if not _fleet_figure or _fleet_to_slot.has(fleet.id): return
	var idx: int = _fleet_figure.data.output_slots.size()
	const SlotData := preload("res://core/data/slot_data.gd")
	var slot_data := SlotData.create(fleet.name, 1, idx) # 1 = OUTPUT
	_fleet_figure.data.output_slots.append(slot_data)
	_fleet_to_slot[fleet.id] = slot_data
	_fleet_figure._apply_data()
	workspace.links_layer.refresh()

func _fleet_figure_rename_slot(fleet: FleetData) -> void:
	if not _fleet_figure or not _fleet_to_slot.has(fleet.id): return
	var slot_data = _fleet_to_slot[fleet.id]
	slot_data.label = fleet.name
	_fleet_figure._apply_data()
	workspace.links_layer.refresh()

func _fleet_figure_remove_slot(fleet: FleetData) -> void:
	if not _fleet_figure or not _fleet_to_slot.has(fleet.id): return
	var slot_data = _fleet_to_slot[fleet.id]
	workspace.links_layer.remove_links_for_slot_id(slot_data.id)
	_fleet_figure.data.output_slots.erase(slot_data)
	_fleet_to_slot.erase(fleet.id)
	for i in _fleet_figure.data.output_slots.size():
		_fleet_figure.data.output_slots[i].index = i
	_fleet_figure._apply_data()
	workspace.links_layer.refresh()

# ── Timeline Handlers ──
func _sync_timeline() -> void:
	var all_figure_data: Array = []
	for id in _figures_by_id:
		all_figure_data.append(_figures_by_id[id].data)
	timeline_panel.sync_from_figures(all_figure_data)

func _on_timeline_segment_selected(figure_data) -> void:
	if _syncing_selection: return
	if _figures_by_id.has(figure_data.id):
		_on_figure_selected(_figures_by_id[figure_data.id])

func _on_timeline_segment_moved(_figure_data, _s, _e): pass
func _on_timeline_segment_resized(_figure_data, _s, _e): pass
