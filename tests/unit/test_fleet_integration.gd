extends GutTest

## Tests d'intégration : ajout/suppression de flottes, mise à jour de la FleetFigure,
## nettoyage des liens associés.
##
## Instancie la scène principale pour tester l'orchestration complète.

const MainScene := preload("res://main.tscn")


var _main: Control = null


func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	# Attendre un frame pour que tous les @onready soient prêts
	await get_tree().process_frame


func after_each() -> void:
	_main = null


# ── Helpers ───────────────────────────────────────────────

## Accès au script principal typé.
func _get_main() -> Node:
	return _main


func _fleet_figure() -> Figure:
	return _main.get("_fleet_figure") as Figure


func _fleet_to_slot() -> Dictionary:
	return _main.get("_fleet_to_slot") as Dictionary


func _links_layer() -> LinksLayer:
	return _main.get("links_layer") as LinksLayer


func _fleet_panel() -> FleetPanel:
	return _main.get("fleet_panel") as FleetPanel


func _figures_by_id() -> Dictionary:
	return _main.get("_figures_by_id") as Dictionary


## Simule la création d'une flotte (comme si le FleetDialog émettait le signal).
func _create_fleet(p_name: String, p_type: int = FleetData.DroneType.DRONE_RIFF, p_count: int = 1) -> FleetData:
	var fleet := FleetData.create(p_name, p_type, p_count)
	# Appeler le callback comme le ferait le signal fleet_created
	_main.call("_on_fleet_created", fleet)
	return fleet


## Simule la suppression d'une flotte.
func _delete_fleet(fleet: FleetData) -> void:
	_main.call("_on_fleet_deleted", fleet)


## Simule la mise à jour d'une flotte.
func _update_fleet(fleet: FleetData) -> void:
	_main.call("_on_fleet_updated", fleet)


## Retourne le nombre de liens dans le LinksLayer.
func _link_count() -> int:
	return _links_layer().get("_links").size()


## Retourne le tableau interne des liens.
func _get_links() -> Array:
	return _links_layer().get("_links")


# ══════════════════════════════════════════════════════════
# TESTS : FLEET BOX INITIALE
# ══════════════════════════════════════════════════════════

func test_fleet_figure_exists_at_startup() -> void:
	assert_not_null(_fleet_figure(), "La FleetFigure doit exister au démarrage")


func test_fleet_figure_is_marked_as_fleet() -> void:
	assert_true(_fleet_figure().is_fleet_figure, "La FleetFigure doit être marquée is_fleet_figure")


func test_fleet_figure_has_no_inputs() -> void:
	assert_eq(_fleet_figure().data.input_slots.size(), 0,
		"La FleetFigure ne doit pas avoir d'entrées")


func test_fleet_figure_has_no_outputs_initially() -> void:
	assert_eq(_fleet_figure().data.output_slots.size(), 0,
		"La FleetFigure ne doit avoir aucune sortie au démarrage (pas de flotte)")


func test_fleet_figure_has_green_color() -> void:
	var expected_color := Color(0.33, 0.75, 0.42)
	assert_eq(_fleet_figure().data.color, expected_color,
		"La FleetFigure doit avoir la couleur verte définie dans SPEC §14.3")


# ══════════════════════════════════════════════════════════
# TESTS : AJOUT DE FLOTTE
# ══════════════════════════════════════════════════════════

func test_add_fleet_creates_output_slot() -> void:
	_create_fleet("Alpha")
	assert_eq(_fleet_figure().data.output_slots.size(), 1,
		"Ajouter une flotte doit créer 1 slot de sortie sur la FleetFigure")


func test_add_fleet_slot_has_fleet_name_as_label() -> void:
	_create_fleet("Bravo")
	assert_eq(_fleet_figure().data.output_slots[0].label, "Bravo",
		"Le slot doit porter le nom de la flotte")


