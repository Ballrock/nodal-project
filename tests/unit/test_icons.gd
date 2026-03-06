extends GutTest

## Tests pour la gestion des icônes et des polices.

const ICON_FONT_PATH = "res://assets/fonts/material_symbols_rounded.ttf"

func test_icon_font_exists() -> void:
	var file := FileAccess.open(ICON_FONT_PATH, FileAccess.READ)
	assert_not_null(file, "Le fichier de police Material Symbols doit exister à : " + ICON_FONT_PATH)

func test_icon_font_loading() -> void:
	# Utilisation de load() car preload() peut échouer en headless si les imports ne sont pas à jour
	var font := load(ICON_FONT_PATH) as Font
	assert_not_null(font, "La police doit pouvoir être chargée par Godot")
	
	if font:
		# Vérifier que c'est bien une font utilisable
		var size = font.get_string_size("lock", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		assert_gt(size.x, 0.0, "La police doit retourner une largeur positive pour l'icône 'lock'")
		assert_gt(size.y, 0.0, "La police doit retourner une hauteur positive pour l'icône 'lock'")

func test_links_layer_has_icon_font() -> void:
	var layer := LinksLayer.new()
	add_child_autofree(layer)
	
	# On vérifie que la variable existe et est assignée (elle est @onready donc on force le ready)
	layer._ready()
	assert_not_null(layer.get("_icon_font"), "LinksLayer doit avoir chargé la police d'icônes")

func test_icon_ligature_works() -> void:
	var font := load(ICON_FONT_PATH) as Font
	if not font:
		return
		
	var size_s = font.get_string_size("s", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var size_settings = font.get_string_size("settings", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	
	# Avec les ligatures, "settings" (8 lettres) doit avoir une largeur proche d'un seul caractère (l'icône).
	assert_almost_eq(size_settings.x, size_s.x, size_s.x * 0.8, "La ligature 'settings' devrait avoir une largeur proche d'une seule icône")
