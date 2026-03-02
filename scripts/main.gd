extends Control

## Script principal : orchestre le graphe nodal, les flottes, la timeline
## et la sérialisation.

const FigureScene := preload("res://scenes/figure.tscn")

## Couleur d'en-tête de la boîte Flotte (verte, cf. spec §14.3).
const FLEET_FIGURE_COLOR := Color(0.33, 0.75, 0.42)

@onready var canvas_area: Control = %CanvasArea
@onready var canvas_content: Control = %CanvasContent
@onready var figure_container: Control = %FigureContainer
@onready var links_layer: LinksLayer = %LinksLayer
@onready var fleet_panel: FleetPanel = %FleetPanel
@onready var fleet_dialog: FleetDialog = %FleetDialog
@onready var timeline_panel: TimelinePanel = %TimelinePanel
@onready var _toolbar: MenuBar = %Toolbar

## Boîte actuellement sélectionnée (une seule à la fois).
var _selected_figure: Figure = null
## Registre des boîtes par id pour résoudre les liens.
var _figures_by_id: Dictionary = {}

## La boîte Flotte spéciale (non supprimable, 0 entrées, N sorties = flottes).
var _fleet_figure: Figure = null
## Correspondance stable fleet.id → SlotData (évite la récréation d'IDs à chaque sync).
var _fleet_to_slot: Dictionary = {}

## Garde pour éviter la récursion infinie lors de la synchronisation de sélection.
var _syncing_selection: bool = false

## Compteur pour nommer les figures séquentiellement.
var _figure_counter: int = 0

## ── Pan du canvas (clic droit / clic central) ────────────
var _canvas_panning: bool = false
var _canvas_pan_start: Vector2 = Vector2.ZERO
var _canvas_content_start: Vector2 = Vector2.ZERO

# ── Menu ──────────────────────────────────────────────────

@onready var _fichier_menu: PopupMenu = %Fichier
@onready var _element_menu: PopupMenu = %"Élément"

## Gestionnaire des menus de la barre d'outils.
var _menu_manager: MenuManager

## Dialogues fichier pour sauvegarder / charger.
var _save_dialog: FileDialog
var _load_dialog: FileDialog

# ── Zoom du canvas ────────────────────────────────────────
const CANVAS_ZOOM_MIN := 0.25
const CANVAS_ZOOM_MAX := 1.0
const CANVAS_ZOOM_STEP := 1.1
var _canvas_zoom: float = 1.0


func _ready() -> void:
	links_layer.link_created.connect(_on_link_created)
	links_layer.link_replace_requested.connect(_on_link_replace_requested)

	# ── Menus (délégués au MenuManager) ──
	_menu_manager = MenuManager.new()
	_menu_manager.setup(_fichier_menu, _element_menu)
	_menu_manager.save_requested.connect(_on_save_requested)
	_menu_manager.load_requested.connect(_on_load_requested)
	_menu_manager.add_figure_requested.connect(_add_figure)

	# ── Dialogues fichier ──
	_setup_file_dialogs()

	# ── Style de la barre de menus ──
	_style_toolbar()

	# ── Zoom & pan canvas ──
	canvas_area.gui_input.connect(_canvas_area_gui_input)

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

	# ── Boîte Flotte spéciale (créée automatiquement) ──
	var fleet_fig_data := FigureData.create("Flottes", Vector2(270, 150), 0, 0)
	fleet_fig_data.color = FLEET_FIGURE_COLOR
	_fleet_figure = _spawn_figure_from_data(fleet_fig_data, true)

	# Synchronise la timeline avec les boîtes existantes.
	_sync_timeline()


func _gui_input(event: InputEvent) -> void:
	# Clic dans le vide → désélectionne la boîte active
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_deselect_all()


# ── Zoom & pan du canvas (molette / clic droit-central sur CanvasArea) ──

func _canvas_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# ── Pan : clic droit ou clic central ──
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_canvas_panning = true
				_canvas_pan_start = mb.global_position
				_canvas_content_start = canvas_content.position
				canvas_area.accept_event()
			else:
				_canvas_panning = false
				canvas_area.accept_event()
			return

		# ── Zoom : molette ──
		if mb.pressed and not mb.shift_pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_canvas_zoom(CANVAS_ZOOM_STEP, mb.global_position)
				canvas_area.accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_canvas_zoom(1.0 / CANVAS_ZOOM_STEP, mb.global_position)
				canvas_area.accept_event()

	if event is InputEventMouseMotion and _canvas_panning:
		var mm := event as InputEventMouseMotion
		canvas_content.position = _canvas_content_start + (mm.global_position - _canvas_pan_start)
		links_layer.queue_redraw()
		canvas_area.accept_event()


