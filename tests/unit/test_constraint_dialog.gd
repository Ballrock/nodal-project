extends GutTest

## Tests unitaires pour ConstraintDialog.

const ConstraintDialogScene := preload("res://features/fleet/constraint_dialog.tscn")

var _dialog: ConstraintDialog = null
var SettingsManagerClass = load("res://core/settings/settings_manager.gd")
var _sm = null


func before_each() -> void:
	_sm = SettingsManagerClass.new()
	_sm.name = "SettingsManager"
	add_child(_sm)
	await get_tree().process_frame

	_dialog = ConstraintDialogScene.instantiate()
	add_child_autofree(_dialog)
	await get_tree().process_frame


func after_each() -> void:
	if _dialog and is_instance_valid(_dialog):
		_dialog.hide()
	if _sm:
		_sm.queue_free()
		_sm = null


func test_initial_state() -> void:
	assert_false(_dialog.visible, "Le dialogue doit être masqué au départ")


func test_open_create() -> void:
	_dialog.open_create()
	assert_true(_dialog.visible)
	assert_eq(_dialog.title, "Nouvelle contrainte")
	assert_eq(_dialog.get_node("%ConstraintNameEdit").text, "")
	assert_false(_dialog.get_node("%ConstraintDeleteBtn").visible)
	assert_true(_dialog.get_node("%ConstraintValidateBtn").disabled, "Valider doit être désactivé sans sélection")


func test_open_edit() -> void:
	var constraint := DroneConstraint.create("TestProfile", DroneConstraint.ConstraintCategory.PYRO_EFFECT, "effect_pyro::Bengale verte", 50)
	_dialog.open_edit(constraint)
	assert_true(_dialog.visible)
	assert_eq(_dialog.get_node("%ConstraintNameEdit").text, "TestProfile")
	assert_eq(int(_dialog.get_node("%QuantitySpin").value), 50)
	assert_true(_dialog.get_node("%ConstraintDeleteBtn").visible)


func test_validate_create_emits_signal() -> void:
	watch_signals(_dialog)
	_dialog.open_create()

	# Select category "Type drone"
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.DRONE_TYPE:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break

	# Select value "RIFF" (index 1, index 0 is placeholder)
	var value_option: OptionButton = _dialog.get_node("%ValueOption")
	value_option.select(1)
	value_option.item_selected.emit(1)

	_dialog.get_node("%ConstraintNameEdit").text = "Bengales"
	_dialog.get_node("%QuantitySpin").value = 200

	_dialog.get_node("%ConstraintValidateBtn").pressed.emit()

	assert_signal_emitted(_dialog, "constraint_created")
	var args = get_signal_parameters(_dialog, "constraint_created")
	var constraint: DroneConstraint = args[0]
	assert_eq(constraint.name, "Bengales")
	assert_eq(constraint.quantity, 200)
	assert_false(_dialog.visible)


func test_validate_empty_name_does_not_emit() -> void:
	watch_signals(_dialog)
	_dialog.open_create()

	# Select a category and value so only name blocks validation
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.DRONE_TYPE:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break
	var value_option: OptionButton = _dialog.get_node("%ValueOption")
	value_option.select(1)
	value_option.item_selected.emit(1)

	# Clear auto-generated name (emit signal to simulate user edit)
	var name_edit := _dialog.get_node("%ConstraintNameEdit")
	name_edit.text = "  "
	name_edit.text_changed.emit("  ")

	# Validate button should be disabled with empty name
	assert_true(_dialog.get_node("%ConstraintValidateBtn").disabled)
	_dialog.get_node("%ConstraintValidateBtn").pressed.emit()

	assert_signal_not_emitted(_dialog, "constraint_created")
	assert_true(_dialog.visible)


func test_validate_edit_emits_signal() -> void:
	var constraint := DroneConstraint.create("OldName", DroneConstraint.ConstraintCategory.DRONE_TYPE, "0", 1)
	watch_signals(_dialog)
	_dialog.open_edit(constraint)
	_dialog.get_node("%ConstraintNameEdit").text = "NewName"
	_dialog.get_node("%QuantitySpin").value = 300

	_dialog.get_node("%ConstraintValidateBtn").pressed.emit()

	assert_signal_emitted(_dialog, "constraint_updated")
	assert_eq(constraint.name, "NewName")
	assert_eq(constraint.quantity, 300)


