extends "res://addons/gut/test.gd"

const WorkspaceScene := preload("res://features/workspace/workspace.tscn")

var workspace: Control

func before_each():
	workspace = WorkspaceScene.instantiate()
	add_child(workspace)

func after_each():
	workspace.free()

func test_icon_bar_exists():
	var icon_bar = workspace.get_node("%IconBar")
	assert_not_null(icon_bar, "IconBar should exist in Workspace")
	assert_true(icon_bar.visible, "IconBar should be visible")

func test_recenter_button_exists():
	var recenter_button = workspace.get_node("%RecenterButton")
	assert_not_null(recenter_button, "RecenterButton should exist in Workspace")
	assert_eq(recenter_button.text, "center_focus_strong", "RecenterButton should have correct icon text")

func test_recenter_button_functionality():
	var recenter_button = workspace.get_node("%RecenterButton")
	
	# Move canvas and change zoom
	workspace.set_canvas_zoom(0.5)
	workspace.canvas_content.position = Vector2(100, 100)
	
	# Click the button (simulate)
	recenter_button.pressed.emit()
	
	# Wait a frame because of await get_tree().process_frame in center_view
	await wait_seconds(0.1)
	
	assert_eq(workspace.get_canvas_zoom(), 1.0, "Zoom should be reset to 1.0")
	# With no figures, it should center on viewport center
	var expected_pos = workspace.canvas_area.size / 2.0
	assert_eq(workspace.canvas_content.position, expected_pos, "Canvas content should be centered")
