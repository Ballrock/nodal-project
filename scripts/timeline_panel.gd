class_name TimelinePanel
extends PanelContainer

## Panneau timeline NLE en bas de l'écran.
## Affiche les boîtes sous forme de segments avec rangées dynamiques (auto-layout).

## Émis quand un segment est sélectionné (pour synchronisation avec le canvas).
signal segment_selected(figure_data: FigureData)
## Émis quand un segment est déplacé (drag horizontal).
signal segment_moved(figure_data: FigureData, new_start: float, new_end: float)
## Émis quand un segment est redimensionné (resize bords).
signal segment_resized(figure_data: FigureData, new_start: float, new_end: float)

## Échelle en pixels par seconde.
var timeline_scale: float = 100.0:
	set(value):
		timeline_scale = clampf(value, 1.0, 100000.0)
		_update_all()

## Hauteur d'une rangée en pixels.
const TRACK_HEIGHT := 30

## Durée maximale en secondes (1 heure). Limite le scroll horizontal.
const MAX_DURATION := 3600.0

## Facteur de zoom par cran de molette.
const TIMELINE_ZOOM_STEP := 1.15
## Couleurs.
const COLOR_BG := Color(0.09, 0.09, 0.11, 1.0)
const COLOR_TRACK_EVEN := Color(0.11, 0.11, 0.13, 1.0)
const COLOR_TRACK_ODD := Color(0.13, 0.13, 0.16, 1.0)
const COLOR_TRACK_BORDER := Color(1.0, 1.0, 1.0, 0.06)

## Décalage horizontal du scroll (en pixels).
var _scroll_offset_x: float = 0.0

## Détection de la plateforme (true si macOS).
var _is_macos: bool = false

## ── Scrollbar iOS-style ──────────────────────────────────
## Opacité courante de la scrollbar (0 = invisible, 1 = visible).
var _scrollbar_opacity: float = 0.0
## Timer interne : temps restant avant de commencer le fade-out (en secondes).
var _scrollbar_visible_timer: float = 0.0
## Durée pendant laquelle la scrollbar reste pleinement visible après un scroll.
const SCROLLBAR_LINGER_TIME := 0.8
## Durée du fade-out de la scrollbar.
const SCROLLBAR_FADE_DURATION := 0.4
## Hauteur de la barre de défilement.
const SCROLLBAR_HEIGHT := 4.0
## Marge inférieure depuis le bas du track area.
const SCROLLBAR_MARGIN_BOTTOM := 3.0
## Marge horizontale.
const SCROLLBAR_MARGIN_H := 4.0
## Couleur de la scrollbar.
const SCROLLBAR_COLOR := Color(1.0, 1.0, 1.0, 0.45)
## Rayon des coins de la scrollbar.
const SCROLLBAR_RADIUS := 2.0

## Segments actuellement affichés (indexés par figure_data.id).
var _segments: Dictionary = {}

## Le segment actuellement sélectionné.
var _selected_segment: TimelineSegment = null

## Assignation dynamique des rangées (figure_data.id → row index).
var _row_assignments: Dictionary = {}
## Nombre de rangées calculées.
var _row_count: int = 1

## Références internes aux sous-nœuds.
var _ruler: TimelineRuler = null
var _track_area: Control = null


func _ready() -> void:
	_is_macos = OS.get_name() == "macOS"
	set_process(true)
	_build_ui()
	# Style du PanelContainer.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	style.border_width_top = 1
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", style)


func _process(delta: float) -> void:
	if _scrollbar_opacity <= 0.0 and _scrollbar_visible_timer <= 0.0:
		return
	if _scrollbar_visible_timer > 0.0:
		_scrollbar_visible_timer -= delta
		if _scrollbar_visible_timer <= 0.0:
			_scrollbar_visible_timer = 0.0
	else:
		# En phase de fade-out.
		_scrollbar_opacity -= delta / SCROLLBAR_FADE_DURATION
		if _scrollbar_opacity <= 0.0:
			_scrollbar_opacity = 0.0
	if _track_area:
		_track_area.queue_redraw()


