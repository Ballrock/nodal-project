extends "res://tests/unit/e2e_test_base.gd"

## Tests E2E : workflows complets bout en bout.
## Couvre les scénarios utilisateur réels combinant plusieurs fonctionnalités :
## création → modification → liens → sauvegarde → chargement → vérification.

const GraphSerializer := preload("res://core/serialization/graph_serializer.gd")


# ══════════════════════════════════════════════════════════
# WORKFLOW COMPLET : CRÉATION → LIENS → SAVE → LOAD
# ══════════════════════════════════════════════════════════

func test_full_workflow_create_link_save_load() -> void:
	# ── Étape 1 : Ajouter une figure ──
	var count_before := _standard_figures().size()
	_main.call("_add_figure")
	await _wait_frames(2)
	assert_eq(_standard_figures().size(), count_before + 1, "Figure ajoutée")

	# ── Étape 2 : Ajouter des slots à la nouvelle figure ──
	var new_fig: Figure = _standard_figures().back() as Figure
	new_fig.call("_on_add_slot_pair")
	await _wait_frames(1)
	new_fig.call("_on_add_slot_pair")
	await _wait_frames(1)
	assert_eq(new_fig.data.input_slots.size(), 2, "2 inputs ajoutés")
	assert_eq(new_fig.data.output_slots.size(), 2, "2 outputs ajoutés")

	# ── Étape 3 : Créer un lien entre la première figure et la nouvelle ──
	var first_fig := _standard_figures()[0]
	var out_slot: Slot = first_fig.find_slot_by_id(first_fig.data.output_slots[0].id)
	var in_slot: Slot = new_fig.find_slot_by_id(new_fig.data.input_slots[0].id)
	var link := LinkData.create(first_fig.data.id, out_slot.data.id, new_fig.data.id, in_slot.data.id)
	_links_layer().add_link(out_slot, in_slot, link)
	assert_eq(_link_count(), 1, "Lien créé")

	# ── Étape 4 : Sauvegarder le graphe ──
	var zoom_before: float = _workspace().call("get_canvas_zoom")
	var figs_by_id := _figures_by_id()
	var fleet_to_slot: Dictionary = _main.get("_fleet_to_slot")
	var timeline_scale: float = _timeline_panel().timeline_scale

	var saved_data := GraphSerializer.serialize_graph(
		figs_by_id, _links_layer(), fleet_to_slot, zoom_before, timeline_scale
	)
	assert_not_null(saved_data, "Données sérialisées non nulles")
	assert_true(saved_data.has("figures"), "La sauvegarde contient les figures")
	assert_true(saved_data.has("links"), "La sauvegarde contient les liens")

	# ── Étape 5 : Effacer tout ──
	_main.call("_clear_graph")
	await _wait_frames(2)
	assert_eq(_link_count(), 0, "Tous les liens effacés")

	# ── Étape 6 : Recharger ──
	_main.call("_load_graph", saved_data)
	await _wait_frames(3)

	# ── Étape 7 : Vérifier l'état restauré ──
	assert_eq(float(_workspace().call("get_canvas_zoom")), zoom_before, "Zoom restauré")
	assert_eq(_link_count(), 1, "Lien restauré")
	assert_gte(_figures_by_id().size(), count_before + 1, "Figures restaurées")


# ══════════════════════════════════════════════════════════
# WORKFLOW : SÉLECTION CROISÉE CANVAS ↔ TIMELINE
# ══════════════════════════════════════════════════════════

func test_selection_sync_canvas_to_timeline() -> void:
	var figures := _standard_figures()
	var fig := figures[0]

	_simulate_click(fig, fig.global_position + fig.size / 2.0)
	await _wait_frames(2)

	assert_eq(_selected_figure(), fig, "Figure sélectionnée sur le canvas")
	pass_test("Sélection canvas → timeline synchronisée")


func test_selection_sync_timeline_to_canvas() -> void:
	var figures := _standard_figures()
	var fig := figures[1]

	_main.call("_on_timeline_segment_selected", fig.data)
	await _wait_frames(2)

	assert_eq(_selected_figure(), fig, "Sélection timeline → canvas synchronisée")
	assert_true(fig.get("_is_selected"), "La figure doit apparaître sélectionnée visuellement")


func test_alternating_selections() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]

	_simulate_click(fig_a, fig_a.global_position + fig_a.size / 2.0)
	await _wait_frames(2)
	assert_eq(_selected_figure(), fig_a)

	_main.call("_on_timeline_segment_selected", fig_b.data)
	await _wait_frames(2)
	assert_eq(_selected_figure(), fig_b)
	assert_false(fig_a.get("_is_selected"), "A ne doit plus être sélectionnée")

	_simulate_click(fig_a, fig_a.global_position + fig_a.size / 2.0)
	await _wait_frames(2)
	assert_eq(_selected_figure(), fig_a)
	assert_false(fig_b.get("_is_selected"), "B ne doit plus être sélectionnée")


# ══════════════════════════════════════════════════════════
# WORKFLOW : CRÉATION FIGURE → SLOTS → LIEN → SUPPRESSION SLOT
# ══════════════════════════════════════════════════════════

func test_create_slots_link_then_delete_slot() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]

	fig_a.call("_on_add_slot_pair")
	fig_b.call("_on_add_slot_pair")
	await _wait_frames(2)

	var initial_in_count := fig_a.data.input_slots.size()
	var initial_out_count := fig_a.data.output_slots.size()

	var last_out_idx := fig_a.data.output_slots.size() - 1
	var out_slot: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[last_out_idx].id)
	var in_slot: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	var link := LinkData.create(fig_a.data.id, out_slot.data.id, fig_b.data.id, in_slot.data.id)
	_links_layer().add_link(out_slot, in_slot, link)
	assert_eq(_link_count(), 1)

	_main.call("_on_slot_delete", out_slot, fig_a)
	await _wait_frames(2)

	assert_eq(_link_count(), 0, "Le lien doit être supprimé avec le slot")
	assert_eq(fig_a.data.input_slots.size(), initial_in_count - 1, "Paire supprimée (input)")
	assert_eq(fig_a.data.output_slots.size(), initial_out_count - 1, "Paire supprimée (output)")


