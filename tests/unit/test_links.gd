extends GutTest

## Tests unitaires pour les opérations sur les liens (LinksLayer).
## Vérifie la création, la suppression, les contraintes de connexion,
## les règles de connexion (1 sortie → 1 entrée par boîte cible, remplacement),
## et la cohérence des totaux.

const MainScene := preload("res://main.tscn")
const BoxScene := preload("res://scenes/box.tscn")

var _main: Control = null


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame


func after_each() -> void:
	_main = null


# ── Helpers ───────────────────────────────────────────────

func _links_layer() -> LinksLayer:
	return _main.get("links_layer") as LinksLayer


func _boxes_by_id() -> Dictionary:
	return _main.get("_boxes_by_id") as Dictionary


func _fleet_box() -> Box:
	return _main.get("_fleet_box") as Box


func _link_count() -> int:
	return _links_layer().get("_links").size()


func _get_links() -> Array:
	return _links_layer().get("_links")


## Retourne les boîtes classiques (non-fleet) qui ont des entrées et sorties.
func _get_standard_boxes() -> Array[Box]:
	var result: Array[Box] = []
	for box_id in _boxes_by_id():
		var box: Box = _boxes_by_id()[box_id]
		if not box.is_fleet_box:
			result.append(box)
	return result


## Crée un lien entre deux boîtes via les slots donnés, en utilisant l'API LinksLayer.
## Retourne le LinkData ou null si les slots visuels ne sont pas résolus.
func _create_link_between(
	src_box: Box, src_slot_data: SlotData,
	tgt_box: Box, tgt_slot_data: SlotData
) -> LinkData:
	var src_slot := src_box.find_slot_by_id(src_slot_data.id)
	var tgt_slot := tgt_box.find_slot_by_id(tgt_slot_data.id)
	if src_slot == null or tgt_slot == null:
		return null
	var link := LinkData.create(
		src_box.data.id, src_slot_data.id,
		tgt_box.data.id, tgt_slot_data.id,
	)
	_links_layer().add_link(src_slot, tgt_slot, link)
	return link


## Spawn une boîte de test supplémentaire et l'enregistre dans le main.
func _spawn_extra_box(title: String, pos: Vector2, inputs: int, outputs: int) -> Box:
	return _main.call("_spawn_box", title, pos, inputs, outputs) as Box


# ══════════════════════════════════════════════════════════
# TESTS : ÉTAT INITIAL
# ══════════════════════════════════════════════════════════

func test_no_links_at_startup() -> void:
	assert_eq(_link_count(), 0, "Aucun lien ne doit exister au démarrage")


func test_standard_boxes_exist() -> void:
	var boxes := _get_standard_boxes()
	assert_gte(boxes.size(), 2, "Il doit y avoir au moins 2 boîtes classiques de test")


# ══════════════════════════════════════════════════════════
# TESTS : CRÉATION DE LIEN
# ══════════════════════════════════════════════════════════

func test_create_link_between_two_boxes() -> void:
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	var box_a := boxes[0]
	var box_b := boxes[1]

	await get_tree().process_frame

	var link := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if link:
		assert_eq(_link_count(), 1, "1 lien doit exister après création")
	else:
		pending("Slots visuels non résolus")


func test_link_data_references_are_correct() -> void:
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	var box_a := boxes[0]
	var box_b := boxes[1]

	await get_tree().process_frame

	var link := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if link:
		assert_eq(link.source_box_id, box_a.data.id)
		assert_eq(link.source_slot_id, box_a.data.output_slots[0].id)
		assert_eq(link.target_box_id, box_b.data.id)
		assert_eq(link.target_slot_id, box_b.data.input_slots[0].id)
	else:
		pending("Slots visuels non résolus")


# ══════════════════════════════════════════════════════════
# TESTS : RÈGLE 1 — 1 sortie → max 1 entrée par boîte cible
# ══════════════════════════════════════════════════════════

func test_rule1_output_can_connect_to_different_boxes() -> void:
	# Une sortie PEUT se connecter à des entrées sur des boîtes DIFFÉRENTES
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return

	# Crée une 3e boîte
	await get_tree().process_frame
	var box_c := _spawn_extra_box("BoxC", Vector2(1100, 200), 2, 2)
	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	var link2 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_c, box_c.data.input_slots[0],
	)
	if link1 and link2:
		assert_eq(_link_count(), 2,
			"Une sortie peut se connecter à des entrées sur des boîtes différentes (flotte divisée)")
	else:
		pending("Slots visuels non résolus")


