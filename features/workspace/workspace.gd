extends Control

## Gère le canvas, le zoom, le pan et les figures.

signal figure_selected(figure: Figure)
signal link_created(source_slot: Slot, target_slot: Slot)
signal link_replace_requested(source_slot: Slot, target_slot: Slot, old_link: LinkData)

const FigureScene := preload("res://features/workspace/components/figure.tscn")

@onready var canvas_area: Control = %CanvasArea
@onready var canvas_content: Control = %CanvasContent
@onready var figure_container: Control = %FigureContainer
@onready var links_layer: LinksLayer = %LinksLayer
@onready var minimap: Control = %Minimap

## Workspace Dynamique
const DEFAULT_WORKSPACE_SIZE := Vector2(3000, 2000)
const WORKSPACE_MARGIN := 200.0
var _workspace_rect: Rect2 = Rect2(-DEFAULT_WORKSPACE_SIZE/2.0, DEFAULT_WORKSPACE_SIZE)

## Zoom & Pan
const CANVAS_ZOOM_MIN := 0.25
const CANVAS_ZOOM_MAX := 1.0
const CANVAS_ZOOM_STEP := 1.1
var _canvas_zoom: float = 1.0

var _canvas_panning: bool = false
var _canvas_pan_start: Vector2 = Vector2.ZERO
var _canvas_content_start: Vector2 = Vector2.ZERO

var _refresh_links := false

func _ready() -> void:
	canvas_area.gui_input.connect(_canvas_area_gui_input)
	links_layer.link_created.connect(func(s, t): link_created.emit(s, t))
	links_layer.link_replace_requested.connect(func(s, t, o): link_replace_requested.emit(s, t, o))

func _process(_delta: float) -> void:
	if _refresh_links:
		links_layer.refresh()
	_update_workspace_rect()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			deselect_all()

func _canvas_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
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
	var mouse_local := canvas_area.get_global_transform().affine_inverse() * mouse_global
	var content_pos_before := (mouse_local - canvas_content.position) / old_zoom
	canvas_content.scale = Vector2(_canvas_zoom, _canvas_zoom)
	canvas_content.position = mouse_local - content_pos_before * _canvas_zoom
	links_layer.queue_redraw()

func get_canvas_zoom() -> float:
	return _canvas_zoom

func set_canvas_zoom(value: float) -> void:
	_canvas_zoom = value
	canvas_content.scale = Vector2(_canvas_zoom, _canvas_zoom)
	links_layer.queue_redraw()

func center_view() -> void:
	await get_tree().process_frame
	canvas_content.position = canvas_area.size / 2.0
	links_layer.queue_redraw()

func deselect_all() -> void:
	figure_selected.emit(null)

func spawn_figure_from_data(figure_data: FigureData, is_fleet_figure: bool = false) -> Figure:
	var figure_node: Figure = FigureScene.instantiate()
	figure_container.add_child(figure_node)
	figure_node.is_fleet_figure = is_fleet_figure
	figure_node.setup(figure_data)
	figure_node.selected.connect(func(f): figure_selected.emit(f))
	figure_node.drag_started.connect(func(_b): _refresh_links = true)
	figure_node.drag_ended.connect(func(_b): 
		_refresh_links = false
		links_layer.refresh()
	)
	links_layer.register_figure(figure_node)
	return figure_node

func clear() -> void:
	for child in figure_container.get_children():
		child.queue_free()
	links_layer.clear_all_links()
	links_layer.clear_figures()

func get_workspace_rect() -> Rect2:
	return _workspace_rect

func _update_workspace_rect() -> void:
	var figures_rect := Rect2()
	var children = figure_container.get_children()
	if children.is_empty():
		_workspace_rect = Rect2(-DEFAULT_WORKSPACE_SIZE / 2.0, DEFAULT_WORKSPACE_SIZE)
		return
		
	var first := true
	for figure in children:
		var fig_rect := Rect2(figure.position, figure.size if figure.size != Vector2.ZERO else Vector2(200, 100))
		if first:
			figures_rect = fig_rect
			first = false
		else:
			figures_rect = figures_rect.merge(fig_rect)
	
	var min_rect := Rect2(-DEFAULT_WORKSPACE_SIZE / 2.0, DEFAULT_WORKSPACE_SIZE)
	_workspace_rect = figures_rect.grow(WORKSPACE_MARGIN).merge(min_rect)
