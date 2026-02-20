class_name LinksLayer
extends Control

## Couche de rendu des câbles (Bézier cubiques) entre les slots.
## Gère aussi le drag en cours lors de la création d'un nouveau câble.
## Les liens sont stockés par ID (SlotData/FigureData) et non par référence de nœud,
## pour survivre aux reconstructions de slots (_build_slots).

signal link_created(source_slot: Slot, target_slot: Slot)
## Émis quand un lien existant doit être remplacé (même sortie vers même boîte cible).
signal link_replace_requested(source_slot: Slot, target_slot: Slot, old_link: LinkData)

const LINE_WIDTH := 2.0
const LINE_WIDTH_HOVER := 3.0
const DEFAULT_COLOR := Color("aaaaaa")
const DRAG_COLOR := Color("ffffff")
const SNAP_RADIUS := 30.0

## Données nécessaires au rendu des liens existants.
## Chaque entrée : { link_data: LinkData } — on résout les Slot à la volée.
var _links: Array[Dictionary] = []

## État du drag en cours.
var _dragging: bool = false
var _drag_source_slot: Slot = null
var _drag_end: Vector2 = Vector2.ZERO
var _drag_snap_target: Slot = null

## Référence vers toutes les boîtes pour résoudre les snaps et les liens.
var _figures: Array[Figure] = []


func _ready() -> void:
	# Cette couche ne bloque pas les events souris
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _dragging:
		_drag_end = get_global_mouse_position()
		_drag_snap_target = _find_snap_target(_drag_end)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_drag()


# ── API publique ──────────────────────────────────────────

## Enregistre la liste de boîtes pour la résolution des snaps.
func set_figures(figures: Array[Figure]) -> void:
	_figures = figures


## Ajoute une boîte à la liste (appelé à chaque spawn).
func register_figure(figure: Figure) -> void:
	if not _figures.has(figure):
		_figures.append(figure)
	figure.slot_link_drag_started.connect(_on_slot_link_drag_started)


## Ajoute un lien déjà existant (depuis LinkData).
func add_link(source_slot: Slot, target_slot: Slot, link_data: LinkData) -> void:
	_links.append({
		"link_data": link_data,
	})
	source_slot.set_connected(true)
	target_slot.set_connected(true)
	queue_redraw()


## Supprime un lien par son LinkData.
func remove_link(link_data: LinkData) -> void:
	for i in range(_links.size() - 1, -1, -1):
		if _links[i]["link_data"] == link_data:
			_links.remove_at(i)
			break
	# Met à jour l'état connecté de tous les slots concernés
	_refresh_connected_states()
	queue_redraw()


## Cherche un lien existant depuis un slot de sortie donné vers une boîte cible.
## Retourne le LinkData trouvé ou null.
func find_link_from_output_to_figure(output_slot_id: StringName, target_figure_id: StringName) -> LinkData:
	for link in _links:
		var ld: LinkData = link["link_data"]
		if ld.source_slot_id == output_slot_id and ld.target_figure_id == target_figure_id:
			return ld
	return null


## Cherche le lien existant connecté à un slot d'entrée donné.
## Retourne le LinkData trouvé ou null.
func find_link_connected_to_input(input_slot_id: StringName) -> LinkData:
	for link in _links:
		var ld: LinkData = link["link_data"]
		if ld.target_slot_id == input_slot_id or ld.source_slot_id == input_slot_id:
			return ld
	return null


## Supprime tous les liens liés à un SlotData.id donné.
## Ne rafraîchit PAS les états connectés — l'appelant doit appeler refresh().
func remove_links_for_slot_id(slot_id: StringName) -> void:
	for i in range(_links.size() - 1, -1, -1):
		var ld: LinkData = _links[i]["link_data"]
		if ld.source_slot_id == slot_id or ld.target_slot_id == slot_id:
			_links.remove_at(i)


## Retourne tous les LinkData stockés (pour la sérialisation).
func get_all_link_data() -> Array[LinkData]:
	var result: Array[LinkData] = []
	for link in _links:
		result.append(link["link_data"])
	return result


## Supprime tous les liens.
func clear_all_links() -> void:
	_links.clear()
	_refresh_connected_states()
	queue_redraw()