func _build_ui() -> void:
	# Structure :
	# VBoxContainer
	#   ├── TimelineRuler
	#   └── TrackAreaWrapper (Control, expand, clip)
	#       └── TrackArea (Control, plein rect)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Ruler (aligné avec la zone des segments, temps 0 = bord gauche).
	_ruler = TimelineRuler.new()
	_ruler.timeline_scale = timeline_scale
	_ruler.scroll_offset_x = _scroll_offset_x
	_ruler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_ruler)

	# Wrapper pour la zone des segments (clip children).
	var track_wrapper := Control.new()
	track_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_wrapper.clip_contents = true
	vbox.add_child(track_wrapper)

	# TrackArea : nœud enfant direct, plein rect, contient les segments.
	_track_area = Control.new()
	_track_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_wrapper.add_child(_track_area)

	# Dessine les fonds de rangées.
	_track_area.draw.connect(_on_track_area_draw)


func _on_track_area_draw() -> void:
	var w := _track_area.size.x
	var h := _track_area.size.y
	var row_count := maxi(_row_count, 1)
	# Dessine suffisamment de rangées pour remplir la zone visible.
	var visible_rows := maxi(row_count, ceili(h / TRACK_HEIGHT) + 1)
	for i in visible_rows:
		var y := i * TRACK_HEIGHT
		var bg_color := COLOR_TRACK_EVEN if i % 2 == 0 else COLOR_TRACK_ODD
		_track_area.draw_rect(Rect2(0, y, w, TRACK_HEIGHT), bg_color)
		# Ligne de séparation en bas de chaque rangée.
		_track_area.draw_line(
			Vector2(0, y + TRACK_HEIGHT),
			Vector2(w, y + TRACK_HEIGHT),
			COLOR_TRACK_BORDER,
			1.0,
		)

	# ── Scrollbar iOS-style ──────────────────────────────
	if _scrollbar_opacity > 0.0:
		var max_scroll := maxf(SnapHelper.time_to_pixel(MAX_DURATION, timeline_scale) - _get_track_area_width(), 1.0)
		var visible_width := _get_track_area_width()
		var total_content := SnapHelper.time_to_pixel(MAX_DURATION, timeline_scale)
		if total_content > visible_width:
			var bar_area_w := w - SCROLLBAR_MARGIN_H * 2.0
			var thumb_ratio := clampf(visible_width / total_content, 0.05, 1.0)
			var thumb_w := maxf(bar_area_w * thumb_ratio, 24.0)
			var scroll_ratio := clampf(_scroll_offset_x / max_scroll, 0.0, 1.0)
			var thumb_x := SCROLLBAR_MARGIN_H + scroll_ratio * (bar_area_w - thumb_w)
			var thumb_y := h - SCROLLBAR_HEIGHT - SCROLLBAR_MARGIN_BOTTOM
			var bar_color := SCROLLBAR_COLOR
			bar_color.a *= _scrollbar_opacity
			var bar_rect := Rect2(thumb_x, thumb_y, thumb_w, SCROLLBAR_HEIGHT)
			_draw_scrollbar_rounded_rect(_track_area, bar_rect, bar_color, SCROLLBAR_RADIUS)


## Synchronise l'affichage à partir d'un tableau de FigureData.
## Appelé par main.gd chaque fois que la liste des boîtes change.
func sync_from_figures(figures: Array) -> void:
	# Retire les clips dont le FigureData n'existe plus.
	var valid_ids: Dictionary = {}
	for figure_data: FigureData in figures:
		valid_ids[figure_data.id] = true

	var to_remove: Array[StringName] = []
	for id: StringName in _segments:
		if not valid_ids.has(id):
			to_remove.append(id)
	for id in to_remove:
		var seg: TimelineSegment = _segments[id]
		seg.queue_free()
		_segments.erase(id)

	# Crée ou met à jour les segments.
	for figure_data: FigureData in figures:
		if _segments.has(figure_data.id):
			# Mise à jour.
			var seg: TimelineSegment = _segments[figure_data.id]
			seg.timeline_scale = timeline_scale
			seg.scroll_offset_x = _scroll_offset_x
			seg.update_geometry()
		else:
			_create_segment(figure_data)

	# Calcule les rangées dynamiques et repositionne les segments.
	_compute_rows()
	_apply_row_positions()
	_track_area.queue_redraw()


