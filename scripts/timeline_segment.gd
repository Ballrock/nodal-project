class_name TimelineSegment
extends Control

## Segment (bloc) représentant une boîte sur le panneau timeline NLE.
## Positionné selon start_time/end_time, draggable et resizable.

signal segment_selected(segment: TimelineSegment)
signal segment_moved(segment: TimelineSegment, new_start: float, new_end: float)
signal segment_resized(segment: TimelineSegment, new_start: float, new_end: float)

## Données de la boîte liée à ce segment.
var box_data: BoxData = null

## Échelle en pixels par seconde (définie par le TimelinePanel parent).
var timeline_scale: float = 100.0

## Décalage horizontal du scroll (pixels).
var scroll_offset_x: float = 0.0

## Largeur de la zone de grip pour le resize (px).
const GRIP_WIDTH := 5.0
## Rayon des coins arrondis du segment.
const CORNER_RADIUS := 4.0
## Hauteur du segment (= hauteur de la piste).
const CLIP_HEIGHT := 28.0

## Couleurs.
const COLOR_SELECTED_BORDER := Color("f5c542")
const COLOR_LABEL := Color(1.0, 1.0, 1.0, 0.9)
const LABEL_FONT_SIZE := 11
const BORDER_WIDTH_DEFAULT := 1
const BORDER_WIDTH_SELECTED := 2

var _is_selected: bool = false
var _dragging: bool = false
var _resizing_left: bool = false
var _resizing_right: bool = false
var _drag_start_mouse_x: float = 0.0
var _drag_start_time: float = 0.0
var _drag_end_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = CLIP_HEIGHT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(p_box_data: BoxData, p_scale: float, p_scroll_offset: float = 0.0) -> void:
	box_data = p_box_data
	timeline_scale = p_scale
	scroll_offset_x = p_scroll_offset
	update_geometry()


## Met à jour la position et la taille du clip à partir des données.
func update_geometry() -> void:
	if box_data == null:
		return
	var px_start: float = SnapHelper.time_to_pixel(box_data.start_time, timeline_scale) - scroll_offset_x
	var px_end: float = SnapHelper.time_to_pixel(box_data.end_time, timeline_scale) - scroll_offset_x
	var w := maxf(px_end - px_start, 4.0)  # Largeur minimale 4px
	position.x = px_start
	size = Vector2(w, CLIP_HEIGHT)
	queue_redraw()


func set_selected(selected: bool) -> void:
	_is_selected = selected
	queue_redraw()


func _draw() -> void:
	if box_data == null:
		return

	var rect := Rect2(Vector2.ZERO, size)

	# Fond du clip (couleur de la boîte).
	var clip_color: Color = box_data.color
	clip_color.a = 0.85
	_draw_rounded_rect(rect, clip_color)

	# Bordure de sélection.
	if _is_selected:
		_draw_rounded_border(rect, COLOR_SELECTED_BORDER, BORDER_WIDTH_SELECTED)

	# Label (titre de la boîte).
	var label := box_data.title
	var text_pos := Vector2(6, size.y * 0.5 + LABEL_FONT_SIZE * 0.35)
	var max_width := size.x - 12.0
	if max_width > 10.0:
		draw_string(
			ThemeDB.fallback_font,
			text_pos,
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			int(max_width),
			LABEL_FONT_SIZE,
			COLOR_LABEL,
		)

	# Indicateurs de grip (petites barres aux extrémités).
	if size.x > 20.0:
		var grip_color := Color(1.0, 1.0, 1.0, 0.3)
		# Grip gauche.
		draw_line(Vector2(2, 6), Vector2(2, size.y - 6), grip_color, 1.0)
		# Grip droite.
		draw_line(Vector2(size.x - 3, 6), Vector2(size.x - 3, size.y - 6), grip_color, 1.0)


func _gui_input(event: InputEvent) -> void:
	if box_data == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_handle_press(mb)
			else:
				_handle_release()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging or _resizing_left or _resizing_right:
			_handle_drag(mm)
		else:
			_update_cursor(mm.position)


