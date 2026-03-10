# res://tests/unit/test_config_window.gd
extends "res://addons/gut/test.gd"

const ConfigWindowScene := preload("res://ui/components/config_window.tscn")
const FigureScene := preload("res://features/workspace/components/figure.tscn")
const FigureData := preload("res://core/data/figure_data.gd")

var _config_window: Window = null
var _figure: Figure = null

func before_each():
	_figure = FigureScene.instantiate()
	var data = FigureData.create("Test Figure", Vector2.ZERO, 1, 1)
	_figure.setup(data)
	add_child(_figure)
	
	_config_window = ConfigWindowScene.instantiate()
	add_child(_config_window)
	_config_window.setup(_figure)

func after_each():
	_config_window.free()
	_figure.free()

func test_setup_initializes_fields():
	assert_eq(_config_window.title, "Configuration : Test Figure")
	assert_eq(_config_window._title_edit.text, "Test Figure")
	assert_eq(_config_window._color_picker.color, _figure.data.color)

func test_title_change_updates_figure():
	_config_window._on_title_changed("New Title")
	assert_eq(_figure.data.title, "New Title")
	assert_eq(_figure.title_label.text, "New Title")
	assert_eq(_config_window.title, "Configuration : New Title")

func test_color_change_updates_figure():
	var new_color = Color.RED
	_config_window._on_color_changed(new_color)
	assert_eq(_figure.data.color, new_color)

func test_add_slot_pair():
	var initial_in = _figure.data.input_slots.size()
	var initial_out = _figure.data.output_slots.size()
	
	_config_window._on_add_slot_pressed()
	
	assert_eq(_figure.data.input_slots.size(), initial_in + 1)
	assert_eq(_figure.data.output_slots.size(), initial_out + 1)

func test_delete_slot_pair():
	# Ajoute une paire pour être sûr d'en avoir au moins 2
	_config_window._on_add_slot_pressed()
	var count_before = _figure.data.input_slots.size()
	
	_config_window._delete_slot_pair(0)
	
	assert_eq(_figure.data.input_slots.size(), count_before - 1)
	assert_eq(_figure.data.output_slots.size(), count_before - 1)