func _create_segment(figure_data: FigureData) -> void:
	var seg := TimelineSegment.new()
	_track_area.add_child(seg)
	seg.setup(figure_data, timeline_scale, _scroll_offset_x)
	# Le Y sera positionné par _apply_row_positions().
	# Signaux.
	seg.segment_selected.connect(_on_segment_selected)
	seg.segment_moved.connect(_on_segment_moved)
	seg.segment_resized.connect(_on_segment_resized)
	_segments[figure_data.id] = seg


func _on_segment_selected(seg: TimelineSegment) -> void:
	if _selected_segment and _selected_segment != seg:
		_selected_segment.set_selected(false)
	_selected_segment = seg
	seg.set_selected(true)
	segment_selected.emit(seg.figure_data)


func _on_segment_moved(seg: TimelineSegment, new_start: float, new_end: float) -> void:
	# Recalcule les rangées après un déplacement (les chevauchements ont pu changer).
	_compute_rows()
	_apply_row_positions()
	_track_area.queue_redraw()
	segment_moved.emit(seg.figure_data, new_start, new_end)


func _on_segment_resized(seg: TimelineSegment, new_start: float, new_end: float) -> void:
	# Recalcule les rangées après un resize.
	_compute_rows()
	_apply_row_positions()
	_track_area.queue_redraw()
	segment_resized.emit(seg.figure_data, new_start, new_end)


## Sélectionne le segment correspondant à un FigureData (appelé par main.gd pour la sync canvas → timeline).
func select_segment_for_figure(figure_data: FigureData) -> void:
	if figure_data == null:
		deselect_all()
		return
	if _segments.has(figure_data.id):
		var seg: TimelineSegment = _segments[figure_data.id]
		_on_segment_selected(seg)


## Désélectionne tous les segments.
func deselect_all() -> void:
	if _selected_segment:
		_selected_segment.set_selected(false)
		_selected_segment = null


## Rafraîchit la géométrie de tous les clips (après changement de scale ou scroll).
func _update_all() -> void:
	if _ruler:
		_ruler.timeline_scale = timeline_scale
		_ruler.scroll_offset_x = _scroll_offset_x

	for id: StringName in _segments:
		var seg: TimelineSegment = _segments[id]
		seg.timeline_scale = timeline_scale
		seg.scroll_offset_x = _scroll_offset_x
		seg.update_geometry()

	_apply_row_positions()

	if _track_area:
		_track_area.queue_redraw()


## Gère le zoom et le scroll horizontal selon la plateforme.
## Windows : molette verticale = pan horizontal, Ctrl+molette = zoom.
## macOS   : scroll horizontal (trackpad / molette H) = pan, Ctrl+molette verticale = zoom.
## Les deux : molette horizontale native (WHEEL_LEFT/RIGHT) = pan.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var scroll_speed := 30.0

			# ── Molette horizontale native (trackpad ou souris à molette H) ──
			if mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				_apply_horizontal_scroll(-scroll_speed)
				accept_event()
				return
			elif mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				_apply_horizontal_scroll(scroll_speed)
				accept_event()
				return

			# ── Molette verticale ──
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var direction := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0

				if mb.ctrl_pressed:
					# Ctrl + molette → Zoom (les deux OS).
					var factor := TIMELINE_ZOOM_STEP if direction < 0.0 else (1.0 / TIMELINE_ZOOM_STEP)
					_apply_timeline_zoom(factor, mb.position.x)
					accept_event()
					return

				if not _is_macos:
					# Windows / Linux : molette verticale simple → pan horizontal.
					_apply_horizontal_scroll(direction * scroll_speed)
					accept_event()
					return

				# macOS : molette verticale sans Ctrl → ne rien faire (le pan
				# est assuré par le scroll horizontal du trackpad / WHEEL_LEFT/RIGHT).


## Applique un déplacement horizontal (scroll) et affiche la scrollbar.
func _apply_horizontal_scroll(delta_px: float) -> void:
	_scroll_offset_x += delta_px
	_clamp_scroll()
	_show_scrollbar()
	_update_all()


## Rend la scrollbar visible et réinitialise son timer de disparition.
func _show_scrollbar() -> void:
	_scrollbar_opacity = 1.0
	_scrollbar_visible_timer = SCROLLBAR_LINGER_TIME


