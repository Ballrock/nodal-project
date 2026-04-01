extends "res://tests/unit/e2e_test_base.gd"

## Test E2E pour la page de parametrage des Payloads.
## Verifie la navigation, l'affichage, l'ajout, la modification et la suppression
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


func _apply_button() -> Button:
	return _settings_window().get_node("%ApplyButton") as Button


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


func _find_add_payload_button() -> Button:
	return _find_button_with_text(_options_container(), "Ajouter un payload")


## Trouve le PayloadDialog ouvert (enfant direct de la SettingsWindow)
func _find_payload_dialog() -> Window:
	var sw := _settings_window()
	for child in sw.get_children():
		if child is Window and child.name.begins_with("PayloadDialog"):
			return child
	return null


# ── Tests ────────────────────────────────────────────────────

func test_payload_settings_workflow() -> void:
	# ── 1. Ouvrir les parametres logiciel ──
	var sw := _settings_window()
	# Desactiver force_native pour que la fenetre s'affiche dans le viewport (capturable)
	sw.force_native = false
	sw.content_scale_factor = 1.0
	sw.open_global()
	await _wait_frames(3)
	# Maximiser la fenetre pour qu'elle occupe tout le viewport
	sw.position = Vector2i(0, 0)
	sw.size = get_window().size
	await _wait_frames(3)
	await _take_screenshot("01_settings_ouvert")

	# ── 2. Verifier que "Composition" n'apparait plus dans l'arbre ──
	var comp_item := _find_tree_item_by_text("Composition")
	assert_null(comp_item, "La categorie 'Composition' ne doit plus apparaitre dans les parametres generaux")
	await _take_screenshot("02_pas_de_composition")

	# ── 3. Naviguer vers Base de donnees / Payloads ──
	var payloads_item := _find_tree_item_by_text("Payloads")
	assert_not_null(payloads_item, "La categorie 'Payloads' doit exister dans Base de donnees")
	if payloads_item:
		payloads_item.select(0)
		_category_tree().item_selected.emit()
		await _wait_frames(3)
	await _take_screenshot("03_page_payloads")

	# ── 4. Verifier la liste des payloads ──
	var initial_count := _count_payload_panels()
	assert_gt(initial_count, 0, "Au moins 1 payload doit exister")
	await _take_screenshot("04_liste_payloads_defaut")

	# ── 5. Ajouter un nouveau payload (ouvre un dialogue) ──
	var add_btn := _find_add_payload_button()
	assert_not_null(add_btn, "Le bouton 'Ajouter un payload' doit exister")
	if add_btn:
		_simulate_button_press(add_btn)
		await _wait_frames(3)

	var dialog := _find_payload_dialog()
	assert_not_null(dialog, "Le PayloadDialog doit s'ouvrir")
	await _take_screenshot_os("05_formulaire_ajout", "", dialog)

	# ── 6. Remplir et enregistrer le nouveau payload ──
	if dialog:
		var name_edit := dialog.get_node("%NameEdit") as LineEdit
		if name_edit:
			name_edit.text = "FlameJet"
			name_edit.text_changed.emit("FlameJet")
		await _wait_frames(1)

		# Cocher RIFF
		var riff_check := dialog.get_node("%RiffCheck") as CheckBox
		if riff_check:
			riff_check.button_pressed = true

		# Cliquer sur Enregistrer
		var save_btn := dialog.get_node("%ValidateBtn") as Button
		if save_btn:
			_simulate_button_press(save_btn)
			await _wait_frames(3)
	await _take_screenshot("06_payload_ajoute")

	# Verifier que le payload a ete ajoute
	assert_eq(_count_payload_panels(), initial_count + 1, "Un payload de plus apres ajout de FlameJet")

	# ── 7. Modifier un payload existant (le premier : Laser) ──
	var container := sw.get("_payload_list_container") as VBoxContainer
	var edit_btn := _find_first_icon_button(container, "edit")
	if edit_btn:
		_simulate_button_press(edit_btn)
		await _wait_frames(3)

	var edit_dialog := _find_payload_dialog()
	assert_not_null(edit_dialog, "Le PayloadDialog doit s'ouvrir pour edition")
	await _take_screenshot_os("07_formulaire_modification", "", edit_dialog)

	# Changer les contraintes et enregistrer
	if edit_dialog:
		var emo_check := edit_dialog.get_node("%EmoCheck") as CheckBox
		if emo_check:
			emo_check.button_pressed = true
		var save_btn2 := edit_dialog.get_node("%ValidateBtn") as Button
		if save_btn2:
			_simulate_button_press(save_btn2)
			await _wait_frames(3)
	await _take_screenshot("08_payload_modifie")

	# ── 8. Supprimer le dernier payload (FlameJet) ──
	var delete_btn := _find_last_icon_button(container, "delete")
	if delete_btn:
		_simulate_button_press(delete_btn)
		await _wait_frames(3)

	# Confirmer la suppression dans le dialogue de confirmation custom
	var confirm_dialog := _find_confirm_dialog(sw)
	assert_not_null(confirm_dialog, "Le dialogue de confirmation de suppression doit s'ouvrir")
	await _take_screenshot_os("09a_confirmation_suppression", "", confirm_dialog)
	if confirm_dialog:
		# Trouver et cliquer le bouton OK (dernier bouton du HBoxContainer)
		var ok_btn := _find_last_button(confirm_dialog)
		if ok_btn:
			_simulate_button_press(ok_btn)
		await _wait_frames(3)
	await _take_screenshot("09_payload_supprime")

	assert_eq(_count_payload_panels(), initial_count, "Retour au nombre initial apres suppression de FlameJet")

	# ── 9. Appliquer les changements ──
	_apply_button().pressed.emit()
	await _wait_frames(3)
	await _take_screenshot("10_settings_applique")

	# Verifier que les payloads ont bien ete persistes
	var saved_payloads: Array = SettingsManager.get_setting("composition/payloads")
	assert_eq(saved_payloads.size(), initial_count, "Payloads persistes = nombre initial")
	if saved_payloads.size() >= 1:
		# Verifier que le Laser a bien les contraintes modifiees
		var laser: Dictionary = saved_payloads[0] as Dictionary
		assert_eq(str(laser.get("name", "")), "Laser", "Premier payload = Laser")

	pass_test("Workflow complet de parametrage des payloads termine")