func test_add_fleet_slot_direction_is_output() -> void:
	_create_fleet("Charlie")
	assert_eq(_fleet_figure().data.output_slots[0].direction, SlotData.Direction.SLOT_OUTPUT,
		"Le slot de la FleetFigure doit être une sortie")


func test_add_multiple_fleets_creates_multiple_slots() -> void:
	_create_fleet("Alpha")
	_create_fleet("Bravo")
	_create_fleet("Charlie")
	assert_eq(_fleet_figure().data.output_slots.size(), 3,
		"3 flottes → 3 slots de sortie")


func test_add_fleet_registers_in_fleet_to_slot_map() -> void:
	var fleet := _create_fleet("Delta")
	assert_true(_fleet_to_slot().has(fleet.id),
		"Le mapping _fleet_to_slot doit contenir l'id de la flotte")


func test_add_fleet_updates_fleet_panel() -> void:
	_create_fleet("Echo")
	var panel_fleets := _fleet_panel().get_fleets()
	assert_eq(panel_fleets.size(), 1, "Le volet doit contenir 1 flotte")
	assert_eq(panel_fleets[0].name, "Echo")


func test_add_fleet_slots_have_sequential_indices() -> void:
	_create_fleet("A")
	_create_fleet("B")
	_create_fleet("C")
	for i in _fleet_figure().data.output_slots.size():
		assert_eq(_fleet_figure().data.output_slots[i].index, i,
			"Le slot %d doit avoir l'index %d" % [i, i])


# ══════════════════════════════════════════════════════════
# TESTS : MISE À JOUR DE FLOTTE
# ══════════════════════════════════════════════════════════

func test_update_fleet_renames_slot_label() -> void:
	var fleet := _create_fleet("OldName")
	fleet.name = "NewName"
	_update_fleet(fleet)
	var slot_data: SlotData = _fleet_to_slot()[fleet.id]
	assert_eq(slot_data.label, "NewName",
		"Le label du slot doit être mis à jour après renommage de la flotte")


func test_update_fleet_preserves_slot_count() -> void:
	_create_fleet("A")
	var fleet_b := _create_fleet("B")
	fleet_b.name = "B_renamed"
	_update_fleet(fleet_b)
	assert_eq(_fleet_figure().data.output_slots.size(), 2,
		"Le nombre de slots ne doit pas changer lors d'une mise à jour")


# ══════════════════════════════════════════════════════════
# TESTS : SUPPRESSION DE FLOTTE
# ══════════════════════════════════════════════════════════

func test_remove_fleet_removes_slot() -> void:
	var fleet := _create_fleet("ToRemove")
	assert_eq(_fleet_figure().data.output_slots.size(), 1)
	_delete_fleet(fleet)
	assert_eq(_fleet_figure().data.output_slots.size(), 0,
		"Supprimer la flotte doit retirer son slot de la FleetFigure")


func test_remove_fleet_clears_mapping() -> void:
	var fleet := _create_fleet("Mapped")
	_delete_fleet(fleet)
	assert_false(_fleet_to_slot().has(fleet.id),
		"Le mapping _fleet_to_slot ne doit plus contenir la flotte supprimée")


func test_remove_fleet_updates_fleet_panel() -> void:
	var fleet := _create_fleet("Paneled")
	_delete_fleet(fleet)
	assert_eq(_fleet_panel().get_fleets().size(), 0,
		"Le volet Flottes doit être vide après suppression")


func test_remove_middle_fleet_reindexes_remaining() -> void:
	var fa := _create_fleet("A")
	var fb := _create_fleet("B")
	var fc := _create_fleet("C")
	# Supprime celle du milieu
	_delete_fleet(fb)
	assert_eq(_fleet_figure().data.output_slots.size(), 2, "Il doit rester 2 slots")
	# Les indices doivent être séquentiels
	for i in _fleet_figure().data.output_slots.size():
		assert_eq(_fleet_figure().data.output_slots[i].index, i,
			"Slot %d doit avoir index %d après reindexation" % [i, i])


