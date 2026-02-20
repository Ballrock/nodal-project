extends Control

## Script principal : instancie des boîtes de test avec slots paramétrables,
## gère les câbles, le volet Flottes et la boîte Flotte.

const BoxScene := preload("res://scenes/box.tscn")

## Couleur d'en-tête de la boîte Flotte (verte, cf. spec §14.3).
const FLEET_BOX_COLOR := Color(0.33, 0.75, 0.42)

@onready var box_container: Control = %BoxContainer
@onready var links_layer: LinksLayer = %LinksLayer
@onready var fleet_panel: FleetPanel = %FleetPanel
@onready var fleet_dialog: FleetDialog = %FleetDialog
@onready var timeline_panel: TimelinePanel = %TimelinePanel

## Boîte actuellement sélectionnée (une seule à la fois).
var _selected_box: Box = null
## Registre des boîtes par id pour résoudre les liens.
var _boxes_by_id: Dictionary = {}

## La boîte Flotte spéciale (non supprimable, 0 entrées, N sorties = flottes).
var _fleet_box: Box = null
## Correspondance stable fleet.id → SlotData (évite la récréation d'IDs à chaque sync).
var _fleet_to_slot: Dictionary = {}

## Garde pour éviter la récursion infinie lors de la synchronisation de sélection.
var _syncing_selection: bool = false


func _ready() -> void:
	links_layer.link_created.connect(_on_link_created)
	links_layer.link_replace_requested.connect(_on_link_replace_requested)

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
	_fleet_box = _spawn_box("Flottes", Vector2(270, 150), 0, 0)
	_fleet_box.data.color = FLEET_BOX_COLOR
	_fleet_box.is_fleet_box = true
	_fleet_box._apply_data()

	# ── Boîtes de test ──
	_spawn_box("Démarrage", Vector2(550, 200), 2, 2, 0.5, 2.5, 0)
	_spawn_box("Traitement", Vector2(850, 150), 2, 2, 3.0, 5.0, 1)

	# Synchronise la timeline avec les boîtes existantes.
	_sync_timeline()


func _gui_input(event: InputEvent) -> void:
	# Clic dans le vide → désélectionne la boîte active
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_deselect_all()


func _on_box_selected(box: Box) -> void:
	if _syncing_selection:
		return
	_syncing_selection = true
	if _selected_box and _selected_box != box:
		_selected_box.set_selected(false)
	_selected_box = box
	# Synchronise la sélection vers la timeline.
	timeline_panel.select_segment_for_box(box.data)
	_syncing_selection = false


func _deselect_all() -> void:
	if _selected_box:
		_selected_box.set_selected(false)
		_selected_box = null
	timeline_panel.deselect_all()


func _spawn_box(title: String, pos: Vector2, inputs: int = 1, outputs: int = 1, p_start_time: float = 0.0, p_end_time: float = 1.0, p_track: int = 0) -> Box:
	var box_node: Box = BoxScene.instantiate()
	box_container.add_child(box_node)
	var box_data := BoxData.create(title, pos, inputs, outputs, p_start_time, p_end_time, p_track)
	box_node.setup(box_data)
	box_node.selected.connect(_on_box_selected)
	# Redessin des câbles quand une boîte bouge
	box_node.drag_started.connect(func(_b: Box) -> void: _start_link_refresh())
	box_node.drag_ended.connect(func(_b: Box) -> void: _stop_link_refresh())
	# Suppression de lien / slot via menu contextuel
	box_node.slot_remove_link_requested.connect(_on_slot_remove_link)
	box_node.slot_delete_requested.connect(_on_slot_delete)
	# Rafraîchir les états connectés quand les slots changent (+)
	box_node.slots_changed.connect(func(_b: Box) -> void: links_layer.refresh())
	# Enregistrement dans la couche de liens
	links_layer.register_box(box_node)
	_boxes_by_id[box_data.id] = box_node
	return box_node


