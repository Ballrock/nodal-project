extends Control

## Minimap : affiche une vue d'ensemble du workspace et de la vue actuelle.

## Référence au Workspace pour obtenir les données du graphe et du canvas.
var workspace_node: Node = null

## Couleur du fond de la minimap.
@export var background_color := Color(0, 0, 0, 0.3)
## Couleur des figures dans la minimap.
@export var figure_color := Color(1, 1, 1, 0.6)
## Couleur des liens dans la minimap.
@export var link_color := Color(1, 1, 1, 0.3)
## Couleur de l'indicateur de vue (viewport).
@export var viewport_color := Color(1, 1, 0, 0.5)

## Marge interne pour ne pas coller aux bords de la minimap.
const PADDING := 10.0

func _ready() -> void:
	# On cherche le noeud Workspace (parent direct ou via owner)
	workspace_node = get_parent()
	while workspace_node and not workspace_node.has_method("get_workspace_rect"):
		workspace_node = workspace_node.get_parent()
	
	# Forcer le redraw régulièrement
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not workspace_node:
		return
	
	# 1. Dessiner le fond
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	
	# 2. Obtenir les données nécessaires
	var workspace_rect: Rect2 = workspace_node.get_workspace_rect()
	var canvas_area: Control = workspace_node.canvas_area
	var canvas_content: Control = workspace_node.canvas_content
	var canvas_zoom: float = workspace_node.get_canvas_zoom()
	var figure_container: Control = workspace_node.figure_container
	
	if workspace_rect.size.x <= 0 or workspace_rect.size.y <= 0:
		return

	# 3. Calculer le ratio de mise à l'échelle
	var available_size := size - Vector2(PADDING * 2, PADDING * 2)
	var scale_factor: float = min(available_size.x / workspace_rect.size.x, available_size.y / workspace_rect.size.y)
	
	var offset := Vector2(PADDING, PADDING)
	offset += (available_size - workspace_rect.size * scale_factor) / 2.0

	var to_minimap := func(pos: Vector2) -> Vector2:
		return offset + (pos - workspace_rect.position) * scale_factor

	# 4. Dessiner les figures
	for figure in figure_container.get_children():
		if not figure is Figure: continue
		var fig_rect := Rect2(figure.position, figure.size)
		var mini_fig_pos: Vector2 = to_minimap.call(fig_rect.position)
		var mini_fig_size: Vector2 = fig_rect.size * scale_factor
		mini_fig_size = mini_fig_size.max(Vector2(2, 2))
		
		var color := figure_color
		if figure.data:
			color = figure.data.color
			color.a = 0.8
		draw_rect(Rect2(mini_fig_pos, mini_fig_size), color)

	# 4.5 Dessiner les liens
	var links: Array[LinkData] = workspace_node.links_layer.get_all_link_data()
	var canvas_transform_inv := canvas_content.get_global_transform().affine_inverse()
	for ld in links:
		# Résolution des figures via le container (plus lent mais découplé)
		var src_fig: Figure = null
		var tgt_fig: Figure = null
		for figure in figure_container.get_children():
			if not figure is Figure: continue
			if figure.data.id == ld.source_figure_id: src_fig = figure
			if figure.data.id == ld.target_figure_id: tgt_fig = figure
			if src_fig and tgt_fig: break
			
		if src_fig and tgt_fig:
			var src_slot: Slot = src_fig.find_slot_by_id(ld.source_slot_id)
			var tgt_slot: Slot = tgt_fig.find_slot_by_id(ld.target_slot_id)
			if src_slot and tgt_slot:
				var from_ws: Vector2 = canvas_transform_inv * src_slot.get_circle_global_center()
				var to_ws: Vector2 = canvas_transform_inv * tgt_slot.get_circle_global_center()
				var mini_from: Vector2 = to_minimap.call(from_ws)
				var mini_to: Vector2 = to_minimap.call(to_ws)
				_draw_mini_bezier(mini_from, mini_to, link_color, 1.0)

	# 5. Dessiner le viewport
	var view_pos: Vector2 = -canvas_content.position / canvas_zoom
	var view_size: Vector2 = canvas_area.size / canvas_zoom
	var view_rect_in_workspace := Rect2(view_pos, view_size)
	var mini_view_pos: Vector2 = to_minimap.call(view_rect_in_workspace.position)
	var mini_view_size: Vector2 = view_rect_in_workspace.size * scale_factor
	
	var mini_map_rect := Rect2(offset, workspace_rect.size * scale_factor)
	var clamped_rect := Rect2(mini_view_pos, mini_view_size).intersection(mini_map_rect)
	
	if clamped_rect.size.x > 0 and clamped_rect.size.y > 0:
		draw_rect(clamped_rect, viewport_color, false, 1.0)
	
	draw_rect(mini_map_rect, Color(1, 1, 1, 0.1), false, 1.0)

func _draw_mini_bezier(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var cp_offset: float = abs(to.x - from.x) * 0.5
	cp_offset = max(cp_offset, 2.0) 
	var cp1 := from + Vector2(cp_offset, 0)
	var cp2 := to - Vector2(cp_offset, 0)
	var points := PackedVector2Array()
	var segments := 8
	for i in segments + 1:
		var t := float(i) / float(segments)
		points.append(_cubic_bezier(from, cp1, cp2, to, t))
	draw_polyline(points, color, width, true)

func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_minimap_click(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_handle_minimap_click(mm.position)

func _handle_minimap_click(click_pos: Vector2) -> void:
	if not workspace_node:
		return
		
	var workspace_rect: Rect2 = workspace_node.get_workspace_rect()
	var canvas_area: Control = workspace_node.canvas_area
	var canvas_content: Control = workspace_node.canvas_content
	var canvas_zoom: float = workspace_node.get_canvas_zoom()
	
	var available_size := size - Vector2(PADDING * 2, PADDING * 2)
	var scale_factor: float = min(available_size.x / workspace_rect.size.x, available_size.y / workspace_rect.size.y)
	var offset: Vector2 = Vector2(PADDING, PADDING) + (available_size - workspace_rect.size * scale_factor) / 2.0
	
	var local_click := click_pos - offset
	local_click = local_click.clamp(Vector2.ZERO, workspace_rect.size * scale_factor)
	var workspace_pos: Vector2 = workspace_rect.position + local_click / scale_factor
	var new_content_pos: Vector2 = (canvas_area.size / 2.0) - (workspace_pos * canvas_zoom)
	canvas_content.position = new_content_pos
	workspace_node.links_layer.queue_redraw()
