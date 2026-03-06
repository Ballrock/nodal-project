extends GutTest

## Tests unitaires pour le verrouillage des liens et le menu contextuel unifié.

const MainScene := preload("res://ui/main/main.tscn")
const LinkData := preload("res://core/data/link_data.gd")

var _main: Control = null

func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame

func _workspace() -> Node:
	return _main.get_node("%Workspace")

func _links_layer() -> LinksLayer:
	return _workspace().get_node("%LinksLayer") as LinksLayer

func _figures_by_id() -> Dictionary:
	return _main.get("_figures_by_id") as Dictionary

func _get_standard_figures() -> Array[Figure]:
	var result: Array[Figure] = []
	var figs = _figures_by_id()
	for id in figs:
		var figure = figs[id]
		if not figure.is_fleet_figure:
			result.append(figure)
	return result

# ── Tests de Données ──────────────────────────────────────

func test_link_data_lock_state() -> void:
	var ld := LinkData.create("a", "s1", "b", "s2")
	assert_false(ld.is_locked, "Un lien devrait être déverrouillé par défaut")
	ld.is_locked = true
	assert_true(ld.is_locked)

# ── Tests de Logique de Menu ──────────────────────────────

func test_unified_menu_logic_lock_unlock() -> void:
	var ld := LinkData.new()
	var layer := _links_layer()
	
	layer._ctx_link = ld
	# ID 0 = Verrouiller
	layer._on_link_menu_id_pressed(0)
	assert_true(ld.is_locked, "Le lien devrait être verrouillé après clic menu")
	
	layer._ctx_link = ld
	# ID 1 = Déverrouiller
	layer._on_link_menu_id_pressed(1)
	assert_false(ld.is_locked, "Le lien devrait être déverrouillé après clic menu")

func test_unified_menu_logic_delete_disabled_when_locked() -> void:
	var ld := LinkData.new()
	ld.is_locked = true
	var layer := _links_layer()
	
	# On simule l'ouverture du menu pour vérifier l'état des items
	layer._ctx_link = ld
	layer.call("_show_link_context_menu", Vector2.ZERO)
	
	var popup: PopupMenu = null
	# On cherche le PopupMenu dans les enfants
	for child in layer.get_children():
		if child is PopupMenu:
			popup = child
			break
			
	assert_not_null(popup, "Le PopupMenu devrait être créé")
	if popup:
		# Index 0 = Verrouiller/Déverrouiller, Index 1 = Separator, Index 2 = Supprimer
		assert_true(popup.is_item_disabled(2), "L'option Supprimer devrait être grisée si le lien est verrouillé")
		popup.queue_free()

# ── Tests d'Intégration Slot -> Link Menu ────────────────

func test_slot_right_click_opens_link_menu_if_connected() -> void:
	var figs := _get_standard_figures()
	var fig_a := figs[0]
	var fig_b := figs[1]
	var layer := _links_layer()
	
	# Créer un lien
	var link := LinkData.create(fig_a.data.id, fig_a.data.output_slots[0].id, fig_b.data.id, fig_b.data.input_slots[0].id)
	layer.add_link_from_data(link)
	layer.refresh()
	
	var slot_node := fig_a.find_slot_by_id(fig_a.data.output_slots[0].id)
	
	# Simuler le signal depuis la figure
	fig_a.slot_context_menu_requested.emit(slot_node, fig_a, Vector2(100, 100))
	
	assert_eq(layer._ctx_link, link, "Le menu du lien devrait être activé lors du clic sur un slot connecté")

func test_slot_right_click_opens_slot_menu_if_not_connected() -> void:
	var figs := _get_standard_figures()
	var fig_a := figs[0]
	var layer := _links_layer()
	
	var slot_data := fig_a.data.output_slots[0]
	layer.remove_links_for_slot_id(slot_data.id)
	layer.refresh()
	
	var slot_node := fig_a.find_slot_by_id(slot_data.id)
	
	# Simuler le signal
	fig_a.slot_context_menu_requested.emit(slot_node, fig_a, Vector2(100, 100))
	
	assert_null(layer._ctx_link, "Le menu du lien NE devrait PAS être activé si le slot n'a pas de lien")

func test_right_click_on_link_trait_opens_menu() -> void:
	var figs := _get_standard_figures()
	var fig_a := figs[0]
	var fig_b := figs[1]
	var layer := _links_layer()
	
	# Créer un lien
	var link := LinkData.create(fig_a.data.id, fig_a.data.output_slots[0].id, fig_b.data.id, fig_b.data.input_slots[0].id)
	layer.add_link_from_data(link)
	layer.refresh()
	
	# Calculer un point approximatif au milieu du lien (Bézier simplifié pour le test)
	var from := fig_a.find_slot_by_id(fig_a.data.output_slots[0].id).get_circle_global_center()
	var to := fig_b.find_slot_by_id(fig_b.data.input_slots[0].id).get_circle_global_center()
	var mid := (from + to) / 2.0
	
	# Simuler le survol du milieu du lien
	# On utilise la nouvelle version de _update_hovered_link qui accepte une position
	layer.call("_update_hovered_link", mid)
	
	assert_eq(layer._hovered_link, link, "Le lien devrait être survolé au milieu")
	
	# Simuler l'événement de clic droit à cet endroit
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.global_position = mid
	
	layer._input(event)
	
	assert_eq(layer._ctx_link, link, "Le menu contextuel devrait être ouvert après clic sur le trait")