func test_rule1_is_valid_connection_blocks_same_output_same_box() -> void:
	# _is_valid_connection doit REFUSER un 2e lien de la même sortie vers la même boîte
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[1].data.input_slots.size() < 2:
		pending("Box B n'a pas assez d'entrées")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Crée un premier lien output_0(A) → input_0(B)
	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if not link1:
		pending("Slots visuels non résolus")
		return

	# Vérifie que _is_valid_connection refuse un 2e lien output_0(A) → input_1(B)
	var src_slot := box_a.find_slot_by_id(box_a.data.output_slots[0].id)
	var tgt_slot := box_b.find_slot_by_id(box_b.data.input_slots[1].id)
	if src_slot and tgt_slot:
		var valid: bool = _links_layer().call("_is_valid_connection", src_slot, tgt_slot)
		assert_false(valid,
			"_is_valid_connection doit refuser un 2e lien de la même sortie vers la même boîte cible")
	else:
		pending("Slots visuels non résolus")


func test_rule1_different_outputs_to_same_box_allowed() -> void:
	# Deux SORTIES DIFFÉRENTES de la même boîte CAN connect to the même boîte cible
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[0].data.output_slots.size() < 2 or boxes[1].data.input_slots.size() < 2:
		pending("Pas assez de slots")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	var link2 := _create_link_between(
		box_a, box_a.data.output_slots[1],
		box_b, box_b.data.input_slots[1],
	)
	if link1 and link2:
		assert_eq(_link_count(), 2,
			"Deux sorties différentes peuvent se connecter à la même boîte cible")
	else:
		pending("Slots visuels non résolus")


func test_rule1_find_link_from_output_to_box() -> void:
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Pas encore de lien
	var found := _links_layer().find_link_from_output_to_box(
		box_a.data.output_slots[0].id, box_b.data.id)
	assert_null(found, "Pas de lien existant avant création")

	# Crée un lien
	var link := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if link:
		found = _links_layer().find_link_from_output_to_box(
			box_a.data.output_slots[0].id, box_b.data.id)
		assert_not_null(found, "Le lien doit être trouvé après création")
		assert_eq(found.id, link.id)
	else:
		pending("Slots visuels non résolus")


# ══════════════════════════════════════════════════════════
# TESTS : RÈGLE 2 — Remplacement automatique
# ══════════════════════════════════════════════════════════

func test_rule2_replace_link_same_output_same_target_box() -> void:
	# Si output_0(A) → input_0(B) existe et qu'on crée output_0(A) → input_1(B),
	# l'ancien lien est remplacé par le nouveau (via _on_link_replace_requested).
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[1].data.input_slots.size() < 2:
		pending("Box B n'a pas assez d'entrées")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Crée le premier lien
	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if not link1:
		pending("Slots visuels non résolus")
		return

	assert_eq(_link_count(), 1, "1 lien initial")

	# Simule le remplacement via _on_link_replace_requested
	var src_slot := box_a.find_slot_by_id(box_a.data.output_slots[0].id)
	var new_tgt_slot := box_b.find_slot_by_id(box_b.data.input_slots[1].id)
	if src_slot and new_tgt_slot:
		_main.call("_on_link_replace_requested", src_slot, new_tgt_slot, link1)
		assert_eq(_link_count(), 1, "Toujours 1 lien après remplacement")
		# Vérifie que le lien est maintenant vers input_1
		var remaining: LinkData = _get_links()[0]["link_data"]
		assert_eq(remaining.target_slot_id, box_b.data.input_slots[1].id,
			"Le lien doit pointer vers la nouvelle entrée input_1")
		assert_ne(remaining.id, link1.id,
			"Le lien doit être un nouveau LinkData (id différent)")
	else:
		pending("Slots visuels non résolus")


func test_rule2_can_connect_or_replace_allows_replacement() -> void:
	# _can_connect_or_replace doit retourner true même si un lien sortie→même_box existe
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[1].data.input_slots.size() < 2:
		pending("Box B n'a pas assez d'entrées")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if not link1:
		pending("Slots visuels non résolus")
		return

	var src_slot := box_a.find_slot_by_id(box_a.data.output_slots[0].id)
	var tgt_slot := box_b.find_slot_by_id(box_b.data.input_slots[1].id)
	if src_slot and tgt_slot:
		var can: bool = _links_layer().call("_can_connect_or_replace", src_slot, tgt_slot)
		assert_true(can,
			"_can_connect_or_replace doit autoriser le remplacement")
	else:
		pending("Slots visuels non résolus")