func _handle_press(mb: InputEventMouseButton) -> void:
	var local_x := mb.position.x

	# Vérifie si on est dans un grip de resize.
	if local_x <= GRIP_WIDTH:
		_resizing_left = true
		_drag_start_mouse_x = mb.global_position.x
		_drag_start_time = box_data.start_time
		_drag_end_time = box_data.end_time
	elif local_x >= size.x - GRIP_WIDTH:
		_resizing_right = true
		_drag_start_mouse_x = mb.global_position.x
		_drag_start_time = box_data.start_time
		_drag_end_time = box_data.end_time
	else:
		_dragging = true
		_drag_start_mouse_x = mb.global_position.x
		_drag_start_time = box_data.start_time
		_drag_end_time = box_data.end_time

	segment_selected.emit(self)
	accept_event()


func _handle_release() -> void:
	if _dragging:
		segment_moved.emit(self, box_data.start_time, box_data.end_time)
	elif _resizing_left or _resizing_right:
		segment_resized.emit(self, box_data.start_time, box_data.end_time)
	_dragging = false
	_resizing_left = false
	_resizing_right = false


func _handle_drag(mm: InputEventMouseMotion) -> void:
	var delta_px := mm.global_position.x - _drag_start_mouse_x
	var delta_time: float = SnapHelper.pixel_to_time(delta_px, timeline_scale)
	var shift_held := Input.is_key_pressed(KEY_SHIFT)

	if _dragging:
		var new_start := _drag_start_time + delta_time
		var duration := _drag_end_time - _drag_start_time
		if not shift_held:
			new_start = SnapHelper.snap_time(new_start, timeline_scale)
		new_start = maxf(new_start, 0.0)
		box_data.start_time = new_start
		box_data.end_time = new_start + duration

	elif _resizing_left:
		var new_start := _drag_start_time + delta_time
		if not shift_held:
			new_start = SnapHelper.snap_time(new_start, timeline_scale)
		new_start = maxf(new_start, 0.0)
		new_start = minf(new_start, box_data.end_time - SnapHelper.pixel_to_time(4.0, timeline_scale))
		box_data.start_time = new_start

	elif _resizing_right:
		var new_end := _drag_end_time + delta_time
		if not shift_held:
			new_end = SnapHelper.snap_time(new_end, timeline_scale)
		new_end = maxf(new_end, box_data.start_time + SnapHelper.pixel_to_time(4.0, timeline_scale))
		box_data.end_time = new_end

	update_geometry()
	accept_event()


func _update_cursor(local_pos: Vector2) -> void:
	if local_pos.x <= GRIP_WIDTH or local_pos.x >= size.x - GRIP_WIDTH:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# ── Dessin utilitaires ────────────────────────────────────

func _draw_rounded_rect(rect: Rect2, color: Color) -> void:
	var points := _get_rounded_rect_points(rect, CORNER_RADIUS)
	draw_colored_polygon(points, color)


func _draw_rounded_border(rect: Rect2, color: Color, width: float) -> void:
	var points := _get_rounded_rect_points(rect, CORNER_RADIUS)
	points.append(points[0])  # Fermer le polygone.
	draw_polyline(points, color, width)


func _get_rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	var steps := 4  # Segments par coin.

	# Coin haut-gauche.
	for i in range(steps + 1):
		var angle := PI + (PI * 0.5) * (float(i) / steps)
		points.append(Vector2(rect.position.x + r + cos(angle) * r, rect.position.y + r + sin(angle) * r))
	# Coin haut-droite.
	for i in range(steps + 1):
		var angle := PI * 1.5 + (PI * 0.5) * (float(i) / steps)
		points.append(Vector2(rect.end.x - r + cos(angle) * r, rect.position.y + r + sin(angle) * r))
	# Coin bas-droite.
	for i in range(steps + 1):
		var angle := 0.0 + (PI * 0.5) * (float(i) / steps)
		points.append(Vector2(rect.end.x - r + cos(angle) * r, rect.end.y - r + sin(angle) * r))
	# Coin bas-gauche.
	for i in range(steps + 1):
		var angle := PI * 0.5 + (PI * 0.5) * (float(i) / steps)
		points.append(Vector2(rect.position.x + r + cos(angle) * r, rect.end.y - r + sin(angle) * r))

	return points
