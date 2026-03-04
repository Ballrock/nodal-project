extends GutTest

## Tests d'intégration pour le panneau timeline NLE.

const MainScene := preload("res://ui/main/main.tscn")

var _main: Control = null

func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame

func _get_timeline_panel() -> TimelinePanel:
	return _main.get_node("%TimelinePanel") as TimelinePanel

func _get_figures_by_id() -> Dictionary:
	return _main.get("_figures_by_id") as Dictionary

# ── Tests ─────────────────────────────────────────────────

func test_timeline_panel_exists() -> void:
	var panel := _get_timeline_panel()
	assert_not_null(panel)

func test_segments_created_for_figures() -> void:
	var panel := _get_timeline_panel()
	var figures := _get_figures_by_id()
	assert_true(figures.size() >= 3)
	var segments: Dictionary = panel.get("_segments")
	assert_true(segments.size() >= 3)

func test_segment_has_correct_figure_data() -> void:
	var panel := _get_timeline_panel()
	var figures := _get_figures_by_id()
	var segments: Dictionary = panel.get("_segments")
	for id in figures:
		assert_true(segments.has(id))
		var seg = segments[id]
		assert_eq(seg.figure_data.id, figures[id].data.id)

func test_selection_sync_canvas_to_timeline() -> void:
	var panel := _get_timeline_panel()
	var figures := _get_figures_by_id()
	var test_figure = null
	for id in figures:
		if figures[id].data.title == "Traitement":
			test_figure = figures[id]
			break
	assert_not_null(test_figure)

	_main.call("_on_figure_selected", test_figure)
	await get_tree().process_frame

	var selected_segment = panel.get("_selected_segment")
	assert_not_null(selected_segment)
	assert_eq(selected_segment.figure_data.id, test_figure.data.id)

func test_selection_sync_timeline_to_canvas() -> void:
	var panel := _get_timeline_panel()
	var figures := _get_figures_by_id()
	var test_figure = null
	for id in figures:
		if figures[id].data.title == "Démarrage":
			test_figure = figures[id]
			break
	assert_not_null(test_figure)

	_main.call("_on_timeline_segment_selected", test_figure.data)
	await get_tree().process_frame

	var selected = _main.get("_selected_figure")
	assert_not_null(selected)
	assert_eq(selected.data.id, test_figure.data.id)
