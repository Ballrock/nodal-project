class_name MenuManager
extends RefCounted

## Gère la configuration et le routage des menus de la barre d'outils.
## Externalise la logique menu hors de Main.gd.

signal save_requested
signal load_requested
signal global_settings_requested
signal quit_requested
signal add_figure_requested
signal scenography_settings_requested

enum FichierMenuId {
	SAVE = 0,
	LOAD = 1,
	GLOBAL_SETTINGS = 2,
	QUIT = 3,
}

enum ScenographieMenuId {
	SETTINGS = 0,
}

enum ElementMenuId {
	ADD_FIGURE = 0,
}


## Configure les PopupMenu avec leurs entrées et raccourcis.
func setup(fichier_menu: PopupMenu, scenographie_menu: PopupMenu, tolz_menu: PopupMenu, element_menu: PopupMenu) -> void:
	# Menu Fichier
	fichier_menu.add_item("Sauvegarder", FichierMenuId.SAVE)
	fichier_menu.set_item_shortcut(0, _make_shortcut(KEY_S, true), true)
	fichier_menu.add_item("Charger", FichierMenuId.LOAD)
	fichier_menu.set_item_shortcut(1, _make_shortcut(KEY_O, true), true)
	fichier_menu.add_separator()
	fichier_menu.add_item("Paramètres Généraux", FichierMenuId.GLOBAL_SETTINGS)
	fichier_menu.add_item("Quitter", FichierMenuId.QUIT)
	fichier_menu.id_pressed.connect(_on_fichier_menu_id_pressed)

	# Menu Scénographie
	scenographie_menu.add_item("Paramètres", ScenographieMenuId.SETTINGS)
	scenographie_menu.id_pressed.connect(_on_scenographie_menu_id_pressed)
	
	# Menu Tolz (pour l'instant vide, prêt à recevoir des items)

	# Menu Élément
	element_menu.add_item("Ajouter une Figure", ElementMenuId.ADD_FIGURE)
	element_menu.id_pressed.connect(_on_element_menu_id_pressed)


func _on_fichier_menu_id_pressed(id: int) -> void:
	match id:
		FichierMenuId.SAVE:
			save_requested.emit()
		FichierMenuId.LOAD:
			load_requested.emit()
		FichierMenuId.GLOBAL_SETTINGS:
			global_settings_requested.emit()
		FichierMenuId.QUIT:
			quit_requested.emit()


func _on_scenographie_menu_id_pressed(id: int) -> void:
	match id:
		ScenographieMenuId.SETTINGS:
			scenography_settings_requested.emit()


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