## Ajoute un lien à partir de données seules (sans résolution de nœuds).
## Appeler refresh() après avoir ajouté tous les liens.
func add_link_from_data(link_data: LinkData) -> void:
	_links.append({"link_data": link_data})


## Supprime toutes les boîtes enregistrées.
func clear_figures() -> void:
	_figures.clear()


## Force le redessin (quand les boîtes bougent).
func refresh() -> void:
	_refresh_connected_states()
	queue_redraw()


## Résout un Slot par figure_id + slot_id parmi toutes les boîtes.
func _resolve_slot(figure_id: StringName, slot_id: StringName) -> Slot:
	for figure in _figures:
		if figure.data and figure.data.id == figure_id:
			var s := figure.find_slot_by_id(slot_id)
			if s:
				return s
	return null


## Parcourt tous les liens et met à jour l'état connecté des slots.
func _refresh_connected_states() -> void:
	# Réinitialise tous les slots à non-connecté
	for figure in _figures:
		for slot in figure.get_all_slots():
			slot.set_connected(false)
	# Marque les slots connectés
	for link in _links:
		var ld: LinkData = link["link_data"]
		var src := _resolve_slot(ld.source_figure_id, ld.source_slot_id)
		var tgt := _resolve_slot(ld.target_figure_id, ld.target_slot_id)
		if src:
			src.set_connected(true)
		if tgt:
			tgt.set_connected(true)


# ── Drag de câble ────────────────────────────────────────

func _on_slot_link_drag_started(slot: Slot, _figure: Figure) -> void:
	_dragging = true
	_drag_source_slot = slot
	_drag_end = slot.get_circle_global_center()
	_drag_snap_target = null


func _finish_drag() -> void:
	_dragging = false
	var target := _drag_snap_target
	_drag_snap_target = null

	if target and _can_connect_or_replace(_drag_source_slot, target):
		# Détermine les vrais rôles OUTPUT / INPUT
		var out_slot := _drag_source_slot
		var in_slot := target
		if _drag_source_slot.data.direction == SlotData.Direction.SLOT_INPUT:
			out_slot = target
			in_slot = _drag_source_slot

		# Règle 3 : l'input cible est déjà connecté → remplacement (prioritaire)
		var existing_on_input := find_link_connected_to_input(in_slot.data.id)
		if existing_on_input:
			link_replace_requested.emit(_drag_source_slot, target, existing_on_input)
		else:
			# Règle 2 : même sortie → même boîte cible → remplacement
			var existing_from_output := find_link_from_output_to_figure(out_slot.data.id, in_slot.owner_figure.data.id)
			if existing_from_output:
				link_replace_requested.emit(_drag_source_slot, target, existing_from_output)
			else:
				link_created.emit(_drag_source_slot, target)

	# Retire le highlight du snap
	if target:
		target.set_highlight(false)

	_drag_source_slot = null
	queue_redraw()


func _find_snap_target(mouse_pos: Vector2) -> Slot:
	var best_slot: Slot = null
	var best_dist := SNAP_RADIUS

	for figure in _figures:
		for slot in figure.get_all_slots():
			if slot == _drag_source_slot:
				continue
			if not _can_connect_or_replace(_drag_source_slot, slot):
				continue
			var dist := mouse_pos.distance_to(slot.get_circle_global_center())
			if dist < best_dist:
				best_dist = dist
				best_slot = slot

	# Highlight gestion
	for figure in _figures:
		for slot in figure.get_all_slots():
			slot.set_highlight(slot == best_slot)

	return best_slot


## Vérifie si la connexion est valide (sans tenir compte du remplacement).
func _is_valid_connection(source: Slot, target: Slot) -> bool:
	if source == null or target == null:
		return false
	if source.data == null or target.data == null:
		return false

	# Doit relier OUTPUT → INPUT exclusivement
	var src_dir := source.data.direction
	var tgt_dir := target.data.direction
	if src_dir == SlotData.Direction.SLOT_INPUT and tgt_dir == SlotData.Direction.SLOT_OUTPUT:
		pass  # INPUT → OUTPUT : valide (inversé à la création)
	elif src_dir == SlotData.Direction.SLOT_OUTPUT and tgt_dir == SlotData.Direction.SLOT_INPUT:
		pass  # OUTPUT → INPUT : valide
	else:
		return false

	# Pas de self-loop
	if source.owner_figure == target.owner_figure:
		return false

	# Un slot d'entrée n'accepte qu'un seul câble
	var input_slot := target if tgt_dir == SlotData.Direction.SLOT_INPUT else source
	if _is_input_already_connected(input_slot):
		return false

	# Règle 1 : une sortie ne peut être reliée qu'à une seule entrée par boîte cible
	var out_slot := source if src_dir == SlotData.Direction.SLOT_OUTPUT else target
	var in_slot := target if tgt_dir == SlotData.Direction.SLOT_INPUT else source
	if _has_link_from_output_to_figure(out_slot.data.id, in_slot.owner_figure.data.id):
		return false

	return true


