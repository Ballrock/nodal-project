# tests/unit/test_settings_manager.gd
extends "res://addons/gut/test.gd"

var SettingsManagerClass = load("res://core/settings/settings_manager.gd")
var _sm = null

func before_each():
	_sm = SettingsManagerClass.new()
	add_child(_sm)

func after_each():
	_sm.free()

func test_declare_and_get_setting():
	_sm.declare_setting("test/my_val", 0, 42) # NUMBER
	assert_eq(_sm.get_setting("test/my_val"), 42, "La valeur par défaut doit être 42")

func test_set_setting():
	_sm.declare_setting("test/my_val", 0, 42)
	_sm.set_setting("test/my_val", 100)
	assert_eq(_sm.get_setting("test/my_val"), 100, "La valeur doit être mise à jour à 100")

func test_setting_changed_signal():
	_sm.declare_setting("test/my_val", 0, 42)
	watch_signals(_sm)
	_sm.set_setting("test/my_val", 123)
	assert_signal_emitted_with_parameters(_sm, "setting_changed", ["test/my_val", 123])

func test_get_categories():
	# La signature est : key, type, default, scope, category...
	_sm.declare_setting("cat1/val", 0, 1, 0, "Category 1") # 0 = GLOBAL
	_sm.declare_setting("cat2/val", 0, 2, 0, "Category 2")
	var cats = _sm.get_categories_for_scope(0) # 0 = GLOBAL
	assert_true(cats.has("Category 1"))
	assert_true(cats.has("Category 2"))

func test_get_settings_by_category():
	_sm.declare_setting("cat1/val1", 0, 1, 0, "Category 1")
	_sm.declare_setting("cat1/val2", 0, 2, 0, "Category 1")
	_sm.declare_setting("cat2/val1", 0, 3, 0, "Category 2")

	var cat1_settings = _sm.get_settings_by_category_and_scope("Category 1", 0)
	assert_eq(cat1_settings.size(), 2, "Doit avoir 2 paramètres dans Category 1 (GLOBAL)")

# --- Tests get_category_tree_for_scope ---
# Ces tests utilisent une instance isolée (sans add_child) pour éviter
# la pollution par _declare_defaults() qui est appelé dans _ready().

func _create_isolated_sm():
	var sm = SettingsManagerClass.new()
	# Ne pas appeler add_child pour éviter _ready()/_declare_defaults()
	return sm

func test_category_tree_flat_structure():
	var sm = _create_isolated_sm()
	sm.declare_setting("a/val", 0, 1, 0, "Alpha")
	sm.declare_setting("b/val", 0, 2, 0, "Beta")
	var tree = sm.get_category_tree_for_scope(0)
	assert_eq(tree.size(), 2, "Doit avoir 2 catégories L1")
	assert_eq(tree[0]["name"], "Alpha")
	assert_eq(tree[0]["children"].size(), 0)
	assert_eq(tree[1]["name"], "Beta")
	sm.free()

func test_category_tree_hierarchical():
	var sm = _create_isolated_sm()
	sm.declare_setting("a/val", 0, 1, 0, "Parent/ChildB")
	sm.declare_setting("b/val", 0, 2, 0, "Parent/ChildA")
	var tree = sm.get_category_tree_for_scope(0)
	assert_eq(tree.size(), 1, "Doit avoir 1 catégorie L1")
	assert_eq(tree[0]["name"], "Parent")
	assert_eq(tree[0]["children"].size(), 2)
	# Children triés alphabétiquement
	assert_eq(tree[0]["children"][0], "ChildA")
	assert_eq(tree[0]["children"][1], "ChildB")
	sm.free()

func test_category_tree_general_pinned_first():
	var sm = _create_isolated_sm()
	sm.declare_setting("z/val", 0, 1, 0, "Zulu/Sub")
	sm.declare_setting("g/val", 0, 2, 0, "Général/Canvas")
	sm.declare_setting("a/val", 0, 3, 0, "Alpha")
	var tree = sm.get_category_tree_for_scope(0)
	assert_eq(tree[0]["name"], "Général", "Général doit toujours être en premier")
	assert_eq(tree[1]["name"], "Alpha")
	assert_eq(tree[2]["name"], "Zulu")
	sm.free()

func test_category_tree_children_sorted():
	var sm = _create_isolated_sm()
	sm.declare_setting("a/val", 0, 1, 0, "Général/Logiciel")
	sm.declare_setting("b/val", 0, 2, 0, "Général/Canvas")
	sm.declare_setting("c/val", 0, 3, 0, "Général/Composition")
	var tree = sm.get_category_tree_for_scope(0)
	var children = tree[0]["children"]
	assert_eq(children[0], "Canvas")
	assert_eq(children[1], "Composition")
	assert_eq(children[2], "Logiciel")
	sm.free()

func test_category_tree_with_full_path_settings():
	var sm = _create_isolated_sm()
	sm.declare_setting("a/val", 0, 1, 0, "Général/Canvas")
	sm.declare_setting("b/val", 0, 2, 0, "Général/Canvas")
	var settings = sm.get_settings_by_category_and_scope("Général/Canvas", 0)
	assert_eq(settings.size(), 2, "get_settings_by_category_and_scope doit fonctionner avec chemin complet")
	sm.free()
