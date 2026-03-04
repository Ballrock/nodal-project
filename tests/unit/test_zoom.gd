extends GutTest

## Tests unitaires pour le zoom canvas et timeline.

const WorkspaceScene := preload("res://features/workspace/workspace.tscn")
const TimelinePanelScene := preload("res://features/timeline/timeline_panel.tscn")
const MainScene := preload("res://ui/main/main.tscn")

var _workspace: Control = null
var _timeline_panel: Control = null
var _main: Control = null

func before_each() -> void:
	_workspace = WorkspaceScene.instantiate()
	add_child_autofree(_workspace)
	
	_timeline_panel = TimelinePanelScene.instantiate()
	add_child_autofree(_timeline_panel)
	
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	
	await get_tree().process_frame

func _get_canvas_zoom() -> float:
	return _workspace.call("get_canvas_zoom")

func _get_canvas_content() -> Control:
	return _workspace.get_node("%CanvasContent") as Control

# ── Tests Zoom Canvas ────────────────────────────────────

func test_canvas_zoom_initial_value() -> void:
	assert_eq(_get_canvas_zoom(), 1.0, "Le zoom canvas démarre à 100%")

func test_canvas_content_scale_matches_zoom() -> void:
	var content := _get_canvas_content()
	assert_not_null(content, "CanvasContent doit exister")
	assert_eq(content.scale, Vector2(1.0, 1.0), "Le scale initial doit être (1,1)")

func test_canvas_zoom_clamp_min() -> void:
	# Applique un facteur de dézoom extrême.
	for i in 50:
		_workspace.call("_apply_canvas_zoom", 0.5, Vector2(400, 300))
	var zoom: float = _get_canvas_zoom()
	assert_true(zoom >= 0.25, "Le zoom ne doit pas descendre sous 25%% (actuel: %s)" % zoom)
	assert_almost_eq(zoom, 0.25, 0.001, "Le zoom minimum doit être 25%%")

func test_canvas_zoom_clamp_max() -> void:
	# Le zoom initial est 1.0 (max). Essaye de zoomer au-delà.
	for i in 20:
		_workspace.call("_apply_canvas_zoom", 2.0, Vector2(400, 300))
	var zoom: float = _get_canvas_zoom()
	assert_true(zoom <= 1.0, "Le zoom ne doit pas dépasser 100%% (actuel: %s)" % zoom)
	assert_almost_eq(zoom, 1.0, 0.001, "Le zoom maximum doit être 100%%")

func test_canvas_zoom_does_not_alter_figure_data_position() -> void:
	# Ajoute une figure
	var fig_data := FigureData.create("A", Vector2(100, 100))
	var figure = _workspace.spawn_figure_from_data(fig_data)
	var pos_before = figure.data.position

	# Applique un dézoom.
	_workspace.call("_apply_canvas_zoom", 0.5, Vector2(400, 300))
	await get_tree().process_frame

	# Les positions logiques (FigureData.position) ne doivent pas changer.
	assert_eq(figure.data.position, pos_before, "La position ne doit pas changer après zoom")

func test_canvas_content_scale_after_zoom() -> void:
	_workspace.call("_apply_canvas_zoom", 0.5, Vector2(400, 300))
	var content := _get_canvas_content()
	var zoom := _get_canvas_zoom()
	assert_almost_eq(content.scale.x, zoom, 0.001, "Le scale X doit correspondre au zoom")
	assert_almost_eq(content.scale.y, zoom, 0.001, "Le scale Y doit correspondre au zoom")

# ── Tests Zoom Timeline ─────────────────────────────────

func test_timeline_zoom_initial_scale() -> void:
	assert_true(_timeline_panel.timeline_scale > 0.0, "L'échelle timeline doit être positive")

func test_timeline_zoom_changes_scale() -> void:
	var original_scale: float = _timeline_panel.timeline_scale
	# Simule un zoom avant.
	_timeline_panel.call("_apply_timeline_zoom", 1.15, 400.0)
	assert_ne(_timeline_panel.timeline_scale, original_scale, "L'échelle doit changer après zoom")

func test_timeline_zoom_clamp_max() -> void:
	# Zoom avant extrême.
	for i in 100:
		_timeline_panel.call("_apply_timeline_zoom", 2.0, 400.0)
	var limits: Vector2 = _timeline_panel.call("get_timeline_scale_limits")
	assert_true(_timeline_panel.timeline_scale <= limits.y + 0.01)

func test_timeline_zoom_clamp_min() -> void:
	# Dézoom extrême.
	for i in 100:
		_timeline_panel.call("_apply_timeline_zoom", 0.5, 400.0)
	var limits: Vector2 = _timeline_panel.call("get_timeline_scale_limits")
	assert_true(_timeline_panel.timeline_scale >= limits.x - 0.01)

# ── Tests Fleet Panel Layout ─────────────────────────────

func test_fleet_panel_is_not_overlay() -> void:
	var fleet_panel = _main.get_node("%FleetPanel")
	assert_not_null(fleet_panel)
	var parent := fleet_panel.get_parent()
	assert_true(parent is HBoxContainer, "Le FleetPanel doit être enfant d'un HBoxContainer")

func test_fleet_panel_does_not_overlap_timeline() -> void:
	var fleet_panel = _main.get_node("%FleetPanel")
	var timeline_panel = _main.get_node("%TimelinePanel")
	assert_not_null(fleet_panel)
	assert_not_null(timeline_panel)
	assert_ne(fleet_panel.get_parent(), timeline_panel.get_parent(), "FleetPanel et TimelinePanel ne doivent pas être dans le même conteneur")
