class_name TimelinePanel
extends PanelContainer

## Panneau timeline NLE en bas de l'écran.
## Affiche les boîtes sous forme de segments sur des pistes (tracks).

## Émis quand un segment est sélectionné (pour synchronisation avec le canvas).
signal segment_selected(box_data: BoxData)
## Émis quand un segment est déplacé (drag horizontal).
signal segment_moved(box_data: BoxData, new_start: float, new_end: float)
## Émis quand un segment est redimensionné (resize bords).
signal segment_resized(box_data: BoxData, new_start: float, new_end: float)

## Échelle en pixels par seconde.
var timeline_scale: float = 100.0:
	set(value):
		timeline_scale = maxf(value, 1.0)
		_update_all()

## Nombre de pistes affichées.
var track_count: int = 4

## Hauteur d'une piste en pixels.
const TRACK_HEIGHT := 30
## Largeur de la colonne des labels de piste.
const LABEL_COLUMN_WIDTH := 120
## Couleurs.
const COLOR_BG := Color(0.09, 0.09, 0.11, 1.0)
const COLOR_TRACK_EVEN := Color(0.11, 0.11, 0.13, 1.0)
const COLOR_TRACK_ODD := Color(0.13, 0.13, 0.16, 1.0)
const COLOR_TRACK_BORDER := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_TRACK_LABEL := Color(1.0, 1.0, 1.0, 0.4)
const LABEL_FONT_SIZE := 10

## Décalage horizontal du scroll (en pixels).
var _scroll_offset_x: float = 0.0

## Segments actuellement affichés (indexés par box_data.id).
var _segments: Dictionary = {}

## Le segment actuellement sélectionné.
var _selected_segment: TimelineSegment = null

## Références internes aux sous-nœuds.
var _ruler: TimelineRuler = null
var _track_area: Control = null
var _track_labels_container: VBoxContainer = null


func _ready() -> void:
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


func _build_ui() -> void:
	# Structure :
	# VBoxContainer
	#   ├── TimelineRuler
	#   └── HBoxContainer
	#       ├── TrackLabels (VBoxContainer, largeur fixe)
	#       └── TrackAreaWrapper (Control, expand)
	#           └── TrackArea (Control, grand, clippé)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Ruler.
	_ruler = TimelineRuler.new()
	_ruler.timeline_scale = timeline_scale
	_ruler.scroll_offset_x = _scroll_offset_x
	_ruler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_ruler)

	# Conteneur horizontal (labels + pistes).
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Colonne des labels de piste.
	_track_labels_container = VBoxContainer.new()
	_track_labels_container.custom_minimum_size.x = LABEL_COLUMN_WIDTH
	_track_labels_container.add_theme_constant_override("separation", 0)
	hbox.add_child(_track_labels_container)

	# Wrapper pour la zone des pistes (clip children).
	var track_wrapper := Control.new()
	track_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_wrapper.clip_contents = true
	hbox.add_child(track_wrapper)

	# TrackArea : nœud enfant direct, grande largeur, positionné via scroll offset.
	_track_area = Control.new()
	_track_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_wrapper.add_child(_track_area)

	# Dessine les fonds de pistes.
	_track_area.draw.connect(_on_track_area_draw)

	_build_track_labels()


func _build_track_labels() -> void:
	# Vide les labels existants.
	for child in _track_labels_container.get_children():
		_track_labels_container.remove_child(child)
		child.queue_free()

	for i in track_count:
		var label := Label.new()
		label.text = "Piste %d" % (i + 1)
		label.custom_minimum_size.y = TRACK_HEIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		label.add_theme_color_override("font_color", COLOR_TRACK_LABEL)
		label.add_theme_constant_override("margin_right", 8)
		_track_labels_container.add_child(label)


