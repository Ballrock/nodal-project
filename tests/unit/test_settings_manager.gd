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