func _apply_canvas_zoom(factor: float, mouse_global: Vector2) -> void:
	var old_zoom := _canvas_zoom
	_canvas_zoom = clampf(_canvas_zoom * factor, CANVAS_ZOOM_MIN, CANVAS_ZOOM_MAX)
	if is_equal_approx(old_zoom, _canvas_zoom):
		return
	# Zoom centré sur la position du curseur.
	var mouse_local := canvas_area.get_global_transform().affine_inverse() * mouse_global
	var content_pos_before := (mouse_local - canvas_content.position) / old_zoom
	canvas_content.scale = Vector2(_canvas_zoom, _canvas_zoom)
	canvas_content.position = mouse_local - content_pos_before * _canvas_zoom
	links_layer.queue_redraw()


func get_canvas_zoom() -> float:
	return _canvas_zoom

## Style la barre de menus pour un rendu sombre sans coins arrondis.
func _style_toolbar() -> void:
	# Couleurs.
	var bg_color := Color(0.11, 0.11, 0.13, 1.0)
	var hover_color := Color(0.22, 0.22, 0.26, 1.0)
	var pressed_color := Color(0.18, 0.18, 0.22, 1.0)

	# StyleBox normal : fond sombre, pas d'arrondi.
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.set_corner_radius_all(0)
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 4
	style_normal.content_margin_bottom = 4

	# StyleBox hover : plus clair.
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = hover_color
	style_hover.set_corner_radius_all(0)
	style_hover.content_margin_left = 8
	style_hover.content_margin_right = 8
	style_hover.content_margin_top = 4
	style_hover.content_margin_bottom = 4

	# StyleBox pressed.
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = pressed_color
	style_pressed.set_corner_radius_all(0)
	style_pressed.content_margin_left = 8
	style_pressed.content_margin_right = 8
	style_pressed.content_margin_top = 4
	style_pressed.content_margin_bottom = 4

	# Appliquer au MenuBar.
	_toolbar.add_theme_stylebox_override("normal", style_normal)
	_toolbar.add_theme_stylebox_override("hover", style_hover)
	_toolbar.add_theme_stylebox_override("pressed", style_pressed)
	_toolbar.add_theme_stylebox_override("disabled", style_normal)

# ── Menus : gestion des actions ─────────────────────────────

## Crée une nouvelle figure au centre de la zone visible du canvas.
func _add_figure() -> void:
	_figure_counter += 1
	var title := "Figure %d" % _figure_counter
	# Calcul du centre visible du canvas (en coordonnées logiques)
	var canvas_center_screen := canvas_area.size / 2.0
	var canvas_center_local := (canvas_center_screen - canvas_content.position) / _canvas_zoom
	var _figure_node := _spawn_figure(title, canvas_center_local, 0, 0)
	_sync_timeline()


# ── Dialogues fichier ─────────────────────────────────────

func _setup_file_dialogs() -> void:
	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.filters = PackedStringArray(["*.json ; Schéma JSON"])
	_save_dialog.title = "Sauvegarder le schéma"
	_save_dialog.size = Vector2i(800, 500)
	_save_dialog.file_selected.connect(_on_save_file_selected)
	add_child(_save_dialog)

	_load_dialog = FileDialog.new()
	_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_load_dialog.filters = PackedStringArray(["*.json ; Schéma JSON"])
	_load_dialog.title = "Charger un schéma"
	_load_dialog.size = Vector2i(800, 500)
	_load_dialog.file_selected.connect(_on_load_file_selected)
	add_child(_load_dialog)


func _on_save_requested() -> void:
	_save_dialog.popup_centered()


func _on_load_requested() -> void:
	_load_dialog.popup_centered()


func _on_save_file_selected(path: String) -> void:
	var data := GraphSerializer.serialize_graph(
		_figures_by_id,
		links_layer,
		fleet_panel,
		_fleet_to_slot,
		_canvas_zoom,
		timeline_panel.timeline_scale,
	)
	var err := GraphSerializer.save_to_file(path, data)
	if err != OK:
		push_error("Erreur lors de la sauvegarde : %s" % error_string(err))


func _on_load_file_selected(path: String) -> void:
	var data := GraphSerializer.load_from_file(path)
	if data.is_empty():
		push_error("Erreur lors du chargement du fichier : %s" % path)
		return
	_load_graph(data)