func test_remove_fleet_preserves_other_slots() -> void:
	var fa := _create_fleet("Keep_A")
	var fb := _create_fleet("Remove_B")
	var fc := _create_fleet("Keep_C")
	_delete_fleet(fb)
	var labels: Array[String] = []
	for slot in _fleet_figure().data.output_slots:
		labels.append(slot.label)
	assert_has(labels, "Keep_A", "Le slot A doit être conservé")
	assert_has(labels, "Keep_C", "Le slot C doit être conservé")
	assert_does_not_have(labels, "Remove_B", "Le slot B doit avoir été supprimé")


# ══════════════════════════════════════════════════════════
# TESTS : SUPPRESSION DE FLOTTE AVEC LIENS
# ══════════════════════════════════════════════════════════

func test_remove_fleet_with_link_cleans_up_link() -> void:
	# Crée une flotte → slot de sortie sur la FleetFigure
	var fleet := _create_fleet("Linked")
	var fleet_slot_data: SlotData = _fleet_to_slot()[fleet.id]

	# Récupère une boîte cible (Démarrage a 2 inputs)
	var target_figure: Figure = null
	for figure_id in _figures_by_id():
		var figure: Figure = _figures_by_id()[figure_id]
		if not figure.is_fleet_figure and figure.data.input_slots.size() > 0:
			target_figure = figure
			break
	assert_not_null(target_figure, "Il doit y avoir une boîte cible avec des entrées")

	# Crée un lien FleetFigure (sortie) → boîte cible (entrée)
	var link := LinkData.create(
		_fleet_figure().data.id,
		fleet_slot_data.id,
		target_figure.data.id,
		target_figure.data.input_slots[0].id,
	)
	# Résoudre les slots visuels pour add_link
	await get_tree().process_frame
	var source_slot := _fleet_figure().find_slot_by_id(fleet_slot_data.id)
	var target_slot := target_figure.find_slot_by_id(target_figure.data.input_slots[0].id)

	if source_slot and target_slot:
		_links_layer().add_link(source_slot, target_slot, link)
		assert_eq(_link_count(), 1, "Le lien doit exister avant la suppression")

		# Supprime la flotte → le lien doit être nettoyé
		_delete_fleet(fleet)
		assert_eq(_link_count(), 0,
			"Le lien doit être supprimé quand la flotte est supprimée")
	else:
		# Si les slots visuels ne sont pas trouvés, on skip avec un warning
		gut.p("WARN: Slots visuels non résolus — test de lien visuel ignoré")
		pending("Slots visuels non résolus dans l'arbre de scène")


func test_remove_fleet_with_multiple_links_cleans_all() -> void:
	# Crée 2 flottes, connecte chacune à une boîte différente
	var fleet_a := _create_fleet("F_A")
	var fleet_b := _create_fleet("F_B")
	var slot_a: SlotData = _fleet_to_slot()[fleet_a.id]
	var slot_b: SlotData = _fleet_to_slot()[fleet_b.id]

	# Trouve 2 boîtes cibles
	var targets: Array[Figure] = []
	for figure_id in _figures_by_id():
		var figure: Figure = _figures_by_id()[figure_id]
		if not figure.is_fleet_figure and figure.data.input_slots.size() > 0:
			targets.append(figure)
	if targets.size() < 2:
		pending("Pas assez de boîtes cibles pour ce test")
		return

	await get_tree().process_frame

	# Créer les liens
	var link_a := LinkData.create(
		_fleet_figure().data.id, slot_a.id,
		targets[0].data.id, targets[0].data.input_slots[0].id,
	)
	var link_b := LinkData.create(
		_fleet_figure().data.id, slot_b.id,
		targets[1].data.id, targets[1].data.input_slots[0].id,
	)

	var src_a := _fleet_figure().find_slot_by_id(slot_a.id)
	var tgt_a := targets[0].find_slot_by_id(targets[0].data.input_slots[0].id)
	var src_b := _fleet_figure().find_slot_by_id(slot_b.id)
	var tgt_b := targets[1].find_slot_by_id(targets[1].data.input_slots[0].id)

	if src_a and tgt_a and src_b and tgt_b:
		_links_layer().add_link(src_a, tgt_a, link_a)
		_links_layer().add_link(src_b, tgt_b, link_b)
		assert_eq(_link_count(), 2, "2 liens doivent exister")

		# Supprime uniquement la flotte A
		_delete_fleet(fleet_a)
		assert_eq(_link_count(), 1,
			"Seul le lien de la flotte A doit être supprimé")

		# Vérifie que le lien restant est celui de la flotte B
		var remaining: LinkData = _get_links()[0]["link_data"]
		assert_eq(remaining.source_slot_id, slot_b.id,
			"Le lien restant doit être celui de la flotte B")
	else:
		pending("Slots visuels non résolus — test ignoré")


