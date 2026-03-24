class_name ModalWindow
extends Window

## Fenêtre modale générique basée sur Window.
## Remplace l'ancienne implémentation à base de CanvasLayer.

signal closed

@onready var content_container: VBoxContainer = %ContentContainer

func _ready() -> void:
	close_requested.connect(close)
	# Les fenêtres modales centrent au départ
	WindowHelper.popup_fitted(self)

func setup(p_title: String) -> void:
	title = p_title

## Ajoute un nœud au contenu de la fenêtre.
func add_content(node: Node) -> void:
	content_container.add_child(node)

func close() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