# ── Sauvegarde / Chargement ──────────────────────────────

## Supprime toutes les figures, liens, flottes et réinitialise l'état.
func _clear_graph() -> void:
	# Désélection
	_selected_figure = null
	_syncing_selection = false

	# Supprimer toutes les figures du scene tree
	for id: StringName in _figures_by_id:
		var figure_node: Figure = _figures_by_id[id]
		figure_container.remove_child(figure_node)
		figure_node.queue_free()
	_figures_by_id.clear()

	# Reset fleet
	_fleet_figure = null
	_fleet_to_slot.clear()

	# Reset links
	links_layer.clear_all_links()
	links_layer.clear_figures()

	# Reset fleet panel
	fleet_panel.clear_fleets()

	# Reset counter
	_figure_counter = 0

	# Sync timeline (vide)
	_sync_timeline()


## Charge un graphe complet à partir d'un dictionnaire désérialisé.
func _load_graph(data: Dictionary) -> void:
	_clear_graph()

	# Restaurer le zoom canvas
	_canvas_zoom = float(data.get("canvas_zoom", 1.0))
	canvas_content.scale = Vector2(_canvas_zoom, _canvas_zoom)

	# Restaurer l'échelle timeline
	timeline_panel.timeline_scale = float(data.get("timeline_scale", 100.0))

	# Restaurer les figures
	var figures_data: Array = data.get("figures", [])
	for fig_dict: Dictionary in figures_data:
		var figure_data := GraphSerializer.dict_to_figure_data(fig_dict)
		var is_fleet := bool(fig_dict.get("is_fleet_figure", false))
		if is_fleet:
			_fleet_figure = _spawn_figure_from_data(figure_data, true)
		else:
			_spawn_figure_from_data(figure_data)
			_figure_counter += 1

	# Si aucune fleet figure n'a été trouvée, en créer une par défaut
	if _fleet_figure == null:
		var fleet_fig_data := FigureData.create("Flottes", Vector2(270, 150), 0, 0)
		fleet_fig_data.color = FLEET_FIGURE_COLOR
		_fleet_figure = _spawn_figure_from_data(fleet_fig_data, true)

	# Restaurer les flottes (affichage dans le panel uniquement,
	# les slots sont déjà dans la fleet figure via les données sauvegardées)
	var fleets_data: Array = data.get("fleets", [])
	var loaded_fleets: Array[FleetData] = []
	for fleet_dict: Dictionary in fleets_data:
		loaded_fleets.append(GraphSerializer.dict_to_fleet_data(fleet_dict))
	fleet_panel.set_fleets(loaded_fleets)

	# Reconstruire le mapping fleet.id → SlotData
	var saved_mapping: Dictionary = data.get("fleet_to_slot", {})
	for fleet_id_str: String in saved_mapping:
		var fleet_id := StringName(fleet_id_str)
		var slot_id := StringName(str(saved_mapping[fleet_id_str]))
		if _fleet_figure:
			for slot_data: SlotData in _fleet_figure.data.output_slots:
				if slot_data.id == slot_id:
					_fleet_to_slot[fleet_id] = slot_data
					break

	# Restaurer les liens
	var links_data: Array = data.get("links", [])
	for link_dict: Dictionary in links_data:
		var link_data := GraphSerializer.dict_to_link_data(link_dict)
		links_layer.add_link_from_data(link_data)

	# Synchroniser la timeline
	_sync_timeline()

	# Rafraîchir les câbles après un frame pour que le layout des slots soit calculé.
	await get_tree().process_frame
	links_layer.refresh()


func _on_figure_selected(figure: Figure) -> void:
	if _syncing_selection:
		return
	_syncing_selection = true
	if _selected_figure and _selected_figure != figure:
		_selected_figure.set_selected(false)
	_selected_figure = figure
	# Synchronise la sélection vers la timeline.
	timeline_panel.select_segment_for_figure(figure.data)
	_syncing_selection = false


func _deselect_all() -> void:
	if _selected_figure:
		_selected_figure.set_selected(false)
		_selected_figure = null
	timeline_panel.deselect_all()


func _spawn_figure(title: String, pos: Vector2, inputs: int = 1, outputs: int = 1, p_start_time: float = 0.0, p_end_time: float = 1.0, p_track: int = 0) -> Figure:
	var figure_data := FigureData.create(title, pos, inputs, outputs, p_start_time, p_end_time, p_track)
	return _spawn_figure_from_data(figure_data)


