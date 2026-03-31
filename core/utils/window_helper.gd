class_name WindowHelper
extends RefCounted

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


## Affiche un dialogue de confirmation natif OS avec scaling Retina.
## Appelle on_confirm si l'utilisateur valide, sinon le dialogue se ferme.
static func confirm(
	parent: Node,
	title_text: String,
	message: String,
	on_confirm: Callable,
	ok_text: String = "Supprimer",
	cancel_text: String = "Annuler"
) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.force_native = true
	dialog.content_scale_factor = DisplayServer.screen_get_scale()
	dialog.title = title_text
	dialog.dialog_text = message
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = cancel_text
	dialog.confirmed.connect(func():
		on_confirm.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	parent.add_child(dialog)
	dialog.popup_centered()
	return dialog