func test_delete_emits_signal() -> void:
	var constraint := DroneConstraint.create("ToDelete", DroneConstraint.ConstraintCategory.DRONE_TYPE, "0", 1)
	watch_signals(_dialog)
	_dialog.open_edit(constraint)

	_dialog.get_node("%ConstraintDeleteBtn").pressed.emit()

	assert_signal_emitted(_dialog, "constraint_deleted")
	assert_false(_dialog.visible)


func test_cancel_closes_dialog() -> void:
	_dialog.open_create()
	_dialog.get_node("%ConstraintCancelBtn").pressed.emit()
	assert_false(_dialog.visible)


func test_category_option_populated() -> void:
	_dialog.open_create()
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	assert_gt(category_option.item_count, 0, "Doit avoir des catégories")
	var labels: Array[String] = []
	for i in category_option.item_count:
		labels.append(category_option.get_item_text(i))
	assert_true(labels.has("Type drone"))
	assert_true(labels.has("Nacelle"))
	assert_true(labels.has("Payload"))
	assert_true(labels.has("Effet Pyro"))


func test_value_option_changes_with_category() -> void:
	_dialog.open_create()
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	var value_option: OptionButton = _dialog.get_node("%ValueOption")

	# Select "Nacelle" category
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.NACELLE:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break

	# item_count > 1 means at least one real item beyond the placeholder
	assert_gt(value_option.item_count, 1, "Doit afficher des nacelles (+ placeholder)")


func _select_pyro_category() -> void:
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.PYRO_EFFECT:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break


func _setup_pyro_effects(effects: Array) -> Variant:
	var original: Variant = SettingsManager.get_setting("composition/pyro_effects")
	SettingsManager.set_setting("composition/pyro_effects", effects)
	_dialog._load_catalogs()
	return original


func _count_selectable_items(item: TreeItem) -> int:
	var count := 0
	if item.is_selectable(0) and item.get_metadata(0) != null:
		count += 1
	var child := item.get_first_child()
	while child:
		count += _count_selectable_items(child)
		child = child.get_next()
	return count


func _collect_type_names(tree: Tree) -> Array[String]:
	var names: Array[String] = []
	var root := tree.get_root()
	if not root:
		return names
	var child := root.get_first_child()
	while child:
		if not child.is_selectable(0):
			names.append(child.get_text(0))
		child = child.get_next()
	return names


func test_pyro_effect_uses_real_catalog_when_available() -> void:
	var original = _setup_pyro_effects([
		{"id": "bengale_rouge", "name": "Bengale Rouge", "type": "Bengal"},
		{"id": "fumigene_blanc", "name": "Fumigene Blanc", "type": "Fumigene"},
	])

	_dialog.open_create()
	_select_pyro_category()

	# Should show 2 real effects in Tree
	var tree: Tree = _dialog.get_node("%EffectTree")
	var root := tree.get_root()
	assert_not_null(root, "Tree doit avoir une racine")
	var selectable := _count_selectable_items(root)
	assert_eq(selectable, 2, "Doit afficher les 2 effets reels dans le Tree")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_pyro_effect_falls_back_to_static_catalog_when_no_real_effects() -> void:
	var original = _setup_pyro_effects([])

	_dialog.open_create()
	_select_pyro_category()

	# Should fall back to static effects in Tree
	var tree: Tree = _dialog.get_node("%EffectTree")
	var root := tree.get_root()
	assert_not_null(root, "Tree doit avoir une racine")
	var selectable := _count_selectable_items(root)
	assert_gt(selectable, 0, "Doit afficher le catalogue statique en fallback")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_load_catalogs_populates_pyro_effects_real() -> void:
	var original: Variant = SettingsManager.get_setting("composition/pyro_effects")
	SettingsManager.set_setting("composition/pyro_effects", [
		{"id": "strobe_60", "name": "Strobe 60mm", "type": "Strobe"},
	])
	_dialog._load_catalogs()
	assert_eq(_dialog._pyro_effects_real.size(), 1)
	assert_eq(_dialog._pyro_effects_real[0].get("name"), "Strobe 60mm")
	SettingsManager.set_setting("composition/pyro_effects", original)