func test_remove_all_fleets_returns_to_initial_state() -> void:
	var f1 := _create_fleet("F1")
	var f2 := _create_fleet("F2")
	var f3 := _create_fleet("F3")
	_delete_fleet(f1)
	_delete_fleet(f2)
	_delete_fleet(f3)
	assert_eq(_fleet_figure().data.output_slots.size(), 0,
		"FleetFigure doit revenir à 0 slots")
	assert_eq(_fleet_to_slot().size(), 0,
		"Le mapping doit être vide")
	assert_eq(_fleet_panel().get_fleets().size(), 0,
		"Le volet doit être vide")


# ══════════════════════════════════════════════════════════
# TESTS : INTÉGRITÉ DES LIENS
# ══════════════════════════════════════════════════════════

func test_link_count_increments_on_add() -> void:
	var fleet := _create_fleet("CountTest")
	var slot_data: SlotData = _fleet_to_slot()[fleet.id]

	var target_figure: Figure = null
	for figure_id in _figures_by_id():
		var figure: Figure = _figures_by_id()[figure_id]
		if not figure.is_fleet_figure and figure.data.input_slots.size() > 0:
			target_figure = figure
			break
	if not target_figure:
		pending("Pas de boîte cible")
		return

	await get_tree().process_frame

	var link := LinkData.create(
		_fleet_figure().data.id, slot_data.id,
		target_figure.data.id, target_figure.data.input_slots[0].id,
	)
	var src := _fleet_figure().find_slot_by_id(slot_data.id)
	var tgt := target_figure.find_slot_by_id(target_figure.data.input_slots[0].id)

	if src and tgt:
		var before := _link_count()
		_links_layer().add_link(src, tgt, link)
		assert_eq(_link_count(), before + 1,
			"Le nombre de liens doit augmenter de 1")
	else:
		pending("Slots visuels non résolus")


func test_remove_link_decrements_count() -> void:
	var fleet := _create_fleet("RemoveCount")
	var slot_data: SlotData = _fleet_to_slot()[fleet.id]

	var target_figure: Figure = null
	for figure_id in _figures_by_id():
		var figure: Figure = _figures_by_id()[figure_id]
		if not figure.is_fleet_figure and figure.data.input_slots.size() > 0:
			target_figure = figure
			break
	if not target_figure:
		pending("Pas de boîte cible")
		return

	await get_tree().process_frame

	var link := LinkData.create(
		_fleet_figure().data.id, slot_data.id,
		target_figure.data.id, target_figure.data.input_slots[0].id,
	)
	var src := _fleet_figure().find_slot_by_id(slot_data.id)
	var tgt := target_figure.find_slot_by_id(target_figure.data.input_slots[0].id)

	if src and tgt:
		_links_layer().add_link(src, tgt, link)
		_links_layer().remove_link(link)
		assert_eq(_link_count(), 0, "Le lien doit être supprimé")
	else:
		pending("Slots visuels non résolus")
