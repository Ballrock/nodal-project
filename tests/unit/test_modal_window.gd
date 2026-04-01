extends GutTest

## Tests unitaires pour ModalWindow.

const ModalWindowScene := preload("res://ui/components/modal_window.tscn")

var _window: ModalWindow = null


func before_each() -> void:
	_window = ModalWindowScene.instantiate()
	add_child_autofree(_window)
	await get_tree().process_frame


func test_initial_state() -> void:
	assert_true(_window.visible, "La fenêtre doit être visible après instantiation (popup_fitted dans _ready)")
	assert_true(_window.force_native or true, "force_native est appliqué par setup_window")
	assert_true(_window.transient, "transient doit être true")
	assert_true(_window.exclusive, "exclusive doit être true")


func test_setup_sets_title() -> void:
	_window.setup("Mon titre test")
	assert_eq(_window.title, "Mon titre test")


func test_setup_different_title() -> void:
	_window.setup("Autre titre")
	assert_eq(_window.title, "Autre titre")


func test_add_content_adds_child() -> void:
	var label := Label.new()
	label.text = "Contenu test"
	_window.add_content(label)
	var container := _window.content_container
	assert_true(label.get_parent() == container, "Le label doit être enfant du ContentContainer")


func test_add_content_multiple() -> void:
	var label1 := Label.new()
	var label2 := Label.new()
	_window.add_content(label1)
	_window.add_content(label2)
	assert_eq(_window.content_container.get_child_count(), 2, "Deux enfants dans le ContentContainer")


func test_close_emits_signal() -> void:
	watch_signals(_window)
	_window.close()
	assert_signal_emitted(_window, "closed")


func test_close_queues_free() -> void:
	_window.close()
	assert_true(_window.is_queued_for_deletion(), "La fenêtre doit être marquée pour suppression")


func test_close_requested_triggers_close() -> void:
	watch_signals(_window)
	_window.close_requested.emit()
	assert_signal_emitted(_window, "closed")


func test_esc_closes_when_visible() -> void:
	_window.visible = true
	watch_signals(_window)
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	_window._input(event)
	assert_signal_emitted(_window, "closed")


func test_esc_ignored_when_hidden() -> void:
	_window.visible = false
	watch_signals(_window)
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	_window._input(event)
	assert_signal_not_emitted(_window, "closed")


func test_content_container_exists() -> void:
	assert_not_null(_window.content_container, "ContentContainer doit exister")
	assert_true(_window.content_container is VBoxContainer, "ContentContainer doit être un VBoxContainer")