## Vérifie si on peut connecter ou remplacer (permet le snap même en cas de
## remplacement — règles 2 et 3).
func _can_connect_or_replace(source: Slot, target: Slot) -> bool:
	if source == null or target == null:
		return false
	if source.data == null or target.data == null:
		return false

	var src_dir := source.data.direction
	var tgt_dir := target.data.direction
	if src_dir == SlotData.Direction.SLOT_INPUT and tgt_dir == SlotData.Direction.SLOT_OUTPUT:
		pass
	elif src_dir == SlotData.Direction.SLOT_OUTPUT and tgt_dir == SlotData.Direction.SLOT_INPUT:
		pass
	else:
		return false

	if source.owner_figure == target.owner_figure:
		return false

	var input_slot := target if tgt_dir == SlotData.Direction.SLOT_INPUT else source
	var output_slot := source if src_dir == SlotData.Direction.SLOT_OUTPUT else target

	# Règle 3 : l'input est déjà connecté → remplacement autorisé (snap permis)
	if _is_input_already_connected(input_slot):
		return true

	# Règle 2 : même sortie → même boîte cible → remplacement autorisé
	if _has_link_from_output_to_figure(output_slot.data.id, input_slot.owner_figure.data.id):
		return true

	return true


## Vérifie si un lien existe déjà depuis une sortie vers une boîte donnée.
func _has_link_from_output_to_figure(output_slot_id: StringName, target_figure_id: StringName) -> bool:
	return find_link_from_output_to_figure(output_slot_id, target_figure_id) != null


func _is_input_already_connected(slot: Slot) -> bool:
	if slot.data.direction != SlotData.Direction.SLOT_INPUT:
		return false
	for link in _links:
		var ld: LinkData = link["link_data"]
		if ld.target_slot_id == slot.data.id or ld.source_slot_id == slot.data.id:
			return true
	return false


# ── Rendu ─────────────────────────────────────────────────

## Convertit un point global en coordonnées locales de ce Control.
## Équivalent de Node2D.to_local() mais disponible pour Control.
func _global_to_local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _draw() -> void:
	# Câbles existants — résolution à la volée par ID
	for link in _links:
		var ld: LinkData = link["link_data"]
		var src := _resolve_slot(ld.source_figure_id, ld.source_slot_id)
		var tgt := _resolve_slot(ld.target_figure_id, ld.target_slot_id)
		if src == null or tgt == null:
			continue
		var from := _global_to_local(src.get_circle_global_center())
		var to := _global_to_local(tgt.get_circle_global_center())
		_draw_bezier(from, to, DEFAULT_COLOR, LINE_WIDTH)

	# Câble en cours de drag
	if _dragging and _drag_source_slot:
		var from := _global_to_local(_drag_source_slot.get_circle_global_center())
		var to: Vector2
		if _drag_snap_target:
			to = _global_to_local(_drag_snap_target.get_circle_global_center())
		else:
			to = _global_to_local(_drag_end)
		_draw_bezier(from, to, DRAG_COLOR, LINE_WIDTH)


func _draw_bezier(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var cp_offset: float = abs(to.x - from.x) * 0.5
	cp_offset = max(cp_offset, 50.0)
	var cp1 := from + Vector2(cp_offset, 0)
	var cp2 := to - Vector2(cp_offset, 0)

	var points := PackedVector2Array()
	var segments := 32
	for i in segments + 1:
		var t := float(i) / float(segments)
		points.append(_cubic_bezier(from, cp1, cp2, to, t))

	if points.size() >= 2:
		draw_polyline(points, color, width, true)


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