func test_rule2_replace_preserves_other_links() -> void:
	# D'autres liens non concernés doivent être préservés
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return

	await get_tree().process_frame
	var box_c := _spawn_extra_box("BoxC", Vector2(1100, 200), 2, 2)
	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Lien output_0(A) → input_0(B)
	var link_ab := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	# Lien output_1(A) → input_0(C)
	if box_a.data.output_slots.size() >= 2:
		var link_ac := _create_link_between(
			box_a, box_a.data.output_slots[1],
			box_c, box_c.data.input_slots[0],
		)
		if link_ab and link_ac:
			assert_eq(_link_count(), 2, "2 liens avant remplacement")

			# Remplace le lien vers B
			if box_b.data.input_slots.size() >= 2:
				var src_slot := box_a.find_slot_by_id(box_a.data.output_slots[0].id)
				var new_tgt := box_b.find_slot_by_id(box_b.data.input_slots[1].id)
				if src_slot and new_tgt:
					_main.call("_on_link_replace_requested", src_slot, new_tgt, link_ab)
					assert_eq(_link_count(), 2,
						"Le remplacement ne doit pas affecter les autres liens")
					# Vérifie que le lien vers C est intact
					var found_ac := false
					for l in _get_links():
						var ld: LinkData = l["link_data"]
						if ld.target_box_id == box_c.data.id:
							found_ac = true
					assert_true(found_ac, "Le lien vers box_c doit être préservé")
			else:
				pass  # Ne peut tester replace sans 2 entrées
		else:
			pending("Slots visuels non résolus")
	else:
		pending("Box A n'a pas assez de sorties")


# ══════════════════════════════════════════════════════════
# TESTS : SUPPRESSION DE LIEN
# ══════════════════════════════════════════════════════════

func test_remove_single_link() -> void:
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return

	await get_tree().process_frame

	var link := _create_link_between(
		boxes[0], boxes[0].data.output_slots[0],
		boxes[1], boxes[1].data.input_slots[0],
	)
	if link:
		_links_layer().remove_link(link)
		assert_eq(_link_count(), 0, "Le lien doit être supprimé")
	else:
		pending("Slots visuels non résolus")


func test_remove_link_by_slot_id() -> void:
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return

	await get_tree().process_frame

	var link := _create_link_between(
		boxes[0], boxes[0].data.output_slots[0],
		boxes[1], boxes[1].data.input_slots[0],
	)
	if link:
		_links_layer().remove_links_for_slot_id(boxes[0].data.output_slots[0].id)
		_links_layer().refresh()
		assert_eq(_link_count(), 0, "Le lien doit être supprimé par slot_id")
	else:
		pending("Slots visuels non résolus")


func test_remove_links_for_slot_only_removes_matching() -> void:
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[0].data.output_slots.size() < 2 or boxes[1].data.input_slots.size() < 2:
		pending("Les boîtes n'ont pas assez de slots pour ce test")
		return

	await get_tree().process_frame

	# Crée 2 liens avec des slots différents
	var link1 := _create_link_between(
		boxes[0], boxes[0].data.output_slots[0],
		boxes[1], boxes[1].data.input_slots[0],
	)
	var link2 := _create_link_between(
		boxes[0], boxes[0].data.output_slots[1],
		boxes[1], boxes[1].data.input_slots[1],
	)
	if link1 and link2:
		assert_eq(_link_count(), 2)
		# Supprime seulement les liens du slot 0
		_links_layer().remove_links_for_slot_id(boxes[0].data.output_slots[0].id)
		assert_eq(_link_count(), 1,
			"Seul le lien du slot 0 doit être supprimé")
		# Vérifie que le lien restant est bien celui du slot 1
		var remaining: LinkData = _get_links()[0]["link_data"]
		assert_eq(remaining.source_slot_id, boxes[0].data.output_slots[1].id)
	else:
		pending("Slots visuels non résolus")


# ══════════════════════════════════════════════════════════
# TESTS : TOTAUX ET COHÉRENCE
# ══════════════════════════════════════════════════════════