func test_pyro_mode_shows_tree_hides_option() -> void:
	_dialog.open_create()

	# Select a non-pyro category first
	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.DRONE_TYPE:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break

	var pyro_container: VBoxContainer = _dialog.get_node("%PyroEffectContainer")
	var value_option: OptionButton = _dialog.get_node("%ValueOption")

	assert_false(pyro_container.visible, "Pyro container masqué pour Type drone")
	assert_true(value_option.visible, "ValueOption visible pour Type drone")

	# Switch to PYRO_EFFECT
	_select_pyro_category()

	assert_true(pyro_container.visible, "Pyro container visible pour Effet Pyro")
	assert_false(value_option.visible, "ValueOption masqué pour Effet Pyro")


func test_effect_tree_groups_by_type() -> void:
	var original = _setup_pyro_effects([
		{"id": "b1", "name": "Bengale Rouge", "type": "Bengal"},
		{"id": "f1", "name": "Fumigene Blanc", "type": "Fumigene"},
		{"id": "b2", "name": "Bengale Verte", "type": "Bengal"},
	])

	_dialog.open_create()
	_select_pyro_category()

	var types := _collect_type_names(_dialog.get_node("%EffectTree"))
	assert_true(types.has("Bengal"), "Doit contenir le type Bengal")
	assert_true(types.has("Fumigene"), "Doit contenir le type Fumigene")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_effect_tree_sorts_alphabetically() -> void:
	var original = _setup_pyro_effects([
		{"id": "z1", "name": "Zinc Flare", "type": "Zinc"},
		{"id": "a1", "name": "Alpha Burst", "type": "Alpha"},
		{"id": "m1", "name": "Mega Flash", "type": "Mega"},
	])

	_dialog.open_create()
	_select_pyro_category()

	var types := _collect_type_names(_dialog.get_node("%EffectTree"))
	assert_eq(types[0], "Alpha", "Premier type doit etre Alpha")
	assert_eq(types[1], "Mega", "Deuxième type doit etre Mega")
	assert_eq(types[2], "Zinc", "Troisième type doit etre Zinc")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_effect_search_filters_effects() -> void:
	var original = _setup_pyro_effects([
		{"id": "b1", "name": "Bengale Rouge", "type": "Bengal"},
		{"id": "f1", "name": "Fumigene Blanc", "type": "Fumigene"},
	])

	_dialog.open_create()
	_select_pyro_category()

	# Filter by "bengale"
	_dialog._effect_search.text = "bengale"
	_dialog._effect_search.text_changed.emit("bengale")

	var tree: Tree = _dialog.get_node("%EffectTree")
	var selectable := _count_selectable_items(tree.get_root())
	assert_eq(selectable, 1, "Seul Bengale Rouge doit rester après filtre")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_effect_search_case_insensitive() -> void:
	var original = _setup_pyro_effects([
		{"id": "b1", "name": "Bengale Rouge", "type": "Bengal"},
		{"id": "f1", "name": "Fumigene Blanc", "type": "Fumigene"},
	])

	_dialog.open_create()
	_select_pyro_category()

	# Filter with uppercase
	_dialog._effect_search.text = "BENGALE"
	_dialog._effect_search.text_changed.emit("BENGALE")

	var tree: Tree = _dialog.get_node("%EffectTree")
	var selectable := _count_selectable_items(tree.get_root())
	assert_eq(selectable, 1, "Filtre case-insensitive doit trouver Bengale Rouge")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_effect_tree_selection_triggers_auto_name() -> void:
	var original = _setup_pyro_effects([
		{"id": "b1", "name": "Bengale Rouge", "type": "Bengal"},
	])

	_dialog.open_create()
	_select_pyro_category()

	# Find and select the Bengale Rouge item
	_dialog._select_tree_item_by_metadata("b1")
	_dialog._on_effect_tree_selected()

	assert_eq(_dialog.get_node("%ConstraintNameEdit").text, "Bengale Rouge", "Auto-nom depuis le Tree")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_effect_tree_selection_enables_validate() -> void:
	var original = _setup_pyro_effects([
		{"id": "b1", "name": "Bengale Rouge", "type": "Bengal"},
	])

	_dialog.open_create()
	_select_pyro_category()

	# Before selection, validate should be disabled
	assert_true(_dialog.get_node("%ConstraintValidateBtn").disabled, "Valider désactivé sans sélection")

	# Select an item
	_dialog._select_tree_item_by_metadata("b1")
	_dialog._on_effect_tree_selected()

	assert_false(_dialog.get_node("%ConstraintValidateBtn").disabled, "Valider activé après sélection")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_validate_with_tree_selection_emits_correct_value() -> void:
	var original = _setup_pyro_effects([
		{"id": "bengale_rouge", "name": "Bengale Rouge", "type": "Bengal"},
	])

	watch_signals(_dialog)
	_dialog.open_create()
	_select_pyro_category()

	# Select effect
	_dialog._select_tree_item_by_metadata("bengale_rouge")
	_dialog._on_effect_tree_selected()

	# Set name manually
	_dialog.get_node("%ConstraintNameEdit").text = "Test Pyro"
	_dialog.get_node("%ConstraintNameEdit").text_changed.emit("Test Pyro")
	_dialog.get_node("%QuantitySpin").value = 10

	_dialog.get_node("%ConstraintValidateBtn").pressed.emit()

	assert_signal_emitted(_dialog, "constraint_created")
	var args = get_signal_parameters(_dialog, "constraint_created")
	var constraint: DroneConstraint = args[0]
	assert_eq(constraint.value, "bengale_rouge", "Valeur doit correspondre au metadata")
	assert_eq(constraint.category, DroneConstraint.ConstraintCategory.PYRO_EFFECT)

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_open_edit_restores_tree_selection() -> void:
	var original = _setup_pyro_effects([
		{"id": "bengale_rouge", "name": "Bengale Rouge", "type": "Bengal"},
		{"id": "fumigene_blanc", "name": "Fumigene Blanc", "type": "Fumigene"},
	])

	var constraint := DroneConstraint.create("Test", DroneConstraint.ConstraintCategory.PYRO_EFFECT, "fumigene_blanc", 5)
	_dialog.open_edit(constraint)

	var tree: Tree = _dialog.get_node("%EffectTree")
	var selected := tree.get_selected()
	assert_not_null(selected, "Un item doit etre selectionne")
	assert_eq(selected.get_metadata(0), "fumigene_blanc", "Le bon effet doit etre selectionne")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_effect_tree_variants_as_sub_items() -> void:
	var original = _setup_pyro_effects([
		{"id": "comete", "name": "Comète", "type": "Comète", "variants": ["Rouge", "Verte", "Bleue"]},
	])

	_dialog.open_create()
	_select_pyro_category()

	var tree: Tree = _dialog.get_node("%EffectTree")
	var root := tree.get_root()
	var selectable := _count_selectable_items(root)
	assert_eq(selectable, 3, "3 variants doivent etre selectionnables")

	# Verify variant metadata format
	_dialog._select_tree_item_by_metadata("comete::Rouge")
	var selected := tree.get_selected()
	assert_not_null(selected, "Variant Rouge doit etre trouvable")
	assert_eq(selected.get_text(0), "Comète — Rouge")

	SettingsManager.set_setting("composition/pyro_effects", original)


func test_other_categories_still_use_option_button() -> void:
	_dialog.open_create()

	var category_option: OptionButton = _dialog.get_node("%CategoryOption")
	var pyro_container: VBoxContainer = _dialog.get_node("%PyroEffectContainer")
	var value_option: OptionButton = _dialog.get_node("%ValueOption")

	# Test NACELLE category
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.NACELLE:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break

	assert_false(pyro_container.visible, "Pyro container masqué pour Nacelle")
	assert_true(value_option.visible, "ValueOption visible pour Nacelle")
	assert_gt(value_option.item_count, 1, "Nacelle doit avoir des items")

	# Test PAYLOAD category
	for i in category_option.item_count:
		if category_option.get_item_id(i) == DroneConstraint.ConstraintCategory.PAYLOAD:
			category_option.select(i)
			category_option.item_selected.emit(i)
			break

	assert_false(pyro_container.visible, "Pyro container masqué pour Payload")
	assert_true(value_option.visible, "ValueOption visible pour Payload")