## Instancie une Figure à partir d'un FigureData existant (utilisé au chargement).
func _spawn_figure_from_data(figure_data: FigureData, p_is_fleet_figure: bool = false) -> Figure:
	var figure_node: Figure = FigureScene.instantiate()
	figure_container.add_child(figure_node)
	figure_node.is_fleet_figure = p_is_fleet_figure
	figure_node.setup(figure_data)
	figure_node.selected.connect(_on_figure_selected)
	# Redessin des câbles quand une boîte bouge
	figure_node.drag_started.connect(func(_b: Figure) -> void: _start_link_refresh())
	figure_node.drag_ended.connect(func(_b: Figure) -> void: _stop_link_refresh())
	# Suppression de lien / slot via menu contextuel
	figure_node.slot_remove_link_requested.connect(_on_slot_remove_link)
	figure_node.slot_delete_requested.connect(_on_slot_delete)
	# Rafraîchir les états connectés quand les slots changent (+)
	figure_node.slots_changed.connect(func(_b: Figure) -> void: links_layer.refresh())
	# Enregistrement dans la couche de liens
	links_layer.register_figure(figure_node)
	_figures_by_id[figure_data.id] = figure_node
	return figure_node


## Appelé par LinksLayer quand une connexion est validée par l'utilisateur.
func _on_link_created(source_slot: Slot, target_slot: Slot) -> void:
	# Normalise : s'assure que source = OUTPUT, target = INPUT
	var out_slot := source_slot
	var in_slot := target_slot
	if source_slot.data.direction == SlotData.Direction.SLOT_INPUT:
		out_slot = target_slot
		in_slot = source_slot

	var link_data := LinkData.create(
		out_slot.owner_figure.data.id,
		out_slot.data.id,
		in_slot.owner_figure.data.id,
		in_slot.data.id,
	)
	links_layer.add_link(out_slot, in_slot, link_data)


## Appelé par LinksLayer quand un lien existant doit être remplacé
## (même sortie vers même boîte cible, entrée différente — règle 2).
func _on_link_replace_requested(source_slot: Slot, target_slot: Slot, old_link: LinkData) -> void:
	# Supprime l'ancien lien
	links_layer.remove_link(old_link)
	# Crée le nouveau
	_on_link_created(source_slot, target_slot)


# ── Rafraîchissement des câbles pendant le drag ──────────

var _refresh_links := false

func _start_link_refresh() -> void:
	_refresh_links = true

func _stop_link_refresh() -> void:
	_refresh_links = false
	links_layer.refresh()

func _process(_delta: float) -> void:
	if _refresh_links:
		links_layer.refresh()


# ── Gestion des Flottes ──────────────────────────────────

# ── Menu contextuel slots : suppression de lien / d'emplacement ──

func _on_slot_remove_link(slot: Slot, _figure: Figure) -> void:
	if slot.data == null:
		return
	links_layer.remove_links_for_slot_id(slot.data.id)
	links_layer.refresh()


func _on_slot_delete(slot: Slot, figure: Figure) -> void:
	if slot.data == null or figure.is_fleet_figure:
		return

	var direction := slot.data.direction

	# Trouver la position réelle dans le tableau par référence d'objet (et non par .index)
	var pos := -1
	if direction == SlotData.Direction.SLOT_INPUT:
		for i in figure.data.input_slots.size():
			if figure.data.input_slots[i] == slot.data:
				pos = i
				break
	else:
		for i in figure.data.output_slots.size():
			if figure.data.output_slots[i] == slot.data:
				pos = i
				break

	if pos < 0:
		return

	# Trouver le slot symétrique (même position, direction opposée)
	var sym_slot_data: SlotData = null
	if direction == SlotData.Direction.SLOT_INPUT:
		if pos < figure.data.output_slots.size():
			sym_slot_data = figure.data.output_slots[pos]
	else:
		if pos < figure.data.input_slots.size():
			sym_slot_data = figure.data.input_slots[pos]

	# Supprimer les liens des deux slots (silencieux — pas de refresh)
	links_layer.remove_links_for_slot_id(slot.data.id)
	if sym_slot_data:
		links_layer.remove_links_for_slot_id(sym_slot_data.id)

	# Supprimer la paire entrée + sortie à cette position
	if direction == SlotData.Direction.SLOT_INPUT:
		figure.data.input_slots.remove_at(pos)
		if pos < figure.data.output_slots.size():
			figure.data.output_slots.remove_at(pos)
	else:
		figure.data.output_slots.remove_at(pos)
		if pos < figure.data.input_slots.size():
			figure.data.input_slots.remove_at(pos)

	# Renuméroter les index et relabelliser séquentiellement
	figure.relabel_slots()

	figure._build_slots()
	figure._set_children_mouse_filter(figure)
	links_layer.refresh()