func _on_track_area_draw() -> void:
	var w := _track_area.size.x
	for i in track_count:
		var y := i * TRACK_HEIGHT
		var bg_color := COLOR_TRACK_EVEN if i % 2 == 0 else COLOR_TRACK_ODD
		_track_area.draw_rect(Rect2(0, y, w, TRACK_HEIGHT), bg_color)
		# Ligne de séparation en bas de chaque piste.
		_track_area.draw_line(
			Vector2(0, y + TRACK_HEIGHT),
			Vector2(w, y + TRACK_HEIGHT),
			COLOR_TRACK_BORDER,
			1.0,
		)


## Synchronise l'affichage à partir d'un tableau de BoxData.
## Appelé par main.gd chaque fois que la liste des boîtes change.
func sync_from_boxes(boxes: Array) -> void:
	# Retire les clips dont le BoxData n'existe plus.
	var valid_ids: Dictionary = {}
	for box_data: BoxData in boxes:
		valid_ids[box_data.id] = true

	var to_remove: Array[StringName] = []
	for id: StringName in _segments:
		if not valid_ids.has(id):
			to_remove.append(id)
	for id in to_remove:
		var seg: TimelineSegment = _segments[id]
		seg.queue_free()
		_segments.erase(id)

	# Crée ou met à jour les segments.
	for box_data: BoxData in boxes:
		if _segments.has(box_data.id):
			# Mise à jour.
			var seg: TimelineSegment = _segments[box_data.id]
			seg.timeline_scale = timeline_scale
			seg.scroll_offset_x = _scroll_offset_x
			seg.update_geometry()
		else:
			_create_segment(box_data)

	# Met à jour le nombre de pistes si nécessaire.
	var max_track := 0
	for box_data: BoxData in boxes:
		if box_data.track >= max_track:
			max_track = box_data.track + 1
	if max_track > track_count:
		track_count = max_track
		_build_track_labels()

	_track_area.queue_redraw()


func _create_segment(box_data: BoxData) -> void:
	var seg := TimelineSegment.new()
	_track_area.add_child(seg)
	seg.setup(box_data, timeline_scale, _scroll_offset_x)
	# Positionne le segment sur la bonne piste (Y).
	seg.position.y = box_data.track * TRACK_HEIGHT + 1
	# Signaux.
	seg.segment_selected.connect(_on_segment_selected)
	seg.segment_moved.connect(_on_segment_moved)
	seg.segment_resized.connect(_on_segment_resized)
	_segments[box_data.id] = seg


func _on_segment_selected(seg: TimelineSegment) -> void:
	if _selected_segment and _selected_segment != seg:
		_selected_segment.set_selected(false)
	_selected_segment = seg
	seg.set_selected(true)
	segment_selected.emit(seg.box_data)


func _on_segment_moved(seg: TimelineSegment, new_start: float, new_end: float) -> void:
	segment_moved.emit(seg.box_data, new_start, new_end)


func _on_segment_resized(seg: TimelineSegment, new_start: float, new_end: float) -> void:
	segment_resized.emit(seg.box_data, new_start, new_end)


## Sélectionne le segment correspondant à un BoxData (appelé par main.gd pour la sync canvas → timeline).
func select_segment_for_box(box_data: BoxData) -> void:
	if box_data == null:
		deselect_all()
		return
	if _segments.has(box_data.id):
		var seg: TimelineSegment = _segments[box_data.id]
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
		# Repositionne Y sur la piste.
		if seg.box_data:
			seg.position.y = seg.box_data.track * TRACK_HEIGHT + 1

	if _track_area:
		_track_area.queue_redraw()


## Gère le scroll horizontal via la molette.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Scroll horizontal avec Shift + molette ou molette horizontale.
		if mb.pressed:
			var scroll_speed := 30.0
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				if mb.shift_pressed:
					_scroll_offset_x = maxf(_scroll_offset_x - scroll_speed, 0.0)
					_update_all()
					accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if mb.shift_pressed:
					_scroll_offset_x += scroll_speed
					_update_all()
					accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				_scroll_offset_x = maxf(_scroll_offset_x - scroll_speed, 0.0)
				_update_all()
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				_scroll_offset_x += scroll_speed
				_update_all()
				accept_event()