func test_total_links_coherent_after_add_remove_cycle() -> void:
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return

	await get_tree().process_frame

	assert_eq(_link_count(), 0, "Départ à 0")

	var link1 := _create_link_between(
		boxes[0], boxes[0].data.output_slots[0],
		boxes[1], boxes[1].data.input_slots[0],
	)
	if not link1:
		pending("Slots visuels non résolus")
		return

	assert_eq(_link_count(), 1, "Après ajout : 1")

	if boxes[0].data.output_slots.size() >= 2 and boxes[1].data.input_slots.size() >= 2:
		var link2 := _create_link_between(
			boxes[0], boxes[0].data.output_slots[1],
			boxes[1], boxes[1].data.input_slots[1],
		)
		if link2:
			assert_eq(_link_count(), 2, "Après 2e ajout : 2")
			_links_layer().remove_link(link1)
			assert_eq(_link_count(), 1, "Après suppression 1er : 1")
			_links_layer().remove_link(link2)
			assert_eq(_link_count(), 0, "Après suppression 2e : 0")


func test_total_fleet_slots_matches_fleet_count() -> void:
	# Vérifie que le nombre de slots de la FleetBox = nombre de flottes
	var fleet_to_slot := _main.get("_fleet_to_slot") as Dictionary

	_main.call("_on_fleet_created", FleetData.create("F1"))
	_main.call("_on_fleet_created", FleetData.create("F2"))
	assert_eq(_fleet_box().data.output_slots.size(), 2)
	assert_eq(fleet_to_slot.size(), 2)

	var fleets := _main.get("fleet_panel").get_fleets() as Array[FleetData]
	# Supprime la première
	_main.call("_on_fleet_deleted", fleets[0])
	assert_eq(_fleet_box().data.output_slots.size(), 1)
	assert_eq(fleet_to_slot.size(), 1)


# ══════════════════════════════════════════════════════════
# TESTS : RÈGLE 3 — Remplacement quand l'input est déjà occupé
# ══════════════════════════════════════════════════════════

func test_rule3_can_connect_or_replace_allows_occupied_input() -> void:
	# _can_connect_or_replace doit autoriser le snap vers un input déjà connecté
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[0].data.output_slots.size() < 2:
		pending("Box A n'a pas assez de sorties")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Connecte output_0(A) → input_0(B)
	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if not link1:
		pending("Slots visuels non résolus")
		return

	# output_1(A) vers input_0(B) — input déjà occupé
	var src_slot := box_a.find_slot_by_id(box_a.data.output_slots[1].id)
	var tgt_slot := box_b.find_slot_by_id(box_b.data.input_slots[0].id)
	if src_slot and tgt_slot:
		var can: bool = _links_layer().call("_can_connect_or_replace", src_slot, tgt_slot)
		assert_true(can,
			"_can_connect_or_replace doit autoriser la connexion vers un input déjà occupé (remplacement)")
	else:
		pending("Slots visuels non résolus")


func test_rule3_is_valid_connection_blocks_occupied_input() -> void:
	# _is_valid_connection (strict) doit toujours REFUSER un input déjà connecté
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[0].data.output_slots.size() < 2:
		pending("Box A n'a pas assez de sorties")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if not link1:
		pending("Slots visuels non résolus")
		return

	var src_slot := box_a.find_slot_by_id(box_a.data.output_slots[1].id)
	var tgt_slot := box_b.find_slot_by_id(box_b.data.input_slots[0].id)
	if src_slot and tgt_slot:
		var valid: bool = _links_layer().call("_is_valid_connection", src_slot, tgt_slot)
		assert_false(valid,
			"_is_valid_connection (strict) doit refuser un input déjà connecté")
	else:
		pending("Slots visuels non résolus")


func test_rule3_replace_link_on_occupied_input() -> void:
	# Si output_0(A) → input_0(B) et qu'on tire output_1(A) → input_0(B),
	# le premier lien est remplacé.
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[0].data.output_slots.size() < 2:
		pending("Box A n'a pas assez de sorties")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Lien initial : output_0(A) → input_0(B)
	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if not link1:
		pending("Slots visuels non résolus")
		return
	assert_eq(_link_count(), 1)

	# Simule le remplacement : output_1(A) → input_0(B) remplace le lien existant
	var src_slot := box_a.find_slot_by_id(box_a.data.output_slots[1].id)
	var tgt_slot := box_b.find_slot_by_id(box_b.data.input_slots[0].id)
	if src_slot and tgt_slot:
		_main.call("_on_link_replace_requested", src_slot, tgt_slot, link1)
		assert_eq(_link_count(), 1, "Toujours 1 lien après remplacement sur input occupé")
		var remaining: LinkData = _get_links()[0]["link_data"]
		assert_eq(remaining.source_slot_id, box_a.data.output_slots[1].id,
			"Le lien doit maintenant provenir de output_1")
		assert_eq(remaining.target_slot_id, box_b.data.input_slots[0].id,
			"Le lien doit toujours pointer vers input_0")
	else:
		pending("Slots visuels non résolus")


