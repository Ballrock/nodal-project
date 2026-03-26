extends "res://tests/unit/e2e_test_base.gd"

## Test E2E avec captures d'écran à chaque étape.
## Exécuter SANS --headless pour obtenir les screenshots :
##   $GODOT --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_screenshots.gd


func test_screenshot_workflow_complet() -> void:
	# ── 1. État initial : 3 figures + fleet ──
	await _take_screenshot("01_etat_initial")

	# ── 2. Sélection d'une figure par clic ──
	var figures := _standard_figures()
	var fig_a := figures[0]
	_simulate_click(fig_a, fig_a.global_position + fig_a.size / 2.0)
	await _wait_frames(2)
	await _take_screenshot("02_figure_selectionnee")

	# ── 3. Ajout de slots via le bouton + ──
	var add_btn := _find_add_button(fig_a)
	if add_btn:
		_simulate_button_press(add_btn)
		await _wait_frames(2)
		_simulate_button_press(_find_add_button(fig_a))
		await _wait_frames(2)
	await _take_screenshot("03_slots_ajoutes")

	# ── 4. Création d'un lien entre deux figures ──
	var fig_b := figures[1]
	var out_slot: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_slot: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	var link1 := LinkData.create(fig_a.data.id, out_slot.data.id, fig_b.data.id, in_slot.data.id)
	_links_layer().add_link(out_slot, in_slot, link1)
	_links_layer().refresh()
	await _wait_frames(2)
	await _take_screenshot("04_lien_cree")

	# ── 5. Création d'un second lien (vers la 3e figure) ──
	var fig_c := figures[2]
	var out_slot2: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[1].id)
	var in_slot2: Slot = fig_c.find_slot_by_id(fig_c.data.input_slots[0].id)
	var link2 := LinkData.create(fig_a.data.id, out_slot2.data.id, fig_c.data.id, in_slot2.data.id)
	_links_layer().add_link(out_slot2, in_slot2, link2)
	_links_layer().refresh()
	await _wait_frames(2)
	await _take_screenshot("05_deux_liens")

	# ── 6. Verrouillage du premier lien ──
	link1.is_locked = true
	_links_layer().refresh()
	await _wait_frames(2)
	await _take_screenshot("06_lien_verrouille")

	# ── 7. Sélection d'une autre figure ──
	_simulate_click(fig_b, fig_b.global_position + fig_b.size / 2.0)
	await _wait_frames(2)
	await _take_screenshot("07_autre_figure_selectionnee")

	# ── 8. Ajout d'une nouvelle figure ──
	_main.call("_add_figure")
	await _wait_frames(2)
	await _take_screenshot("08_nouvelle_figure_ajoutee")

	# ── 9. Zoom out sur le canvas ──
	var ws := _workspace()
	for i in 3:
		var zoom_event := InputEventMouseButton.new()
		zoom_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		zoom_event.pressed = true
		zoom_event.global_position = Vector2(640, 360)
		ws.call("_canvas_area_gui_input", zoom_event)
		await _wait_frames(1)
	await _take_screenshot("09_zoom_out")

	# ── 10. Suppression du second lien ──
	_links_layer().remove_link(link2)
	_links_layer().refresh()
	await _wait_frames(2)
	await _take_screenshot("10_lien_supprime")

	assert_eq(_link_count(), 1, "Un seul lien doit rester (le verrouillé)")
	pass_test("Workflow screenshot complet terminé")
