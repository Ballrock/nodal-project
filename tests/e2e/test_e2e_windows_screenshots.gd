extends "res://tests/unit/e2e_test_base.gd"

## Test E2E pour capturer des screenshots de toutes les fenêtres/dialogues.
## Vérifie l'uniformité visuelle après l'harmonisation WindowHelper.
##
## Exécuter SANS --headless pour obtenir les screenshots :
##   $GODOT --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_windows_screenshots.gd


const CONFIG_WINDOW_SCENE := preload("res://ui/components/config_window.tscn")
const MODAL_WINDOW_SCENE := preload("res://ui/components/modal_window.tscn")
const ConstraintDialogScene := preload("res://features/fleet/constraint_dialog.tscn")
const FleetDialogScene := preload("res://features/fleet/fleet_dialog.tscn")


func _settings_window() -> Window:
	return _main.get_node("%SettingsWindow") as Window


func _composition_window() -> Window:
	return _main.get_node("%CompositionWindow") as Window


## Trouve un bouton par son texte dans un arbre de nœuds.
func _find_button_with_text(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text:
			return child
		if child.get_child_count() > 0:
			var found := _find_button_with_text(child, text)
			if found:
				return found
	return null


## Recherche récursive d'un TreeItem par texte.
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


## Désactive force_native sur une fenêtre pour la rendre capturable dans le viewport.
## Doit être appelé APRÈS add_child() car _ready() appelle setup_window().
func _make_capturable(win: Window) -> void:
	win.force_native = false
	win.content_scale_factor = 1.0
	win.exclusive = false


# ── Test principal ──────────────────────────────────────────

func test_windows_screenshots() -> void:
	# ── 1. ConfigWindow : fenêtre de configuration d'une figure ──
	var figures := _standard_figures()
	assert_gt(figures.size(), 0, "Au moins une figure doit exister")

	var fig := figures[0]
	var config_win = CONFIG_WINDOW_SCENE.instantiate()
	add_child_autofree(config_win)
	# Overrides APRÈS add_child (car _ready() appelle setup_window())
	_make_capturable(config_win)
	config_win.setup(fig)
	await _wait_frames(5)
	config_win.position = Vector2i(100, 100)
	config_win.size = Vector2i(600, 500)
	await _wait_frames(3)
	await _take_screenshot("01_config_window")

	config_win.hide()
	await _wait_frames(2)

	# ── 2. SettingsWindow : paramètres logiciel ──
	var sw := _settings_window()
	_make_capturable(sw)
	sw.open_global()
	await _wait_frames(3)
	sw.position = Vector2i(0, 0)
	sw.size = get_window().size
	await _wait_frames(3)
	await _take_screenshot("02_settings_window")

	sw.close()
	await _wait_frames(2)

	# ── 3. CompositionWindow : édition de la composition ──
	var cw := _composition_window()
	_make_capturable(cw)
	cw.open()
	await _wait_frames(3)
	cw.position = Vector2i(100, 50)
	cw.size = Vector2i(600, 450)
	await _wait_frames(3)
	await _take_screenshot("03_composition_window")

	# ── 4. ConstraintDialog : sous-dialogue de contrainte ──
	var cd := ConstraintDialogScene.instantiate()
	cw.add_child(cd)
	# Overrides APRÈS add_child (car _ready() appelle setup_window())
	_make_capturable(cd)
	cd.open_create()
	await _wait_frames(3)
	cd.position = Vector2i(250, 120)
	cd.size = Vector2i(450, 400)
	await _wait_frames(3)
	await _take_screenshot("04_constraint_dialog")

	cd.hide()
	cd.queue_free()
	await _wait_frames(2)
	cw.hide()
	await _wait_frames(2)

	# ── 5. PayloadSettings (lecture seule via SettingsWindow) ──
	_make_capturable(sw)
	sw.open_global()
	await _wait_frames(3)
	sw.position = Vector2i(0, 0)
	sw.size = get_window().size
	await _wait_frames(2)

	# Naviguer vers Payloads
	var cat_tree := sw.get_node("%CategoryTree") as Tree
	var payloads_item := _search_tree_item(cat_tree.get_root(), "Payloads")
	if payloads_item:
		payloads_item.select(0)
		cat_tree.item_selected.emit()
		await _wait_frames(3)

	await _take_screenshot("05_payload_settings")

	sw.close()
	await _wait_frames(2)

	# ── 6. FleetDialog : dialogue de flotte (instantiation directe) ──
	var fd := FleetDialogScene.instantiate()
	add_child_autofree(fd)
	_make_capturable(fd)
	fd.open_create()
	await _wait_frames(3)
	fd.position = Vector2i(200, 150)
	fd.size = Vector2i(400, 350)
	await _wait_frames(3)
	await _take_screenshot("06_fleet_dialog")
	fd.hide()
	await _wait_frames(2)

	# ── 7. ModalWindow : fenêtre modale générique (renommer) ──
	var modal := MODAL_WINDOW_SCENE.instantiate()
	add_child_autofree(modal)
	# _ready() appelle popup_fitted() qui rend le modal visible → cacher avant de changer force_native
	modal.hide()
	_make_capturable(modal)
	modal.setup("Renommer la figure")

	var edit := LineEdit.new()
	edit.text = "Démarrage"
	edit.placeholder_text = "Nouveau nom..."
	modal.add_content(edit)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	var cancel_btn := Button.new()
	cancel_btn.text = "Annuler"
	btn_row.add_child(cancel_btn)
	var ok_btn := Button.new()
	ok_btn.text = "Valider"
	btn_row.add_child(ok_btn)
	modal.add_content(btn_row)

	modal.position = Vector2i(200, 150)
	modal.size = Vector2i(400, 250)
	modal.show()
	await _wait_frames(3)
	await _take_screenshot("07_modal_window_rename")

	modal.hide()
	await _wait_frames(2)

	pass_test("Screenshots de toutes les fenêtres capturés")