func test_rule3_replace_from_different_box() -> void:
	# Si output_0(A) → input_0(B) et qu'on tire output_0(C) → input_0(B),
	# le premier lien est remplacé.
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return

	await get_tree().process_frame
	var box_c := _spawn_extra_box("BoxC", Vector2(1100, 200), 2, 2)
	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Lien initial : output_0(A) → input_0(B)
	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if not link1:
		pending("Slots visuels non résolus")
		return
	assert_eq(_link_count(), 1)

	# Remplacement : output_0(C) → input_0(B)
	var src_slot := box_c.find_slot_by_id(box_c.data.output_slots[0].id)
	var tgt_slot := box_b.find_slot_by_id(box_b.data.input_slots[0].id)
	if src_slot and tgt_slot:
		_main.call("_on_link_replace_requested", src_slot, tgt_slot, link1)
		assert_eq(_link_count(), 1, "Toujours 1 lien après remplacement depuis une autre boîte")
		var remaining: LinkData = _get_links()[0]["link_data"]
		assert_eq(remaining.source_box_id, box_c.data.id,
			"Le lien doit maintenant provenir de box_c")
		assert_eq(remaining.target_slot_id, box_b.data.input_slots[0].id,
			"Le lien doit toujours pointer vers input_0(B)")
	else:
		pending("Slots visuels non résolus")


func test_rule3_find_link_connected_to_input() -> void:
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return

	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Pas de lien → null
	var found := _links_layer().find_link_connected_to_input(box_b.data.input_slots[0].id)
	assert_null(found, "Aucun lien connecté à l'input avant création")

	# Crée un lien
	var link := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	if link:
		found = _links_layer().find_link_connected_to_input(box_b.data.input_slots[0].id)
		assert_not_null(found, "Le lien connecté à l'input doit être trouvé")
		assert_eq(found.id, link.id)
	else:
		pending("Slots visuels non résolus")


func test_rule3_replace_preserves_other_links() -> void:
	# Le remplacement sur un input ne doit pas affecter les liens sur d'autres inputs
	var boxes := _get_standard_boxes()
	if boxes.size() < 2:
		pending("Pas assez de boîtes")
		return
	if boxes[0].data.output_slots.size() < 2 or boxes[1].data.input_slots.size() < 2:
		pending("Pas assez de slots")
		return

	await get_tree().process_frame
	var box_c := _spawn_extra_box("BoxC", Vector2(1100, 200), 2, 2)
	await get_tree().process_frame

	var box_a := boxes[0]
	var box_b := boxes[1]

	# Lien 1 : output_0(A) → input_0(B)
	var link1 := _create_link_between(
		box_a, box_a.data.output_slots[0],
		box_b, box_b.data.input_slots[0],
	)
	# Lien 2 : output_1(A) → input_1(B)
	var link2 := _create_link_between(
		box_a, box_a.data.output_slots[1],
		box_b, box_b.data.input_slots[1],
	)
	if not (link1 and link2):
		pending("Slots visuels non résolus")
		return
	assert_eq(_link_count(), 2)

	# Remplace lien 1 par output_0(C) → input_0(B)
	var src_slot := box_c.find_slot_by_id(box_c.data.output_slots[0].id)
	var tgt_slot := box_b.find_slot_by_id(box_b.data.input_slots[0].id)
	if src_slot and tgt_slot:
		_main.call("_on_link_replace_requested", src_slot, tgt_slot, link1)
		assert_eq(_link_count(), 2, "Toujours 2 liens — seul le premier est remplacé")
		# Vérifie que le lien 2 est intact
		var found_link2 := false
		for l in _get_links():
			var ld: LinkData = l["link_data"]
			if ld.source_slot_id == box_a.data.output_slots[1].id and ld.target_slot_id == box_b.data.input_slots[1].id:
				found_link2 = true
		assert_true(found_link2, "Le lien 2 doit être préservé")
	else:
		pending("Slots visuels non résolus")
