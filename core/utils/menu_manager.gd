class_name MenuManager
extends RefCounted

## Gère la configuration et le routage des menus de la barre d'outils.
## Externalise la logique menu hors de Main.gd.

signal save_requested
signal load_requested
signal add_figure_requested

enum FichierMenuId {
	SAVE = 0,
	LOAD = 1,
}

enum ElementMenuId {
	ADD_FIGURE = 0,
}


## Configure les PopupMenu avec leurs entrées et raccourcis.
func setup(fichier_menu: PopupMenu, element_menu: PopupMenu) -> void:
	# Menu Fichier
	fichier_menu.add_item("Sauvegarder", FichierMenuId.SAVE)
	fichier_menu.set_item_shortcut(0, _make_shortcut(KEY_S, true), true)
	fichier_menu.add_item("Charger", FichierMenuId.LOAD)
	fichier_menu.set_item_shortcut(1, _make_shortcut(KEY_O, true), true)
	fichier_menu.id_pressed.connect(_on_fichier_menu_id_pressed)

	# Menu Élément
	element_menu.add_item("Ajouter une Figure", ElementMenuId.ADD_FIGURE)
	element_menu.id_pressed.connect(_on_element_menu_id_pressed)


func _on_fichier_menu_id_pressed(id: int) -> void:
	match id:
		FichierMenuId.SAVE:
			save_requested.emit()
		FichierMenuId.LOAD:
			load_requested.emit()


func _on_element_menu_id_pressed(id: int) -> void:
	match id:
		ElementMenuId.ADD_FIGURE:
			add_figure_requested.emit()


## Crée un Shortcut à partir d'un keycode et de modificateurs.
static func _make_shortcut(keycode: Key, ctrl: bool = false) -> Shortcut:
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.ctrl_pressed = ctrl
	var shortcut := Shortcut.new()
	shortcut.events = [key_event]
	return shortcut
