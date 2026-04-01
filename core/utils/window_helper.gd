class_name WindowHelper
extends RefCounted

## Nom interne du noeud backdrop pour l'identifier dans l'arbre.
const _BACKDROP_NAME := "__modal_backdrop"


## Style partagé pour le panneau de fond de toutes les fenêtres/dialogues.
## Utiliser via WindowHelper.create_dialog_panel_style() pour obtenir une instance.
static func create_dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.98)
	style.content_margin_left = 24.0
	style.content_margin_top = 20.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 20.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


## Configure une fenêtre avec les propriétés standard de l'application.
## Applique : force_native, content_scale_factor (Retina), transient, exclusive.
## Doit être appelé dans le _ready() de chaque fenêtre, avant show()/popup().
static func setup_window(win: Window) -> void:
	win.force_native = true
	win.content_scale_factor = DisplayServer.screen_get_scale()
	win.transient = true
	win.exclusive = true


## Recalcule la taille de la fenetre selon son contenu, puis l'affiche
## centree avec une taille max proportionnelle a l'ecran.
## Si auto_resize est false, la taille actuelle est conservee (utile pour
## les fenetres a layout fixe comme les parametres).
static func popup_fitted(win: Window, max_ratio: float = 0.85, auto_resize: bool = true) -> void:
	if auto_resize:
		win.reset_size()
	var screen_rect := DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen())
	var max_size := Vector2i(
		int(screen_rect.size.x * max_ratio),
		int(screen_rect.size.y * max_ratio))
	win.size = Vector2i(
		mini(win.size.x, max_size.x),
		mini(win.size.y, max_size.y))
	win.popup_centered()


## Affiche un dialogue de confirmation custom avec le style uniforme de l'app.
## Appelle on_confirm si l'utilisateur valide, sinon le dialogue se ferme.
static func confirm(
	parent: Node,
	title_text: String,
	message: String,
	on_confirm: Callable,
	ok_text: String = "Supprimer",
	cancel_text: String = "Annuler"
) -> Window:
	var dialog := Window.new()
	dialog.visible = false
	setup_window(dialog)
	dialog.title = title_text
	dialog.wrap_controls = true
	dialog.unresizable = true

	# Panel avec le style partagé
	var panel_style := load("res://assets/themes/dialog_panel_style.tres") as StyleBoxFlat
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	dialog.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Message
	var label := Label.new()
	label.text = message
	label.custom_minimum_size.x = 300
	vbox.add_child(label)

	# Boutons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = cancel_text
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.3, 0.3, 0.33, 1)
	cancel_style.set_content_margin_all(6.0)
	cancel_style.content_margin_left = 12.0
	cancel_style.content_margin_right = 12.0
	cancel_style.set_corner_radius_all(4)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	btn_row.add_child(cancel_btn)

	var ok_btn := Button.new()
	ok_btn.text = ok_text
	var ok_style := StyleBoxFlat.new()
	ok_style.bg_color = Color(0.75, 0.25, 0.25, 1)
	ok_style.set_content_margin_all(6.0)
	ok_style.content_margin_left = 12.0
	ok_style.content_margin_right = 12.0
	ok_style.set_corner_radius_all(4)
	ok_btn.add_theme_stylebox_override("normal", ok_style)
	btn_row.add_child(ok_btn)

	# Signaux
	var close_dialog := func():
		dialog.hide()
		dialog.queue_free()
	ok_btn.pressed.connect(func():
		on_confirm.call()
		close_dialog.call()
	)
	cancel_btn.pressed.connect(close_dialog)
	dialog.close_requested.connect(close_dialog)

	parent.add_child(dialog)
	bind_backdrop(parent, dialog)
	# reset_size force le wrap_controls à recalculer la taille au contenu
	dialog.reset_size()
	dialog.popup_centered()
	return dialog


# ── Backdrop modal ───────────────────────────────────────────

## Ajoute un backdrop sombre semi-transparent sur une fenêtre parente.
## Le backdrop bloque les hover/clic dans le contenu de la fenêtre et
## indique visuellement que seul le dialogue enfant est actif.
static func show_backdrop(parent_win: Window) -> ColorRect:
	hide_backdrop(parent_win)
	var backdrop := ColorRect.new()
	backdrop.name = _BACKDROP_NAME
	backdrop.color = Color(0, 0, 0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	parent_win.add_child(backdrop)
	# Placer le backdrop au-dessus de tout le contenu existant
	parent_win.move_child(backdrop, parent_win.get_child_count() - 1)
	return backdrop


## Retire le backdrop d'une fenêtre parente.
static func hide_backdrop(parent_win: Window) -> void:
	if not is_instance_valid(parent_win):
		return
	var existing := parent_win.get_node_or_null(_BACKDROP_NAME)
	if existing:
		existing.queue_free()


## Lie automatiquement un backdrop à une fenêtre enfant.
## Le backdrop s'affiche immédiatement et se retire automatiquement quand
## la fenêtre enfant se ferme (hide, close, ou queue_free).
## Fonctionne pour les N1 (child = Settings/Config/Composition) comme
## pour les N2 (child = PayloadDialog/ConstraintDialog/etc.).
## Safe à appeler plusieurs fois : les signaux ne sont connectés qu'une fois.
static func bind_backdrop(parent_win: Window, child_win: Window) -> void:
	show_backdrop(parent_win)
	# Ne connecter les signaux qu'une seule fois (évite l'accumulation
	# pour les fenêtres N1 réutilisées entre open/close/open).
	if child_win.has_meta("_backdrop_bound"):
		return
	child_win.set_meta("_backdrop_bound", true)
	# Retirer le backdrop quand l'enfant devient invisible (hide ou close)
	child_win.visibility_changed.connect(func():
		if not child_win.visible:
			hide_backdrop(parent_win)
	)
	# Filet de sécurité : si l'enfant est détruit sans hide
	child_win.tree_exiting.connect(func():
		hide_backdrop(parent_win)
	)


## Ouvre un dialogue enfant (N2) avec backdrop sur la fenêtre parente (N1).
## Utiliser à la place de add_child + popup_fitted pour les sous-dialogues.
static func open_modal(parent_win: Window, child_win: Window, max_ratio: float = 0.85) -> void:
	parent_win.add_child(child_win)
	bind_backdrop(parent_win, child_win)
