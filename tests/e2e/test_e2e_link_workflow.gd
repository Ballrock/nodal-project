extends "res://tests/unit/e2e_test_base.gd"

## Tests E2E : workflow complet de création et gestion des câbles (liens).
## Simule de vrais clics sur les slots pour créer des liens,
## puis vérifie la suppression et les règles de connexion.


# ══════════════════════════════════════════════════════════
# CRÉATION DE LIENS VIA CLIC SUR SLOTS
# ══════════════════════════════════════════════════════════

func test_link_creation_via_slot_drag() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]
	assert_eq(_link_count(), 0, "Pas de liens au démarrage")

	var out_slot: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_slot: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	assert_not_null(out_slot, "Slot output doit exister")
	assert_not_null(in_slot, "Slot input doit exister")

	_simulate_link_drag(out_slot, in_slot)
	await _wait_frames(3)

	assert_eq(_link_count(), 1, "Un lien doit avoir été créé")
	assert_true(out_slot.get("_is_connected"), "Slot output doit être connecté")
	assert_true(in_slot.get("_is_connected"), "Slot input doit être connecté")


func test_link_creation_from_input_to_output() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]

	var in_slot: Slot = fig_a.find_slot_by_id(fig_a.data.input_slots[0].id)
	var out_slot: Slot = fig_b.find_slot_by_id(fig_b.data.output_slots[0].id)

	_simulate_link_drag(in_slot, out_slot)
	await _wait_frames(3)

	assert_eq(_link_count(), 1, "Le lien input→output doit fonctionner (inversé automatiquement)")


# ══════════════════════════════════════════════════════════
# RÈGLES DE CONNEXION
# ══════════════════════════════════════════════════════════

func test_no_self_loop() -> void:
	var figures := _standard_figures()
	var fig := figures[0]

	var out_slot: Slot = fig.find_slot_by_id(fig.data.output_slots[0].id)
	var in_slot: Slot = fig.find_slot_by_id(fig.data.input_slots[0].id)

	_simulate_link_drag(out_slot, in_slot)
	await _wait_frames(3)

	assert_eq(_link_count(), 0, "Pas de self-loop autorisé")


func test_output_can_connect_to_multiple_figures() -> void:
	var figures := _standard_figures()
	assert_gte(figures.size(), 3, "Au moins 3 figures standards attendues")
	var fig_a := figures[0]
	var fig_b := figures[1]
	var fig_c := figures[2]

	var out_a: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_b: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	_simulate_link_drag(out_a, in_b)
	await _wait_frames(3)
	assert_eq(_link_count(), 1)

	var in_c: Slot = fig_c.find_slot_by_id(fig_c.data.input_slots[0].id)
	_simulate_link_drag(out_a, in_c)
	await _wait_frames(3)
	assert_eq(_link_count(), 2, "Un output peut se connecter à plusieurs figures différentes")


func test_replace_link_same_output_same_target_figure() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]

	if fig_b.data.input_slots.size() < 2:
		fig_b.call("_on_add_slot_pair")
		await _wait_frames(2)

	var out_a: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_b0: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	_simulate_link_drag(out_a, in_b0)
	await _wait_frames(3)
	assert_eq(_link_count(), 1)

	var in_b1: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[1].id)
	_simulate_link_drag(out_a, in_b1)
	await _wait_frames(3)
	assert_eq(_link_count(), 1, "Le lien doit être remplacé, pas dupliqué")

	var remaining := _links_layer().get_all_link_data()[0]
	assert_eq(remaining.target_slot_id, fig_b.data.input_slots[1].id)


# ══════════════════════════════════════════════════════════
# SUPPRESSION DE LIENS
# ══════════════════════════════════════════════════════════

func test_remove_link_via_slot_context() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]

	var out_slot: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_slot: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	var link := LinkData.create(fig_a.data.id, out_slot.data.id, fig_b.data.id, in_slot.data.id)
	_links_layer().add_link(out_slot, in_slot, link)
	assert_eq(_link_count(), 1)

	_main.call("_on_slot_remove_link", out_slot, fig_a)
	await _wait_frames(2)

	assert_eq(_link_count(), 0, "Le lien doit être supprimé")
	assert_false(out_slot.get("_is_connected"), "Le slot output ne doit plus être connecté")


func test_slot_deletion_removes_associated_links() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]

	var out_slot: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_slot: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	var link := LinkData.create(fig_a.data.id, out_slot.data.id, fig_b.data.id, in_slot.data.id)
	_links_layer().add_link(out_slot, in_slot, link)
	assert_eq(_link_count(), 1)

	_main.call("_on_slot_delete", out_slot, fig_a)
	await _wait_frames(2)

	assert_eq(_link_count(), 0, "Le lien doit être supprimé avec le slot")


# ══════════════════════════════════════════════════════════
# VERROUILLAGE DE LIENS
# ══════════════════════════════════════════════════════════

func test_lock_unlock_link() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]

	var out_slot: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_slot: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)
	var link := LinkData.create(fig_a.data.id, out_slot.data.id, fig_b.data.id, in_slot.data.id)
	_links_layer().add_link(out_slot, in_slot, link)

	link.is_locked = true
	assert_true(link.is_locked, "Le lien doit être verrouillé")

	_links_layer().open_context_menu_for_link(link, Vector2(100, 100))
	await _wait_frames(1)

	var popup: PopupMenu = _links_layer().get("_ctx_popup")
	if popup and is_instance_valid(popup):
		var delete_idx := popup.get_item_index(2)
		assert_true(popup.is_item_disabled(delete_idx), "Delete doit être désactivé quand verrouillé")

	assert_eq(_link_count(), 1, "Le lien verrouillé ne doit pas être supprimé")

	link.is_locked = false
	assert_false(link.is_locked, "Le lien doit être déverrouillé")


# ══════════════════════════════════════════════════════════
# ÉTAT VISUEL DES SLOTS CONNECTÉS
# ══════════════════════════════════════════════════════════

func test_slots_show_connected_state_after_link() -> void:
	var figures := _standard_figures()
	var fig_a := figures[0]
	var fig_b := figures[1]

	var out_slot: Slot = fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	var in_slot: Slot = fig_b.find_slot_by_id(fig_b.data.input_slots[0].id)

	assert_false(out_slot.get("_is_connected"), "Avant lien : output non connecté")
	assert_false(in_slot.get("_is_connected"), "Avant lien : input non connecté")

	var link := LinkData.create(fig_a.data.id, out_slot.data.id, fig_b.data.id, in_slot.data.id)
	_links_layer().add_link(out_slot, in_slot, link)

	assert_true(out_slot.get("_is_connected"), "Après lien : output connecté")
	assert_true(in_slot.get("_is_connected"), "Après lien : input connecté")

	_links_layer().remove_link(link)
	await _wait_frames(1)

	assert_false(out_slot.get("_is_connected"), "Après suppression : output non connecté")
	assert_false(in_slot.get("_is_connected"), "Après suppression : input non connecté")
