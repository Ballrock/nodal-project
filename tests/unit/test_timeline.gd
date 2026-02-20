extends GutTest

## Tests d'intégration pour le panneau timeline NLE.

const MainScene := preload("res://main.tscn")

var _main: Control = null


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame


func _get_timeline_panel() -> TimelinePanel:
	return _main.get("timeline_panel") as TimelinePanel


func _get_boxes_by_id() -> Dictionary:
	return _main.get("_boxes_by_id") as Dictionary


# ── Tests ─────────────────────────────────────────────────

func test_timeline_panel_exists() -> void:
	var panel := _get_timeline_panel()
	assert_not_null(panel, "Le TimelinePanel doit exister dans la scène")


func test_segments_created_for_boxes() -> void:
	var panel := _get_timeline_panel()
	var boxes := _get_boxes_by_id()
	# Il y a au minimum la FleetBox + 2 boîtes de test.
	assert_true(boxes.size() >= 3, "Au moins 3 boîtes doivent exister")
	# Vérifie que le panneau timeline a des segments.
	var segments: Dictionary = panel.get("_segments")
	assert_true(segments.size() >= 3, "Au moins 3 segments doivent exister sur la timeline")


func test_segment_has_correct_box_data() -> void:
	var panel := _get_timeline_panel()
	var boxes := _get_boxes_by_id()
	var segments: Dictionary = panel.get("_segments")
	for id: StringName in boxes:
		var box_node: Box = boxes[id]
		assert_true(segments.has(id), "Un segment doit exister pour la boîte '%s'" % box_node.data.title)
		var seg: TimelineSegment = segments[id]
		assert_eq(seg.box_data.id, box_node.data.id, "Le segment doit référencer le bon BoxData")


func test_box_data_start_end_time() -> void:
	var boxes := _get_boxes_by_id()
	# Vérifie que les boîtes de test ont des temps corrects.
	var found_demarrage := false
	for id: StringName in boxes:
		var box_node: Box = boxes[id]
		if box_node.data.title == "Démarrage":
			found_demarrage = true
			assert_eq(box_node.data.start_time, 0.5)
			assert_eq(box_node.data.end_time, 2.5)
			assert_eq(box_node.data.track, 0)
	assert_true(found_demarrage, "La boîte 'Démarrage' doit exister")


func test_selection_sync_canvas_to_timeline() -> void:
	var panel := _get_timeline_panel()
	var boxes := _get_boxes_by_id()

	# Sélectionne une boîte sur le canvas.
	var test_box: Box = null
	for id: StringName in boxes:
		var box_node: Box = boxes[id]
		if box_node.data.title == "Traitement":
			test_box = box_node
			break
	assert_not_null(test_box)

	# Simule la sélection.
	_main.call("_on_box_selected", test_box)
	await get_tree().process_frame

	# Vérifie que le segment correspondant est sélectionné.
	var selected_segment: TimelineSegment = panel.get("_selected_segment")
	assert_not_null(selected_segment, "Un segment doit être sélectionné sur la timeline")
	assert_eq(selected_segment.box_data.id, test_box.data.id)


func test_selection_sync_timeline_to_canvas() -> void:
	var panel := _get_timeline_panel()
	var boxes := _get_boxes_by_id()

	# Trouve la boîte Démarrage.
	var test_box: Box = null
	for id: StringName in boxes:
		var box_node: Box = boxes[id]
		if box_node.data.title == "Démarrage":
			test_box = box_node
			break
	assert_not_null(test_box)

	# Simule la sélection via le signal timeline.
	_main.call("_on_timeline_segment_selected", test_box.data)
	await get_tree().process_frame

	# Vérifie que la boîte est sélectionnée sur le canvas.
	var selected: Box = _main.get("_selected_box")
	assert_not_null(selected, "Une boîte doit être sélectionnée sur le canvas")
	assert_eq(selected.data.id, test_box.data.id)