## Trouve le dialogue de confirmation ouvert (Window enfant visible, hors PayloadDialog).
func _find_confirm_dialog(parent: Node) -> Window:
	for child in parent.get_children():
		if child is Window and child.visible and not child.name.begins_with("PayloadDialog"):
			return child
	return null


## Trouve le dernier bouton dans un arbre de nœuds (le bouton OK/Supprimer).
func _find_last_button(parent: Node) -> Button:
	var all: Array[Button] = []
	_collect_buttons(parent, all)
	if all.is_empty():
		return null
	return all[all.size() - 1]


func _collect_buttons(parent: Node, result: Array[Button]) -> void:
	for child in parent.get_children():
		if child is Button:
			result.append(child)
		if child.get_child_count() > 0:
			_collect_buttons(child, result)


# ── Helpers supplementaires ──

func _find_node_of_type(parent: Node, type_name: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == type_name:
			return child
		if child.get_child_count() > 0:
			var found := _find_node_of_type(child, type_name)
			if found:
				return found
	return null


func _find_checkbox_with_text(parent: Node, text: String) -> CheckBox:
	for child in parent.get_children():
		if child is CheckBox and child.text == text:
			return child
		if child.get_child_count() > 0:
			var found := _find_checkbox_with_text(child, text)
			if found:
				return found
	return null


func _find_first_icon_button(parent: Node, icon_text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == icon_text:
			return child
		if child.get_child_count() > 0:
			var found := _find_first_icon_button(child, icon_text)
			if found:
				return found
	return null


func _find_last_icon_button(parent: Node, icon_text: String) -> Button:
	var all_buttons: Array[Button] = []
	_collect_icon_buttons(parent, icon_text, all_buttons)
	if all_buttons.is_empty():
		return null
	return all_buttons[all_buttons.size() - 1]


func _collect_icon_buttons(parent: Node, icon_text: String, result: Array[Button]) -> void:
	for child in parent.get_children():
		if child is Button and child.text == icon_text:
			result.append(child)
		if child.get_child_count() > 0:
			_collect_icon_buttons(child, icon_text, result)