## Appelé par LinksLayer quand une connexion est validée par l'utilisateur.
func _on_link_created(source_slot: Slot, target_slot: Slot) -> void:
	# Normalise : s'assure que source = OUTPUT, target = INPUT
	var out_slot := source_slot
	var in_slot := target_slot
	if source_slot.data.direction == SlotData.Direction.SLOT_INPUT:
		out_slot = target_slot
		in_slot = source_slot

	var link_data := LinkData.create(
		out_slot.owner_box.data.id,
		out_slot.data.id,
		in_slot.owner_box.data.id,
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

func _on_slot_remove_link(slot: Slot, _box: Box) -> void:
	if slot.data == null:
		return
	links_layer.remove_links_for_slot_id(slot.data.id)
	links_layer.refresh()


func _on_slot_delete(slot: Slot, box: Box) -> void:
	if slot.data == null or box.is_fleet_box:
		return

	var direction := slot.data.direction

	# Trouver la position réelle dans le tableau par référence d'objet (et non par .index)
	var pos := -1
	if direction == SlotData.Direction.SLOT_INPUT:
		for i in box.data.input_slots.size():
			if box.data.input_slots[i] == slot.data:
				pos = i
				break
	else:
		for i in box.data.output_slots.size():
			if box.data.output_slots[i] == slot.data:
				pos = i
				break

	if pos < 0:
		return

	# Trouver le slot symétrique (même position, direction opposée)
	var sym_slot_data: SlotData = null
	if direction == SlotData.Direction.SLOT_INPUT:
		if pos < box.data.output_slots.size():
			sym_slot_data = box.data.output_slots[pos]
	else:
		if pos < box.data.input_slots.size():
			sym_slot_data = box.data.input_slots[pos]

	# Supprimer les liens des deux slots (silencieux — pas de refresh)
	links_layer.remove_links_for_slot_id(slot.data.id)
	if sym_slot_data:
		links_layer.remove_links_for_slot_id(sym_slot_data.id)

	# Supprimer la paire entrée + sortie à cette position
	if direction == SlotData.Direction.SLOT_INPUT:
		box.data.input_slots.remove_at(pos)
		if pos < box.data.output_slots.size():
			box.data.output_slots.remove_at(pos)
	else:
		box.data.output_slots.remove_at(pos)
		if pos < box.data.input_slots.size():
			box.data.input_slots.remove_at(pos)

	# Renuméroter les index et relabelliser séquentiellement
	box.relabel_slots()

	box._build_slots()
	box._set_children_mouse_filter(box)
	links_layer.refresh()


func _on_add_fleet_requested() -> void:
	fleet_dialog.open_create()


func _on_edit_fleet_requested(fleet: FleetData) -> void:
	fleet_dialog.open_edit(fleet)


func _on_fleet_created(fleet: FleetData) -> void:
	fleet_panel.add_fleet(fleet)
	_fleet_box_add_slot(fleet)


func _on_fleet_updated(fleet: FleetData) -> void:
	fleet_panel.update_fleet(fleet)
	_fleet_box_rename_slot(fleet)


func _on_fleet_deleted(fleet: FleetData) -> void:
	fleet_panel.remove_fleet(fleet)
	_fleet_box_remove_slot(fleet)


## Ajoute un slot de sortie pour une nouvelle flotte (ne touche pas aux liens existants).
func _fleet_box_add_slot(fleet: FleetData) -> void:
	if not _fleet_box or _fleet_to_slot.has(fleet.id):
		return
	var idx := _fleet_box.data.output_slots.size()
	var slot_data := SlotData.create(fleet.name, SlotData.Direction.SLOT_OUTPUT, idx)
	_fleet_box.data.output_slots.append(slot_data)
	_fleet_to_slot[fleet.id] = slot_data
	_fleet_box._apply_data()
	links_layer.refresh()


## Renomme le label du slot correspondant à la flotte (préserve les connexions).
func _fleet_box_rename_slot(fleet: FleetData) -> void:
	if not _fleet_box or not _fleet_to_slot.has(fleet.id):
		return
	var slot_data: SlotData = _fleet_to_slot[fleet.id]
	slot_data.label = fleet.name
	_fleet_box._apply_data()
	links_layer.refresh()


## Supprime le slot et les câbles liés à une flotte supprimée.
func _fleet_box_remove_slot(fleet: FleetData) -> void:
	if not _fleet_box or not _fleet_to_slot.has(fleet.id):
		return
	var slot_data: SlotData = _fleet_to_slot[fleet.id]
	# Supprimer silencieusement les liens de ce slot
	links_layer.remove_links_for_slot_id(slot_data.id)
	# Retirer du tableau
	_fleet_box.data.output_slots.erase(slot_data)
	_fleet_to_slot.erase(fleet.id)
	# Renuméroter les slots restants
	for i in _fleet_box.data.output_slots.size():
		_fleet_box.data.output_slots[i].index = i
	_fleet_box._apply_data()
	links_layer.refresh()


# ── Timeline ─────────────────────────────────────────────

## Synchronise le panneau timeline avec la liste de toutes les boîtes.
func _sync_timeline() -> void:
	var all_box_data: Array = []
	for id: StringName in _boxes_by_id:
		var box_node: Box = _boxes_by_id[id]
		all_box_data.append(box_node.data)
	timeline_panel.sync_from_boxes(all_box_data)


## Sélection d'un segment sur la timeline → sélectionne la boîte correspondante sur le canvas.
func _on_timeline_segment_selected(box_data: BoxData) -> void:
	if _syncing_selection:
		return
	_syncing_selection = true
	if _boxes_by_id.has(box_data.id):
		var box_node: Box = _boxes_by_id[box_data.id]
		if _selected_box and _selected_box != box_node:
			_selected_box.set_selected(false)
		box_node.set_selected(true)
		_selected_box = box_node
	_syncing_selection = false


## Un segment a été déplacé sur la timeline (indépendant du canvas).
func _on_timeline_segment_moved(_box_data: BoxData, _new_start: float, _new_end: float) -> void:
	# Les données start_time/end_time sont déjà mises à jour par le segment.
	# La position sur le canvas n'est PAS modifiée (découplage canvas/timeline).
	pass


## Un segment a été redimensionné (indépendant du canvas).
func _on_timeline_segment_resized(_box_data: BoxData, _new_start: float, _new_end: float) -> void:
	# Les données start_time/end_time sont déjà mises à jour par le segment.
	# La position sur le canvas n'est PAS modifiée (découplage canvas/timeline).
	pass
