extends GutTest

## Classe de base pour les tests end-to-end.
## Fournit des helpers pour simuler de vrais clics, drags et interactions
## souris sur l'application instanciée complète (Main.tscn).

const MainScene := preload("res://ui/main/main.tscn")

var _main: Control = null


# ── Setup / Teardown ─────────────────────────────────────

func before_each() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	await _wait_frames(2)
	_workspace().canvas_area.size = Vector2(1280, 720)


# ── Accesseurs ───────────────────────────────────────────

func _workspace() -> Node:
	return _main.get_node("%Workspace")

func _links_layer() -> LinksLayer:
	return _workspace().get_node("%LinksLayer") as LinksLayer

func _timeline_panel() -> Node:
	return _main.get_node("%TimelinePanel")

func _figures_by_id() -> Dictionary:
	return _main.get("_figures_by_id") as Dictionary

func _standard_figures() -> Array[Figure]:
	var result: Array[Figure] = []
	var figs := _figures_by_id()
	for id in figs:
		var figure: Figure = figs[id]
		if not figure.is_fleet_figure:
			result.append(figure)
	return result

func _selected_figure() -> Figure:
	return _main.get("_selected_figure") as Figure

func _link_count() -> int:
	return _links_layer().get_all_link_data().size()


# ── Helpers de simulation d'interactions ─────────────────

func _wait_frames(count: int = 1) -> void:
	for i in count:
		await get_tree().process_frame

func _simulate_click(target: Control, global_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = global_pos
	press.position = global_pos
	target._gui_input(press)
	await _wait_frames(1)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = global_pos
	release.position = global_pos
	target._gui_input(release)
	await _wait_frames(1)

func _simulate_double_click(target: Control, global_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.double_click = true
	press.global_position = global_pos
	press.position = global_pos
	target._gui_input(press)
	await _wait_frames(1)

func _simulate_drag(target: Control, from_pos: Vector2, to_pos: Vector2, steps: int = 5) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = from_pos
	press.position = from_pos
	target._gui_input(press)
	await _wait_frames(1)

	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var current_pos := from_pos.lerp(to_pos, t)
		var motion := InputEventMouseMotion.new()
		motion.global_position = current_pos
		motion.position = current_pos
		motion.relative = (to_pos - from_pos) / float(steps)
		target._gui_input(motion)
		await _wait_frames(1)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = to_pos
	release.position = to_pos
	target._gui_input(release)
	await _wait_frames(1)

func _simulate_slot_click(slot: Slot) -> void:
	var circle: Control = slot.get_node("%SlotCircle")
	var center := circle.global_position + circle.size / 2.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = center
	press.position = circle.size / 2.0
	circle.gui_input.emit(press)
	await _wait_frames(1)

func _simulate_button_press(button: Button) -> void:
	button.pressed.emit()
	await _wait_frames(1)

func _dispatch_input_event(event: InputEvent) -> void:
	get_viewport().push_input(event)
	await _wait_frames(1)

func _find_add_button(figure: Figure) -> Button:
	var slots_container: VBoxContainer = figure.get_node("%SlotsContainer")
	for child in slots_container.get_children():
		if child is Button and child.text == "+":
			return child
	return null

## Compteur interne pour nommer les screenshots séquentiellement.
var _screenshot_counter: int = 0

## Dossier de sortie pour les screenshots.
const SCREENSHOTS_BASE_DIR := "res://tests/e2e/screenshots"

## Horodatage du run (partagé entre tous les tests d'une même exécution).
static var _run_timestamp: String = ""

## Retourne l'horodatage du run courant, initialisé une seule fois.
func _get_run_timestamp() -> String:
	if _run_timestamp == "":
		var dt := Time.get_datetime_dict_from_system()
		_run_timestamp = "%04d%02d%02d-%02d%02d%02d" % [
			dt["year"], dt["month"], dt["day"],
			dt["hour"], dt["minute"], dt["second"]
		]
	return _run_timestamp

## Capture un screenshot du viewport et le sauvegarde en PNG.
## Le nom du fichier est préfixé par le compteur pour garantir l'ordre.
## Les screenshots sont organisés en : screenshots/YYYYMMDD-HHMMSS/nom_du_test/
func _take_screenshot(label: String, test_name: String = "") -> void:
	# En mode headless, get_texture() provoque une erreur engine "Parameter 't' is null".
	# On skip silencieusement la capture dans ce cas.
	if DisplayServer.get_name() == "headless":
		return

	# Attend 2 frames pour que le rendu soit à jour
	await _wait_frames(2)
	_screenshot_counter += 1

	# Construire le chemin du dossier
	var timestamp := _get_run_timestamp()
	var sub_dir := test_name if test_name != "" else _get_current_test_name()
	var dir_path := "%s/%s/%s" % [SCREENSHOTS_BASE_DIR, timestamp, sub_dir]

	var dir := DirAccess.open("res://")
	if dir:
		dir.make_dir_recursive(dir_path.replace("res://", ""))

	var filename := "%s/%02d_%s.png" % [dir_path, _screenshot_counter, label]
	var tex := get_viewport().get_texture()
	if tex == null:
		gut.p("WARNING: Could not capture screenshot")
		return
	var image := tex.get_image()
	if image:
		image.save_png(ProjectSettings.globalize_path(filename))
		gut.p("Screenshot saved: %s" % filename)
	else:
		gut.p("WARNING: Could not capture screenshot")

## Retourne le nom de la méthode de test en cours via GUT.
func _get_current_test_name() -> String:
	if gut:
		var test_obj = gut.get_current_test_object()
		if test_obj and "name" in test_obj:
			return test_obj.name
	# Fallback : utiliser le nom du script
	var script_path := get_script().resource_path as String
	return script_path.get_file().get_basename()


func _simulate_link_drag(source_slot: Slot, target_slot: Slot) -> void:
	_simulate_slot_click(source_slot)
	await _wait_frames(2)

	var ll := _links_layer()
	if ll.get("_dragging"):
		ll.set("_drag_snap_target", target_slot)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.global_position = target_slot.get_circle_global_center()
		_dispatch_input_event(release)
		await _wait_frames(2)
