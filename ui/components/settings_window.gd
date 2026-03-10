# res://ui/components/settings_window.gd
extends Window

@onready var category_tree: Tree = %CategoryTree
@onready var options_container: VBoxContainer = %OptionsContainer
@onready var category_title: Label = %CategoryTitle

@onready var apply_button: Button = %ApplyButton
@onready var cancel_footer_button: Button = %CancelFooterButton

var _current_scope: SettingsManager.SettingScope = SettingsManager.SettingScope.GLOBAL
# Stocke les modifications temporaires : key -> value
var _draft_settings: Dictionary = {}

func _ready() -> void:
	visible = false
	force_native = true
	
	# Adapter le contenu au DPI de l'écran (Retina, etc.)
	content_scale_factor = DisplayServer.screen_get_scale()
	
	transient = false
	exclusive = false
	
	close_requested.connect(close)
	apply_button.pressed.connect(_on_apply_pressed)
	cancel_footer_button.pressed.connect(close)
	category_tree.item_selected.connect(_on_category_selected)

func open_global() -> void:
	_current_scope = SettingsManager.SettingScope.GLOBAL
	title = "Paramètres Logiciel"
	_prepare_draft()
	_refresh()
	popup_centered()

func open_project() -> void:
	_current_scope = SettingsManager.SettingScope.PROJECT
	title = "Paramètres Scénographie"
	_prepare_draft()
	_refresh()
	popup_centered()

func close() -> void:
	hide()
	_draft_settings.clear()

func _prepare_draft() -> void:
	_draft_settings.clear()
	var settings = SettingsManager.get_settings_by_scope(_current_scope)
	for s in settings:
		_draft_settings[s.key] = s.value

func _refresh() -> void:
	_build_category_tree()
	var root = category_tree.get_root()
	if root and root.get_child_count() > 0:
		root.get_child(0).select(0)
	else:
		for child in options_container.get_children():
			child.queue_free()
		category_title.text = ""

func _build_category_tree() -> void:
	category_tree.clear()
	var root = category_tree.create_item()
	var categories = SettingsManager.get_categories_for_scope(_current_scope)
	for cat in categories:
		var item = category_tree.create_item(root)
		item.set_text(0, cat)
		item.set_metadata(0, cat)

func _on_category_selected() -> void:
	var selected = category_tree.get_selected()
	if selected:
		var cat = selected.get_metadata(0)
		_display_category(cat)

func _display_category(category: String) -> void:
	category_title.text = category
	for child in options_container.get_children():
		child.queue_free()
	
	var settings = SettingsManager.get_settings_by_category_and_scope(category, _current_scope)
	for s in settings:
		_add_setting_ui(s)

func _add_setting_ui(setting: SettingsManager.Setting) -> void:
	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 2)
	options_container.add_child(v_box)
	
	var h_box = HBoxContainer.new()
	v_box.add_child(h_box)
	
	var label = Label.new()
	label.text = setting.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_box.add_child(label)
	
	var current_val = _draft_settings.get(setting.key, setting.default_value)
	
	match setting.type:
		SettingsManager.SettingType.BOOLEAN:
			var check = CheckBox.new()
			check.button_pressed = current_val
			check.toggled.connect(func(pressed: bool): _draft_settings[setting.key] = pressed)
			h_box.add_child(check)
			
		SettingsManager.SettingType.NUMBER:
			var spin = SpinBox.new()
			spin.value = current_val
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.custom_minimum_size.x = 100
			spin.value_changed.connect(func(val: float): _draft_settings[setting.key] = val)
			h_box.add_child(spin)
			
		SettingsManager.SettingType.STRING:
			var line_edit = LineEdit.new()
			line_edit.text = str(current_val)
			line_edit.custom_minimum_size.x = 250
			line_edit.text_changed.connect(func(new_text: String): _draft_settings[setting.key] = new_text)
			h_box.add_child(line_edit)
			
		SettingsManager.SettingType.ARRAY:
			var list_box = VBoxContainer.new()
			list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for item in current_val:
				var item_label = Label.new()
				item_label.text = "• " + str(item)
				list_box.add_child(item_label)
			v_box.add_child(list_box)
			
		SettingsManager.SettingType.JSON:
			var edit_btn = Button.new()
			edit_btn.text = "Éditer (JSON)"
			h_box.add_child(edit_btn)
			
		_:
			var val_label = Label.new()
			val_label.text = str(current_val)
			h_box.add_child(val_label)
	
	if setting.description != "":
		var desc_label = Label.new()
		desc_label.text = setting.description
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		v_box.add_child(desc_label)
	
	options_container.add_child(HSeparator.new())

func _on_apply_pressed() -> void:
	# Appliquer toutes les valeurs du draft au SettingsManager
	for key in _draft_settings:
		SettingsManager.set_setting(key, _draft_settings[key])
	close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()