## Dessine un rectangle arrondi pour la scrollbar (utilitaire appelé dans _on_track_area_draw).
static func _draw_scrollbar_rounded_rect(canvas: Control, rect: Rect2, color: Color, radius: float) -> void:
	var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	var points := PackedVector2Array()
	var steps := 4
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
	canvas.draw_colored_polygon(points, color)


## Applique un zoom timeline centré sur la position X du curseur (en coordonnées locales du panneau).
func _apply_timeline_zoom(factor: float, cursor_local_x: float) -> void:
	var limits := get_timeline_scale_limits()
	var old_scale := timeline_scale
	var new_scale := clampf(timeline_scale * factor, limits.x, limits.y)
	if is_equal_approx(old_scale, new_scale):
		return
	# Le temps sous le curseur doit rester fixe après le zoom.
	var time_under_cursor := SnapHelper.pixel_to_time(_scroll_offset_x + cursor_local_x, old_scale)
	timeline_scale = new_scale
	# Recalcule le scroll_offset_x pour garder le même temps sous le curseur.
	_scroll_offset_x = maxf(SnapHelper.time_to_pixel(time_under_cursor, new_scale) - cursor_local_x, 0.0)
	_clamp_scroll()
	_show_scrollbar()
	_update_all()


## Retourne les limites de scale [min, max] en fonction de la largeur visible du track area.
## min_scale → dézoom max → afficher ~1h de durée.
## max_scale → zoom max → afficher ~1min de durée.
func get_timeline_scale_limits() -> Vector2:
	var visible_width := _get_track_area_width()
	if visible_width <= 0.0:
		visible_width = 800.0  # Valeur de repli raisonnable.
	var min_scale := visible_width / 3600.0  # 1h visible
	var max_scale := visible_width / 15.0    # 15s visible
	# Garantir que les limites sont sensées.
	min_scale = maxf(min_scale, 0.1)
	max_scale = maxf(max_scale, min_scale + 0.1)
	return Vector2(min_scale, max_scale)


## Retourne la largeur utile du track area.
func _get_track_area_width() -> float:
	if _track_area and _track_area.get_parent():
		return _track_area.get_parent().size.x
	return size.x


## Limite le scroll horizontal entre 0 et la position maximale (1h).
func _clamp_scroll() -> void:
	var max_scroll := maxf(SnapHelper.time_to_pixel(MAX_DURATION, timeline_scale) - _get_track_area_width(), 0.0)
	_scroll_offset_x = clampf(_scroll_offset_x, 0.0, max_scroll)


## Calcule les rangées dynamiques : si deux segments se chevauchent en temps,
## le second est placé sur la rangée en dessous (algorithme greedy d'interval partitioning).
func _compute_rows() -> void:
	# Collecte les FigureData des segments existants.
	var figure_list: Array[FigureData] = []
	for id: StringName in _segments:
		var seg: TimelineSegment = _segments[id]
		if seg.figure_data:
			figure_list.append(seg.figure_data)

	# Tri par start_time croissant.
	figure_list.sort_custom(func(a: FigureData, b: FigureData) -> bool: return a.start_time < b.start_time)

	# Greedy : pour chaque segment, le placer dans la première rangée libre.
	var row_ends: Array[float] = []  # row_ends[i] = end_time du dernier segment dans la rangée i.
	_row_assignments.clear()

	for figure_data: FigureData in figure_list:
		var placed := false
		for row_idx in row_ends.size():
			if figure_data.start_time >= row_ends[row_idx]:
				row_ends[row_idx] = figure_data.end_time
				_row_assignments[figure_data.id] = row_idx
				placed = true
				break
		if not placed:
			_row_assignments[figure_data.id] = row_ends.size()
			row_ends.append(figure_data.end_time)

	_row_count = maxi(row_ends.size(), 1)


## Applique les positions Y des segments selon les rangées calculées.
func _apply_row_positions() -> void:
	for id: StringName in _segments:
		var seg: TimelineSegment = _segments[id]
		if seg.figure_data and _row_assignments.has(seg.figure_data.id):
			seg.position.y = _row_assignments[seg.figure_data.id] * TRACK_HEIGHT + 1