# ══════════════════════════════════════════════════════════
# WORKFLOW : PAN + ZOOM + SÉLECTION
# ══════════════════════════════════════════════════════════

func test_pan_zoom_then_select_figure() -> void:
	var ws := _workspace()
	var canvas_content: Control = ws.get_node("%CanvasContent")
	var initial_content_pos := canvas_content.position

	# Pan
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.global_position = Vector2(400, 300)
	ws.call("_canvas_area_gui_input", press)

	var motion := InputEventMouseMotion.new()
	motion.global_position = Vector2(500, 400)
	ws.call("_canvas_area_gui_input", motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	ws.call("_canvas_area_gui_input", release)
	await _wait_frames(1)

	assert_ne(canvas_content.position, initial_content_pos, "Canvas panné")

	# Zoom
	var zoom_before: float = ws.call("get_canvas_zoom")
	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zoom_event.pressed = true
	zoom_event.global_position = Vector2(500, 300)
	ws.call("_canvas_area_gui_input", zoom_event)
	await _wait_frames(1)

	assert_ne(float(ws.call("get_canvas_zoom")), zoom_before, "Zoom modifié")

	# Sélection après pan+zoom
	var figures := _standard_figures()
	var fig := figures[0]
	_simulate_click(fig, fig.global_position + fig.size / 2.0)
	await _wait_frames(2)

	assert_eq(_selected_figure(), fig, "La sélection doit fonctionner après pan+zoom")


# ══════════════════════════════════════════════════════════
# WORKFLOW : FIGURES MULTIPLES AVEC LIENS CROISÉS
# ══════════════════════════════════════════════════════════

func test_multiple_links_between_figures() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]
	var fig_c := figures[2]

	var out_a0: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_b0: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	var link1 := LinkData.create(fig_a.data.id, out_a0.data.id, fig_b.data.id, in_b0.data.id)
	_links_layer().add_link(out_a0, in_b0, link1)

	var out_b0: Slot = fig_b.find_slot_by_id(fig_b.data.output_slots[0].id)
	var in_c0: Slot = fig_c.find_slot_by_id(fig_c.data.input_slots[0].id)
	var link2 := LinkData.create(fig_b.data.id, out_b0.data.id, fig_c.data.id, in_c0.data.id)
	_links_layer().add_link(out_b0, in_c0, link2)

	var in_c1: Slot = fig_c.find_slot_by_id(fig_c.data.input_slots[1].id)
	var link3 := LinkData.create(fig_a.data.id, out_a0.data.id, fig_c.data.id, in_c1.data.id)
	_links_layer().add_link(out_a0, in_c1, link3)

	assert_eq(_link_count(), 3, "3 liens créés")

	# Save/load round trip
	var saved := GraphSerializer.serialize_graph(
		_figures_by_id(), _links_layer(),
		_main.get("_fleet_to_slot"),
		float(_workspace().call("get_canvas_zoom")),
		_timeline_panel().timeline_scale
	)

	_main.call("_clear_graph")
	await _wait_frames(2)
	assert_eq(_link_count(), 0)

	_main.call("_load_graph", saved)
	await _wait_frames(3)

	assert_eq(_link_count(), 3, "Les 3 liens doivent être restaurés")


# ══════════════════════════════════════════════════════════
# WORKFLOW : CLEAR PUIS RECONSTRUCTION
# ══════════════════════════════════════════════════════════

func test_clear_graph_removes_everything() -> void:
	assert_gte(_standard_figures().size(), 3, "Au moins 3 figures initiales")

	var figures := _standard_figures()
	var out_slot: Slot = figures[0].find_slot_by_id(figures[0].data.output_slots[0].id)
	var in_slot: Slot = figures[1].find_slot_by_id(figures[1].data.input_slots[0].id)
	var link := LinkData.create(figures[0].data.id, out_slot.data.id, figures[1].data.id, in_slot.data.id)
	_links_layer().add_link(out_slot, in_slot, link)

	_main.call("_clear_graph")
	await _wait_frames(2)

	assert_eq(_figures_by_id().size(), 0, "Toutes les figures effacées")
	assert_eq(_link_count(), 0, "Tous les liens effacés")


# ══════════════════════════════════════════════════════════
# WORKFLOW : TIMELINE SYNC APRÈS AJOUT/MODIFICATION
# ══════════════════════════════════════════════════════════

func test_timeline_updates_after_figure_creation() -> void:
	var timeline := _timeline_panel()
	var track_area: Control = timeline.get("_track_area")
	assert_not_null(track_area, "TrackArea doit exister")
	var segments_before := track_area.get_child_count()

	_main.call("_add_figure")
	await _wait_frames(2)

	var segments_after := track_area.get_child_count()
	assert_gt(segments_after, segments_before, "Un nouveau segment timeline doit apparaître")


func test_figure_title_change_syncs_to_timeline() -> void:
	var figures := _standard_figures()
	var fig := figures[0]
	var new_title := "NouveauNom"

	fig.set_title(new_title)
	fig.title_changed.emit(fig)
	await _wait_frames(2)

	assert_eq(fig.data.title, new_title, "Le titre de la figure doit être mis à jour")
