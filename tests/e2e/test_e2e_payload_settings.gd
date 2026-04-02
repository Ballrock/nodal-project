extends "res://tests/unit/e2e_test_base.gd"

## Test E2E pour la page de parametrage des Payloads (lecture seule).
## Verifie la navigation, l'affichage de la liste telechargee et le bouton de telechargement
## dans Base de donnees / Payloads des parametres logiciel.
##
## Executer SANS --headless pour obtenir les screenshots :
##   $GODOT --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_payload_settings.gd


func _settings_window() -> Window:
	return _main.get_node("%SettingsWindow") as Window


func _category_tree() -> Tree:
	return _settings_window().get_node("%CategoryTree") as Tree


func _options_container() -> VBoxContainer:
	return _settings_window().get_node("%OptionsContainer") as VBoxContainer


func _find_tree_item_by_text(text: String) -> TreeItem:
	var root := _category_tree().get_root()
	if not root:
		return null
	return _search_tree_item(root, text)


func _search_tree_item(item: TreeItem, text: String) -> TreeItem:
	if item.get_text(0) == text:
		return item
	var child := item.get_first_child()
	while child:
		var found := _search_tree_item(child, text)
		if found:
			return found
		child = child.get_next()
	return null


func _count_payload_panels() -> int:
	var container := _settings_window().get("_payload_list_container") as VBoxContainer
	if not container:
		return 0
	var count := 0
	for child in container.get_children():
		if child is PanelContainer:
			count += 1
	return count


func _find_button_with_text(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text:
			return child
		if child.get_child_count() > 0:
			var found := _find_button_with_text(child, text)
			if found:
				return found
	return null


# ── Tests ────────────────────────────────────────────────────

func test_payload_settings_readonly_view() -> void:
	# ── 1. Ouvrir les parametres logiciel ──
	var sw := _settings_window()
	sw.force_native = false
	sw.content_scale_factor = 1.0
	sw.open_global()
	await _wait_frames(3)
	sw.position = Vector2i(0, 0)
	sw.size = get_window().size
	await _wait_frames(3)
	await _take_screenshot("01_settings_ouvert")

	# ── 2. Naviguer vers Base de donnees / Payloads ──
	var payloads_item := _find_tree_item_by_text("Payloads")
	assert_not_null(payloads_item, "La categorie 'Payloads' doit exister dans Base de donnees")
	if payloads_item:
		payloads_item.select(0)
		_category_tree().item_selected.emit()
		await _wait_frames(3)
	await _take_screenshot("02_page_payloads")

	# ── 3. Verifier l'absence de bouton d'ajout (lecture seule) ──
	var add_btn := _find_button_with_text(_options_container(), "Ajouter un payload")
	assert_null(add_btn, "Le bouton 'Ajouter un payload' ne doit plus exister (lecture seule)")
	await _take_screenshot("03_pas_de_bouton_ajout")

	# ── 4. Verifier la presence du bouton de telechargement ──
	var dl_btn := _find_button_with_text(_options_container(), "Telecharger la derniere version")
	assert_not_null(dl_btn, "Le bouton de telechargement doit exister")
	await _take_screenshot("04_bouton_telechargement")

	# ── 5. Verifier les labels d'information ──
	var status_label := sw.get("_payload_status_label") as Label
	assert_not_null(status_label, "Le label de statut doit exister")

	var count_label := sw.get("_payload_count_label") as Label
	assert_not_null(count_label, "Le label de compteur doit exister")
	await _take_screenshot("05_labels_info")

	# ── 6. Verifier la liste des payloads (peut etre vide si pas encore telecharge) ──
	var payload_count := _count_payload_panels()
	if payload_count > 0:
		await _take_screenshot("06_liste_payloads")
	else:
		# Verifier le message "Aucun payload disponible"
		var container := sw.get("_payload_list_container") as VBoxContainer
		if container and container.get_child_count() > 0:
			var first_child := container.get_child(0)
			if first_child is Label:
				assert_true(first_child.text.begins_with("Aucun payload"), "Message vide attendu")
		await _take_screenshot("06_liste_vide")

	# ── 7. Verifier l'absence de boutons edit/delete dans la liste ──
	var container2 := sw.get("_payload_list_container") as VBoxContainer
	if container2:
		var edit_btn := _find_icon_button(container2, "edit")
		assert_null(edit_btn, "Pas de bouton edit en lecture seule")
		var delete_btn := _find_icon_button(container2, "delete")
		assert_null(delete_btn, "Pas de bouton delete en lecture seule")
	await _take_screenshot("07_pas_de_boutons_crud")

	pass_test("Vue lecture seule des payloads validee")


# ── Helpers ──

func _find_icon_button(parent: Node, icon_text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == icon_text:
			return child
		if child.get_child_count() > 0:
			var found := _find_icon_button(child, icon_text)
			if found:
				return found
	return null
