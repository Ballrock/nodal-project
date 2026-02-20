extends GutTest

## Tests unitaires pour le zoom canvas et timeline.

const MainScene := preload("res://main.tscn")

var _main: Control = null


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame


func _get_canvas_zoom() -> float:
	return _main.call("get_canvas_zoom")


func _get_canvas_content() -> Control:
	return _main.get("canvas_content") as Control


func _get_timeline_panel() -> TimelinePanel:
	return _main.get("timeline_panel") as TimelinePanel


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
		_main.call("_apply_canvas_zoom", 0.5, Vector2(400, 300))
	var zoom: float = _get_canvas_zoom()
	assert_true(zoom >= 0.25, "Le zoom ne doit pas descendre sous 25%% (actuel: %s)" % zoom)
	assert_almost_eq(zoom, 0.25, 0.001, "Le zoom minimum doit être 25%%")


func test_canvas_zoom_clamp_max() -> void:
	# Le zoom initial est 1.0 (max). Essaye de zoomer au-delà.
	for i in 20:
		_main.call("_apply_canvas_zoom", 2.0, Vector2(400, 300))
	var zoom: float = _get_canvas_zoom()
	assert_true(zoom <= 1.0, "Le zoom ne doit pas dépasser 100%% (actuel: %s)" % zoom)
	assert_almost_eq(zoom, 1.0, 0.001, "Le zoom maximum doit être 100%%")


func test_canvas_zoom_does_not_alter_figure_data_position() -> void:
	var figures: Dictionary = _main.get("_figures_by_id")
	# Récupère les positions avant zoom.
	var positions_before: Dictionary = {}
	for id: StringName in figures:
		var figure: Figure = figures[id]
		positions_before[id] = figure.data.position

	# Applique un dézoom.
	_main.call("_apply_canvas_zoom", 0.5, Vector2(400, 300))
	await get_tree().process_frame

	# Les positions logiques (FigureData.position) ne doivent pas changer.
	for id: StringName in figures:
		var figure: Figure = figures[id]
		assert_eq(figure.data.position, positions_before[id],
			"La position de '%s' ne doit pas changer après zoom" % figure.data.title)


func test_canvas_content_scale_after_zoom() -> void:
	_main.call("_apply_canvas_zoom", 0.5, Vector2(400, 300))
	var content := _get_canvas_content()
	var zoom := _get_canvas_zoom()
	assert_almost_eq(content.scale.x, zoom, 0.001, "Le scale X doit correspondre au zoom")
	assert_almost_eq(content.scale.y, zoom, 0.001, "Le scale Y doit correspondre au zoom")


# ── Tests Zoom Timeline ─────────────────────────────────

func test_timeline_zoom_initial_scale() -> void:
	var panel := _get_timeline_panel()
	assert_true(panel.timeline_scale > 0.0, "L'échelle timeline doit être positive")


func test_timeline_zoom_changes_scale() -> void:
	var panel := _get_timeline_panel()
	var original_scale := panel.timeline_scale
	# Simule un zoom avant.
	panel.call("_apply_timeline_zoom", 1.15, 400.0)
	assert_ne(panel.timeline_scale, original_scale, "L'échelle doit changer après zoom")


func test_timeline_zoom_clamp_max() -> void:
	var panel := _get_timeline_panel()
	# Zoom avant extrême.
	for i in 100:
		panel.call("_apply_timeline_zoom", 2.0, 400.0)
	var limits: Vector2 = panel.call("get_timeline_scale_limits")
	assert_true(panel.timeline_scale <= limits.y + 0.01,
		"L'échelle ne doit pas dépasser le max (~1min visible). Actuel: %s, Max: %s" % [panel.timeline_scale, limits.y])


func test_timeline_zoom_clamp_min() -> void:
	var panel := _get_timeline_panel()
	# Dézoom extrême.
	for i in 100:
		panel.call("_apply_timeline_zoom", 0.5, 400.0)
	var limits: Vector2 = panel.call("get_timeline_scale_limits")
	assert_true(panel.timeline_scale >= limits.x - 0.01,
		"L'échelle ne doit pas descendre sous le min (~1h visible). Actuel: %s, Min: %s" % [panel.timeline_scale, limits.x])


func test_timeline_scale_limits_coherent() -> void:
	var panel := _get_timeline_panel()
	var limits: Vector2 = panel.call("get_timeline_scale_limits")
	assert_true(limits.x > 0.0, "La limite min doit être positive")
	assert_true(limits.y > limits.x, "La limite max doit être supérieure à la limite min")


# ── Tests Fleet Panel Layout ─────────────────────────────

func test_fleet_panel_is_not_overlay() -> void:
	var fleet_panel: FleetPanel = _main.get("fleet_panel")
	assert_not_null(fleet_panel)
	# Le FleetPanel ne doit plus être enfant direct de Main (overlay).
	# Il doit être dans le CanvasHBox (HBoxContainer).
	var parent := fleet_panel.get_parent()
	assert_true(parent is HBoxContainer,
		"Le FleetPanel doit être enfant d'un HBoxContainer, pas un overlay. Parent actuel: %s" % parent.get_class())


func test_fleet_panel_does_not_overlap_timeline() -> void:
	var fleet_panel: FleetPanel = _main.get("fleet_panel")
	var timeline_panel := _get_timeline_panel()
	assert_not_null(fleet_panel)
	assert_not_null(timeline_panel)
	# Le FleetPanel et la TimelinePanel ne doivent pas partager le même parent direct.
	# FleetPanel est dans CanvasHBox, TimelinePanel est dans VSplitContainer.
	assert_ne(fleet_panel.get_parent(), timeline_panel.get_parent(),
		"FleetPanel et TimelinePanel ne doivent pas être dans le même conteneur")