func _on_add_fleet_requested() -> void:
	fleet_dialog.open_create()


func _on_edit_fleet_requested(fleet: FleetData) -> void:
	fleet_dialog.open_edit(fleet)


func _on_fleet_created(fleet: FleetData) -> void:
	fleet_panel.add_fleet(fleet)
	_fleet_figure_add_slot(fleet)


func _on_fleet_updated(fleet: FleetData) -> void:
	fleet_panel.update_fleet(fleet)
	_fleet_figure_rename_slot(fleet)


func _on_fleet_deleted(fleet: FleetData) -> void:
	fleet_panel.remove_fleet(fleet)
	_fleet_figure_remove_slot(fleet)


## Ajoute un slot de sortie pour une nouvelle flotte (ne touche pas aux liens existants).
func _fleet_figure_add_slot(fleet: FleetData) -> void:
	if not _fleet_figure or _fleet_to_slot.has(fleet.id):
		return
	var idx := _fleet_figure.data.output_slots.size()
	var slot_data := SlotData.create(fleet.name, SlotData.Direction.SLOT_OUTPUT, idx)
	_fleet_figure.data.output_slots.append(slot_data)
	_fleet_to_slot[fleet.id] = slot_data
	_fleet_figure._apply_data()
	links_layer.refresh()


## Renomme le label du slot correspondant à la flotte (préserve les connexions).
func _fleet_figure_rename_slot(fleet: FleetData) -> void:
	if not _fleet_figure or not _fleet_to_slot.has(fleet.id):
		return
	var slot_data: SlotData = _fleet_to_slot[fleet.id]
	slot_data.label = fleet.name
	_fleet_figure._apply_data()
	links_layer.refresh()


## Supprime le slot et les câbles liés à une flotte supprimée.
func _fleet_figure_remove_slot(fleet: FleetData) -> void:
	if not _fleet_figure or not _fleet_to_slot.has(fleet.id):
		return
	var slot_data: SlotData = _fleet_to_slot[fleet.id]
	# Supprimer silencieusement les liens de ce slot
	links_layer.remove_links_for_slot_id(slot_data.id)
	# Retirer du tableau
	_fleet_figure.data.output_slots.erase(slot_data)
	_fleet_to_slot.erase(fleet.id)
	# Renuméroter les slots restants
	for i in _fleet_figure.data.output_slots.size():
		_fleet_figure.data.output_slots[i].index = i
	_fleet_figure._apply_data()
	links_layer.refresh()


# ── Timeline ─────────────────────────────────────────────

## Synchronise le panneau timeline avec la liste de toutes les boîtes.
func _sync_timeline() -> void:
	var all_figure_data: Array = []
	for id: StringName in _figures_by_id:
		var figure_node: Figure = _figures_by_id[id]
		all_figure_data.append(figure_node.data)
	timeline_panel.sync_from_figures(all_figure_data)


## Sélection d'un segment sur la timeline → sélectionne la boîte correspondante sur le canvas.
func _on_timeline_segment_selected(figure_data: FigureData) -> void:
	if _syncing_selection:
		return
	_syncing_selection = true
	if _figures_by_id.has(figure_data.id):
		var figure_node: Figure = _figures_by_id[figure_data.id]
		if _selected_figure and _selected_figure != figure_node:
			_selected_figure.set_selected(false)
		figure_node.set_selected(true)
		_selected_figure = figure_node
	_syncing_selection = false


## Un segment a été déplacé sur la timeline (indépendant du canvas).
func _on_timeline_segment_moved(_figure_data: FigureData, _new_start: float, _new_end: float) -> void:
	# Les données start_time/end_time sont déjà mises à jour par le segment.
	# La position sur le canvas n'est PAS modifiée (découplage canvas/timeline).
	pass


## Un segment a été redimensionné (indépendant du canvas).
func _on_timeline_segment_resized(_figure_data: FigureData, _new_start: float, _new_end: float) -> void:
	# Les données start_time/end_time sont déjà mises à jour par le segment.
	# La position sur le canvas n'est PAS modifiée (découplage canvas/timeline).
	pass
