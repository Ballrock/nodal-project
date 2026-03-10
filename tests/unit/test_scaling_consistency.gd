extends GutTest

## Test de cohérence des échelles et tailles entre l'espace de travail et les fenêtres.

const FigureScene := preload("res://features/workspace/components/figure.tscn")
const ConfigWindowScene := preload("res://ui/components/config_window.tscn")
const FigureData := preload("res://core/data/figure_data.gd")

var _figure: Figure = null
var _config_window: Window = null

func before_each() -> void:
	_figure = FigureScene.instantiate()
	var data := FigureData.create("Figure Test", Vector2.ZERO, 1, 1)
	_figure.setup(data)
	add_child_autofree(_figure)
	
	_config_window = ConfigWindowScene.instantiate()
	add_child_autofree(_config_window)
	_config_window.setup(_figure)
	
	await get_tree().process_frame

func test_font_size_consistency() -> void:
	# Récupérer la taille de police du titre de la figure (Label dans le workspace)
	var figure_title_label: Label = _figure.get_node("%TitleLabel")
	var figure_font_size = figure_title_label.get_theme_font_size("font_size")
	
	# Récupérer la taille de police d'un Label dans la fenêtre de config
	# (On cherche un label qui n'a pas d'override spécifique s'il en reste)
	var config_label: Label = _config_window.find_child("Label", true, false)
	var config_font_size = config_label.get_theme_font_size("font_size")
	
	# Récupérer la taille de police d'un bouton ou LineEdit dans la fenêtre
	var config_edit: LineEdit = _config_window.find_child("TitleEdit", true, false)
	var edit_font_size = config_edit.get_theme_font_size("font_size")
	
	assert_eq(figure_font_size, 16, "La figure doit avoir une police de 16px")
	assert_eq(config_font_size, 16, "Les labels de la config doivent avoir une police de 16px")
	assert_eq(edit_font_size, 16, "Les LineEdit de la config doivent avoir une police de 16px (était 14px)")
	
	assert_eq(figure_font_size, edit_font_size, "La taille de police doit être identique entre le workspace et les fenêtres")

func test_content_scale_inheritance() -> void:
	# Les fenêtres natives (force_native = true) doivent avoir un content_scale_factor
	# correspondant au DPI de l'écran pour un rendu correct du texte.
	var expected_scale := DisplayServer.screen_get_scale()
	
	assert_eq(_config_window.content_scale_factor, expected_scale,
		"La ConfigWindow native doit avoir un content_scale_factor = screen DPI scale")
