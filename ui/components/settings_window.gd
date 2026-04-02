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
# References pour la page nacelles (mise a jour dynamique)
var _nacelle_status_label: Label = null
var _nacelle_download_btn: Button = null
var _nacelle_list_container: VBoxContainer = null
var _nacelle_count_label: Label = null
var _nacelle_version_label: Label = null
# References pour la page effets pyro (mise a jour dynamique)
var _pyro_status_label: Label = null
var _pyro_download_btn: Button = null
var _pyro_list_container: VBoxContainer = null
var _pyro_count_label: Label = null
var _pyro_version_label: Label = null
# References pour les bandeaux de mise a jour
var _nacelle_update_banner: PanelContainer = null
var _pyro_update_banner: PanelContainer = null
# References pour la page payloads (mise a jour dynamique)
var _payload_status_label: Label = null
var _payload_download_btn: Button = null
var _payload_list_container: VBoxContainer = null
var _payload_count_label: Label = null
# Bandeau de mise a jour payloads
var _payload_update_banner: PanelContainer = null
# Police d'icones Material Symbols
var _icon_font: Font = null

func _ready() -> void:
	visible = false
	WindowHelper.setup_window(self)

	# Agrandir la fenêtre proportionnellement au DPI pour compenser le content_scale
	var scale := DisplayServer.screen_get_scale()
	size = Vector2i(int(900 * scale), int(600 * scale))
	min_size = Vector2i(int(900 * scale), int(550 * scale))

	_icon_font = load("res://assets/fonts/material_symbols_rounded.ttf")

	close_requested.connect(close)
	apply_button.pressed.connect(_on_apply_pressed)
	cancel_footer_button.pressed.connect(close)
	category_tree.item_selected.connect(_on_category_selected)

func open_global() -> void:
	_current_scope = SettingsManager.SettingScope.GLOBAL
	title = "Paramètres Logiciel"
	_prepare_draft()
	_refresh()
	WindowHelper.bind_backdrop(get_tree().root.get_window(), self)
	WindowHelper.popup_fitted(self, 0.85, false)

func open_project() -> void:
	_current_scope = SettingsManager.SettingScope.PROJECT
	title = "Paramètres Scénographie"
	_prepare_draft()
	_refresh()
	WindowHelper.bind_backdrop(get_tree().root.get_window(), self)
	WindowHelper.popup_fitted(self, 0.85, false)

func close() -> void:
	hide()
	_draft_settings.clear()
	_disconnect_nacelle_signals()
	_disconnect_pyro_signals()
	_disconnect_payload_signals()

func _prepare_draft() -> void:
	_draft_settings.clear()
	var settings = SettingsManager.get_settings_by_scope(_current_scope)
	for s in settings:
		_draft_settings[s.key] = s.value

func _refresh() -> void:
	_build_category_tree()
	var first = _find_first_selectable()
	if first:
		first.select(0)
	else:
		for child in options_container.get_children():
			child.queue_free()
		category_title.text = ""

func _find_first_selectable() -> TreeItem:
	var root = category_tree.get_root()
	if not root:
		return null
	var l1 = root.get_first_child()
	while l1:
		if l1.is_selectable(0):
			return l1
		var l2 = l1.get_first_child()
		if l2:
			return l2
		l1 = l1.get_next()
	return null

func _build_category_tree() -> void:
	category_tree.clear()
	var root = category_tree.create_item()
	var tree = SettingsManager.get_category_tree_for_scope(_current_scope)
	for entry in tree:
		var l1_item = category_tree.create_item(root)
		l1_item.set_text(0, entry["name"])
		if entry["children"].size() > 0:
			# Parent non-sélectionnable avec enfants
			l1_item.set_selectable(0, false)
			l1_item.set_custom_color(0, Color(0.85, 0.85, 0.85))
			for child_name: String in entry["children"]:
				var l2_item = category_tree.create_item(l1_item)
				l2_item.set_text(0, child_name)
				l2_item.set_metadata(0, entry["name"] + "/" + child_name)
		else:
			# Catégorie plate (pas d'enfants) — sélectionnable directement
			l1_item.set_metadata(0, entry["name"])

func _on_category_selected() -> void:
	var selected = category_tree.get_selected()
	if selected:
		var cat = selected.get_metadata(0)
		_display_category(cat)

func _display_category(category: String) -> void:
	# Afficher le nom court (partie après "/") comme titre
	var display_name := category
	var slash_pos := category.rfind("/")
	if slash_pos >= 0:
		display_name = category.substr(slash_pos + 1)
	category_title.text = display_name

	_disconnect_nacelle_signals()
	_disconnect_pyro_signals()
	_disconnect_payload_signals()
	for child in options_container.get_children():
		child.queue_free()

	# Rendu personnalise pour la categorie Nacelles
	if category == "Base de données/Nacelles" and _current_scope == SettingsManager.SettingScope.GLOBAL:
		_display_nacelles_category()
		return

	# Rendu personnalise pour la categorie Effets Pyro
	if category == "Base de données/Effets" and _current_scope == SettingsManager.SettingScope.GLOBAL:
		_display_pyro_effects_category()
		return

	# Rendu personnalise pour la categorie Payloads
	if category == "Base de données/Payloads" and _current_scope == SettingsManager.SettingScope.GLOBAL:
		_display_payloads_category()
		return

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
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		v_box.add_child(desc_label)

	options_container.add_child(HSeparator.new())


# --- Bandeau de mise a jour ---

func _create_update_banner(message: String) -> PanelContainer:
	# Le bandeau est un PanelContainer qui s'etend sur toute la largeur
	var banner := PanelContainer.new()
	banner.visible = false
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Fond jaune semi-transparent avec bordure gauche
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.65, 0.13, 0.15)
	style.border_color = Color(0.85, 0.65, 0.13, 0.6)
	style.border_width_left = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	banner.add_theme_stylebox_override("panel", style)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	banner.add_child(inner)

	# Icone warning via Material Symbols
	var icon_label := Label.new()
	icon_label.text = "warning"
	if _icon_font:
		icon_label.add_theme_font_override("font", _icon_font)
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.13))
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(icon_label)

	# Message
	var msg_label := Label.new()
	msg_label.text = message
	msg_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.13))
	msg_label.add_theme_font_size_override("font_size", 13)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(msg_label)

	return banner


# --- Affichage personnalise de la categorie Nacelles ---

func _display_nacelles_category() -> void:
	# Bandeau de mise a jour
	_nacelle_update_banner = _create_update_banner("Une nouvelle version des nacelles est disponible. Cliquez sur \"Telecharger\" pour mettre a jour.")
	options_container.add_child(_nacelle_update_banner)

	# Verifier si une mise a jour est deja connue
	if NacelleManager.is_update_available():
		_nacelle_update_banner.visible = true

	# Lancer la verification en arriere-plan
	if not NacelleManager.update_check_completed.is_connected(_on_nacelle_update_check):
		NacelleManager.update_check_completed.connect(_on_nacelle_update_check)
	if not NacelleManager.update_check_failed.is_connected(_on_nacelle_update_check_failed):
		NacelleManager.update_check_failed.connect(_on_nacelle_update_check_failed)
	NacelleManager.check_for_update()

	# Section : Informations et telechargement
	var info_section := VBoxContainer.new()
	info_section.add_theme_constant_override("separation", 10)
	options_container.add_child(info_section)

	# Derniere mise a jour
	var last_dl_box := HBoxContainer.new()
	info_section.add_child(last_dl_box)

	var last_dl_label := Label.new()
	last_dl_label.text = "Dernier telechargement :"
	last_dl_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last_dl_box.add_child(last_dl_label)

	_nacelle_status_label = Label.new()
	_nacelle_status_label.text = NacelleManager.get_last_download_date_formatted()
	_nacelle_status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	last_dl_box.add_child(_nacelle_status_label)

	# Version du fichier
	var version_box := HBoxContainer.new()
	info_section.add_child(version_box)

	var version_title := Label.new()
	version_title.text = "Date du fichier :"
	version_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_box.add_child(version_title)

	_nacelle_version_label = Label.new()
	_nacelle_version_label.text = NacelleManager.get_file_version_date()
	_nacelle_version_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	version_box.add_child(_nacelle_version_label)

	# Nombre de nacelles
	var count_box := HBoxContainer.new()
	info_section.add_child(count_box)

	var count_title := Label.new()
	count_title.text = "Nacelles disponibles :"
	count_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_box.add_child(count_title)

	_nacelle_count_label = Label.new()
	_nacelle_count_label.text = str(NacelleManager.get_nacelle_count())
	_nacelle_count_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	count_box.add_child(_nacelle_count_label)

	# Bouton Telecharger
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	info_section.add_child(btn_box)

	_nacelle_download_btn = Button.new()
	_nacelle_download_btn.text = "Telecharger la derniere version"
	_nacelle_download_btn.pressed.connect(_on_nacelle_download_pressed)
	if NacelleManager.is_downloading():
		_nacelle_download_btn.text = "Telechargement en cours..."
		_nacelle_download_btn.disabled = true
	btn_box.add_child(_nacelle_download_btn)

	options_container.add_child(HSeparator.new())

	# Section : Liste des nacelles
	var list_header := Label.new()
	list_header.text = "Liste des nacelles"
	list_header.add_theme_font_size_override("font_size", 16)
	options_container.add_child(list_header)

	_nacelle_list_container = VBoxContainer.new()
	_nacelle_list_container.add_theme_constant_override("separation", 4)
	options_container.add_child(_nacelle_list_container)

	_populate_nacelle_list()

	# Connecter les signaux du NacelleManager
	_connect_nacelle_signals()


func _populate_nacelle_list() -> void:
	if not _nacelle_list_container:
		return
	for child in _nacelle_list_container.get_children():
		child.queue_free()

	var nacelles := NacelleManager.get_nacelles()

	if nacelles.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucune nacelle disponible. Cliquez sur \"Telecharger\" pour recuperer la liste."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_nacelle_list_container.add_child(empty_label)
		return

	for n: NacelleDefinition in nacelles:
		var row := _create_nacelle_row(n)
		_nacelle_list_container.add_child(row)
		_nacelle_list_container.add_child(HSeparator.new())


func _create_nacelle_row(n: NacelleDefinition) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Ligne 1 : Nom + Type drone
	var line1 := HBoxContainer.new()
	vbox.add_child(line1)

	var name_label := Label.new()
	name_label.text = n.name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line1.add_child(name_label)

	if not n.type_drone.is_empty():
		var type_label := Label.new()
		type_label.text = n.type_drone
		var type_color := Color(0.29, 0.56, 0.85) if n.type_drone.to_upper() == "RIFF" else Color(0.49, 0.78, 0.89)
		type_label.add_theme_color_override("font_color", type_color)
		line1.add_child(type_label)

	# Ligne 2 : Details
	var details_parts: PackedStringArray = []
	if not n.mount_type.is_empty():
		details_parts.append("Montage: %s" % n.get_mount_type_label())
	if n.weight > 0:
		details_parts.append("Poids: %dg" % n.weight)
	if n.effect_count > 0:
		details_parts.append("Effets: %d" % n.effect_count)

	if not details_parts.is_empty():
		var details_label := Label.new()
		details_label.text = " | ".join(details_parts)
		details_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		details_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(details_label)

	# Section depliable : Channels / Effets
	if not n.effects.is_empty():
		var channels_container := VBoxContainer.new()
		channels_container.add_theme_constant_override("separation", 2)
		channels_container.visible = false
		vbox.add_child(channels_container)

		# Toggle button
		var toggle_btn := Button.new()
		toggle_btn.text = "▶ Channels (%d)" % n.effects.size()
		toggle_btn.flat = true
		toggle_btn.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
		toggle_btn.add_theme_font_size_override("font_size", 12)
		toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Insert toggle before the channels container
		vbox.move_child(channels_container, vbox.get_child_count() - 1)
		vbox.add_child(toggle_btn)
		vbox.move_child(toggle_btn, channels_container.get_index())
		vbox.move_child(channels_container, toggle_btn.get_index() + 1)

		toggle_btn.pressed.connect(func():
			channels_container.visible = not channels_container.visible
			if channels_container.visible:
				toggle_btn.text = "▼ Channels (%d)" % n.effects.size()
			else:
				toggle_btn.text = "▶ Channels (%d)" % n.effects.size()
		)

		# Header des colonnes
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		channels_container.add_child(header)

		var h_ch := Label.new()
		h_ch.text = "Channel"
		h_ch.custom_minimum_size.x = 70
		h_ch.add_theme_font_size_override("font_size", 11)
		h_ch.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		header.add_child(h_ch)

		var h_ah := Label.new()
		h_ah.text = "Angle H"
		h_ah.custom_minimum_size.x = 80
		h_ah.add_theme_font_size_override("font_size", 11)
		h_ah.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		header.add_child(h_ah)

		var h_ap := Label.new()
		h_ap.text = "Angle P"
		h_ap.custom_minimum_size.x = 80
		h_ap.add_theme_font_size_override("font_size", 11)
		h_ap.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		header.add_child(h_ap)

		var sep := HSeparator.new()
		channels_container.add_child(sep)

		# Lignes des channels
		for effect in n.effects:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			channels_container.add_child(row)

			var ch_label := Label.new()
			ch_label.text = "Ch %d" % int(effect.get("channel", 0))
			ch_label.custom_minimum_size.x = 70
			ch_label.add_theme_font_size_override("font_size", 12)
			ch_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			row.add_child(ch_label)

			var ah_label := Label.new()
			ah_label.text = "%.1f°" % float(effect.get("angleH", 0.0))
			ah_label.custom_minimum_size.x = 80
			ah_label.add_theme_font_size_override("font_size", 12)
			ah_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
			row.add_child(ah_label)

			var ap_label := Label.new()
			ap_label.text = "%.1f°" % float(effect.get("angleP", 0.0))
			ap_label.custom_minimum_size.x = 80
			ap_label.add_theme_font_size_override("font_size", 12)
			ap_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
			row.add_child(ap_label)

	return panel


func _on_nacelle_download_pressed() -> void:
	if _nacelle_download_btn:
		_nacelle_download_btn.text = "Telechargement en cours..."
		_nacelle_download_btn.disabled = true
	NacelleManager.download_nacelles()


func _connect_nacelle_signals() -> void:
	if not NacelleManager.nacelles_loaded.is_connected(_on_nacelles_updated):
		NacelleManager.nacelles_loaded.connect(_on_nacelles_updated)
	if not NacelleManager.nacelles_download_failed.is_connected(_on_nacelles_download_failed):
		NacelleManager.nacelles_download_failed.connect(_on_nacelles_download_failed)
	if not NacelleManager.download_finished.is_connected(_on_download_finished):
		NacelleManager.download_finished.connect(_on_download_finished)


func _disconnect_nacelle_signals() -> void:
	if NacelleManager.nacelles_loaded.is_connected(_on_nacelles_updated):
		NacelleManager.nacelles_loaded.disconnect(_on_nacelles_updated)
	if NacelleManager.nacelles_download_failed.is_connected(_on_nacelles_download_failed):
		NacelleManager.nacelles_download_failed.disconnect(_on_nacelles_download_failed)
	if NacelleManager.download_finished.is_connected(_on_download_finished):
		NacelleManager.download_finished.disconnect(_on_download_finished)
	if NacelleManager.update_check_completed.is_connected(_on_nacelle_update_check):
		NacelleManager.update_check_completed.disconnect(_on_nacelle_update_check)
	if NacelleManager.update_check_failed.is_connected(_on_nacelle_update_check_failed):
		NacelleManager.update_check_failed.disconnect(_on_nacelle_update_check_failed)


func _on_nacelle_update_check(update_available: bool) -> void:
	if _nacelle_update_banner:
		_nacelle_update_banner.visible = update_available


func _on_nacelle_update_check_failed() -> void:
	# En cas d'echec de verification, ne rien afficher
	pass


func _on_nacelles_updated() -> void:
	if _nacelle_status_label:
		_nacelle_status_label.text = NacelleManager.get_last_download_date_formatted()
	if _nacelle_version_label:
		_nacelle_version_label.text = NacelleManager.get_file_version_date()
	if _nacelle_count_label:
		_nacelle_count_label.text = str(NacelleManager.get_nacelle_count())
	if _nacelle_update_banner:
		_nacelle_update_banner.visible = false
	_populate_nacelle_list()


func _on_nacelles_download_failed(error_msg: String) -> void:
	if _nacelle_status_label:
		_nacelle_status_label.text = "Erreur: %s" % error_msg
		_nacelle_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _on_download_finished() -> void:
	if _nacelle_download_btn:
		_nacelle_download_btn.text = "Telecharger la derniere version"
		_nacelle_download_btn.disabled = false


func _on_apply_pressed() -> void:
	# Appliquer toutes les valeurs du draft au SettingsManager
	for key in _draft_settings:
		SettingsManager.set_setting(key, _draft_settings[key])
	close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


# --- Affichage personnalise de la categorie Effets Pyro ---

func _display_pyro_effects_category() -> void:
	# Bandeau de mise a jour
	_pyro_update_banner = _create_update_banner("Une nouvelle version des effets pyro est disponible. Cliquez sur \"Telecharger\" pour mettre a jour.")
	options_container.add_child(_pyro_update_banner)

	# Verifier si une mise a jour est deja connue
	if PyroEffectManager.is_update_available():
		_pyro_update_banner.visible = true

	# Lancer la verification en arriere-plan
	if not PyroEffectManager.update_check_completed.is_connected(_on_pyro_update_check):
		PyroEffectManager.update_check_completed.connect(_on_pyro_update_check)
	if not PyroEffectManager.update_check_failed.is_connected(_on_pyro_update_check_failed):
		PyroEffectManager.update_check_failed.connect(_on_pyro_update_check_failed)
	PyroEffectManager.check_for_update()

	# Section : Informations et telechargement
	var info_section := VBoxContainer.new()
	info_section.add_theme_constant_override("separation", 10)
	options_container.add_child(info_section)

	# Derniere mise a jour
	var last_dl_box := HBoxContainer.new()
	info_section.add_child(last_dl_box)

	var last_dl_label := Label.new()
	last_dl_label.text = "Dernier telechargement :"
	last_dl_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last_dl_box.add_child(last_dl_label)

	_pyro_status_label = Label.new()
	_pyro_status_label.text = PyroEffectManager.get_last_download_date_formatted()
	_pyro_status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	last_dl_box.add_child(_pyro_status_label)

	# Version du fichier
	var version_box := HBoxContainer.new()
	info_section.add_child(version_box)

	var version_title := Label.new()
	version_title.text = "Date du fichier :"
	version_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_box.add_child(version_title)

	_pyro_version_label = Label.new()
	_pyro_version_label.text = PyroEffectManager.get_file_version_date()
	_pyro_version_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	version_box.add_child(_pyro_version_label)

	# Nombre d'effets
	var count_box := HBoxContainer.new()
	info_section.add_child(count_box)

	var count_title := Label.new()
	count_title.text = "Effets disponibles :"
	count_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_box.add_child(count_title)

	_pyro_count_label = Label.new()
	_pyro_count_label.text = str(PyroEffectManager.get_pyro_effect_count())
	_pyro_count_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	count_box.add_child(_pyro_count_label)

	# Bouton Telecharger
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	info_section.add_child(btn_box)

	_pyro_download_btn = Button.new()
	_pyro_download_btn.text = "Telecharger la derniere version"
	_pyro_download_btn.pressed.connect(_on_pyro_download_pressed)
	if PyroEffectManager.is_downloading():
		_pyro_download_btn.text = "Telechargement en cours..."
		_pyro_download_btn.disabled = true
	btn_box.add_child(_pyro_download_btn)

	options_container.add_child(HSeparator.new())

	# Section : Liste des effets
	var list_header := Label.new()
	list_header.text = "Liste des effets pyrotechniques"
	list_header.add_theme_font_size_override("font_size", 16)
	options_container.add_child(list_header)

	_pyro_list_container = VBoxContainer.new()
	_pyro_list_container.add_theme_constant_override("separation", 4)
	options_container.add_child(_pyro_list_container)

	_populate_pyro_effects_list()

	# Connecter les signaux du PyroEffectManager
	_connect_pyro_signals()


func _populate_pyro_effects_list() -> void:
	if not _pyro_list_container:
		return
	for child in _pyro_list_container.get_children():
		child.queue_free()

	var effects := PyroEffectManager.get_pyro_effects()

	if effects.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucun effet disponible. Cliquez sur \"Telecharger\" pour recuperer la liste."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pyro_list_container.add_child(empty_label)
		return

	# Grouper les effets par type
	var groups: Dictionary = {}
	for e: PyroEffectDefinition in effects:
		var t := e.type.strip_edges()
		if t.is_empty():
			t = "Autre"
		if not groups.has(t):
			groups[t] = []
		groups[t].append(e)

	var sorted_types: Array = groups.keys()
	sorted_types.sort()

	for type_name: String in sorted_types:
		# En-tete de groupe
		var group_label := Label.new()
		group_label.text = "%s (%d)" % [type_name, groups[type_name].size()]
		group_label.add_theme_font_size_override("font_size", 14)
		group_label.add_theme_color_override("font_color", Color(0.9, 0.65, 0.3))
		_pyro_list_container.add_child(group_label)

		for e: PyroEffectDefinition in groups[type_name]:
			var row := _create_pyro_effect_row(e)
			_pyro_list_container.add_child(row)
			_pyro_list_container.add_child(HSeparator.new())


func _create_pyro_effect_row(e: PyroEffectDefinition) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Ligne 1 : Nom + Fabricant
	var line1 := HBoxContainer.new()
	vbox.add_child(line1)

	var name_label := Label.new()
	name_label.text = e.name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line1.add_child(name_label)

	if not e.fabricant.is_empty():
		var fab_label := Label.new()
		fab_label.text = e.fabricant
		fab_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		fab_label.add_theme_font_size_override("font_size", 12)
		line1.add_child(fab_label)

	# Ligne 2 : Caractéristiques principales
	var details_parts: PackedStringArray = []
	if not e.calibre.is_empty():
		details_parts.append("Calibre: %s" % e.calibre)
	if e.duree > 0.0:
		details_parts.append("Durée: %.1fs" % e.duree)
	if e.hauteur_effet > 0.0:
		details_parts.append("Hauteur: %.0fm" % e.hauteur_effet)
	if e.poids > 0.0:
		details_parts.append("Poids: %.0fg" % e.poids)

	if not details_parts.is_empty():
		var details_label := Label.new()
		details_label.text = " | ".join(details_parts)
		details_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		details_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(details_label)

	# Section depliable : Informations techniques
	var has_details := (e.distance_securite_verticale > 0.0 or e.distance_securite_horizontale > 0.0
		or e.largeur_effet > 0.0 or not e.code_onu.is_empty()
		or not e.categorie.is_empty() or not e.classe.is_empty())

	if has_details:
		var details_container := VBoxContainer.new()
		details_container.add_theme_constant_override("separation", 2)
		details_container.visible = false
		vbox.add_child(details_container)

		var toggle_btn := Button.new()
		toggle_btn.text = "▶ Détails techniques"
		toggle_btn.flat = true
		toggle_btn.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
		toggle_btn.add_theme_font_size_override("font_size", 12)
		toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		vbox.add_child(toggle_btn)
		vbox.move_child(toggle_btn, details_container.get_index())
		vbox.move_child(details_container, toggle_btn.get_index() + 1)

		toggle_btn.pressed.connect(func():
			details_container.visible = not details_container.visible
			toggle_btn.text = "▼ Détails techniques" if details_container.visible else "▶ Détails techniques"
		)

		var tech_parts: PackedStringArray = []
		if e.distance_securite_verticale > 0.0:
			tech_parts.append("Sécu. verticale: %.0fm" % e.distance_securite_verticale)
		if e.distance_securite_horizontale > 0.0:
			tech_parts.append("Sécu. horizontale: %.0fm" % e.distance_securite_horizontale)
		if e.largeur_effet > 0.0:
			tech_parts.append("Largeur effet: %.0fm" % e.largeur_effet)
		if not e.code_onu.is_empty():
			tech_parts.append("Code ONU: %s" % e.code_onu)
		if not e.categorie.is_empty():
			tech_parts.append("Catégorie: %s" % e.categorie)
		if not e.classe.is_empty():
			tech_parts.append("Classe: %s" % e.classe)

		for part in tech_parts:
			var tech_label := Label.new()
			tech_label.text = "  • " + part
			tech_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
			tech_label.add_theme_font_size_override("font_size", 12)
			details_container.add_child(tech_label)

	return panel


func _on_pyro_download_pressed() -> void:
	if _pyro_download_btn:
		_pyro_download_btn.text = "Telechargement en cours..."
		_pyro_download_btn.disabled = true
	PyroEffectManager.download_pyro_effects()


func _connect_pyro_signals() -> void:
	if not PyroEffectManager.pyro_effects_loaded.is_connected(_on_pyro_effects_updated):
		PyroEffectManager.pyro_effects_loaded.connect(_on_pyro_effects_updated)
	if not PyroEffectManager.pyro_effects_download_failed.is_connected(_on_pyro_download_failed):
		PyroEffectManager.pyro_effects_download_failed.connect(_on_pyro_download_failed)
	if not PyroEffectManager.download_finished.is_connected(_on_pyro_download_finished):
		PyroEffectManager.download_finished.connect(_on_pyro_download_finished)


func _disconnect_pyro_signals() -> void:
	if PyroEffectManager.pyro_effects_loaded.is_connected(_on_pyro_effects_updated):
		PyroEffectManager.pyro_effects_loaded.disconnect(_on_pyro_effects_updated)
	if PyroEffectManager.pyro_effects_download_failed.is_connected(_on_pyro_download_failed):
		PyroEffectManager.pyro_effects_download_failed.disconnect(_on_pyro_download_failed)
	if PyroEffectManager.download_finished.is_connected(_on_pyro_download_finished):
		PyroEffectManager.download_finished.disconnect(_on_pyro_download_finished)
	if PyroEffectManager.update_check_completed.is_connected(_on_pyro_update_check):
		PyroEffectManager.update_check_completed.disconnect(_on_pyro_update_check)
	if PyroEffectManager.update_check_failed.is_connected(_on_pyro_update_check_failed):
		PyroEffectManager.update_check_failed.disconnect(_on_pyro_update_check_failed)


func _on_pyro_update_check(update_available: bool) -> void:
	if _pyro_update_banner:
		_pyro_update_banner.visible = update_available


func _on_pyro_update_check_failed() -> void:
	# En cas d'echec de verification, ne rien afficher
	pass


func _on_pyro_effects_updated() -> void:
	if _pyro_status_label:
		_pyro_status_label.text = PyroEffectManager.get_last_download_date_formatted()
	if _pyro_version_label:
		_pyro_version_label.text = PyroEffectManager.get_file_version_date()
	if _pyro_count_label:
		_pyro_count_label.text = str(PyroEffectManager.get_pyro_effect_count())
	if _pyro_update_banner:
		_pyro_update_banner.visible = false
	_populate_pyro_effects_list()


func _on_pyro_download_failed(error_msg: String) -> void:
	if _pyro_status_label:
		_pyro_status_label.text = "Erreur: %s" % error_msg
		_pyro_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _on_pyro_download_finished() -> void:
	if _pyro_download_btn:
		_pyro_download_btn.text = "Telecharger la derniere version"
		_pyro_download_btn.disabled = false


# --- Affichage personnalise de la categorie Payloads ---

func _display_payloads_category() -> void:
	# Bandeau de mise a jour
	_payload_update_banner = _create_update_banner("Une nouvelle version des payloads est disponible. Cliquez sur \"Telecharger\" pour mettre a jour.")
	options_container.add_child(_payload_update_banner)

	# Verifier si une mise a jour est deja connue
	if PayloadManager.is_update_available():
		_payload_update_banner.visible = true

	# Lancer la verification en arriere-plan
	if not PayloadManager.update_check_completed.is_connected(_on_payload_update_check):
		PayloadManager.update_check_completed.connect(_on_payload_update_check)
	if not PayloadManager.update_check_failed.is_connected(_on_payload_update_check_failed):
		PayloadManager.update_check_failed.connect(_on_payload_update_check_failed)
	PayloadManager.check_for_update()

	# Section : Informations et telechargement
	var info_section := VBoxContainer.new()
	info_section.add_theme_constant_override("separation", 10)
	options_container.add_child(info_section)

	# Derniere mise a jour
	var last_dl_box := HBoxContainer.new()
	info_section.add_child(last_dl_box)

	var last_dl_label := Label.new()
	last_dl_label.text = "Dernier telechargement :"
	last_dl_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last_dl_box.add_child(last_dl_label)

	_payload_status_label = Label.new()
	_payload_status_label.text = PayloadManager.get_last_download_date_formatted()
	_payload_status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	last_dl_box.add_child(_payload_status_label)

	# Nombre de payloads
	var count_box := HBoxContainer.new()
	info_section.add_child(count_box)

	var count_title := Label.new()
	count_title.text = "Payloads disponibles :"
	count_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_box.add_child(count_title)

	_payload_count_label = Label.new()
	_payload_count_label.text = str(PayloadManager.get_payload_count())
	_payload_count_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	count_box.add_child(_payload_count_label)

	# Bouton Telecharger
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	info_section.add_child(btn_box)

	_payload_download_btn = Button.new()
	_payload_download_btn.text = "Telecharger la derniere version"
	_payload_download_btn.pressed.connect(_on_payload_download_pressed)
	if PayloadManager.is_downloading():
		_payload_download_btn.text = "Telechargement en cours..."
		_payload_download_btn.disabled = true
	btn_box.add_child(_payload_download_btn)

	options_container.add_child(HSeparator.new())

	# Section : Liste des payloads
	var list_header := Label.new()
	list_header.text = "Liste des payloads"
	list_header.add_theme_font_size_override("font_size", 16)
	options_container.add_child(list_header)

	_payload_list_container = VBoxContainer.new()
	_payload_list_container.add_theme_constant_override("separation", 4)
	options_container.add_child(_payload_list_container)

	_populate_payload_list()

	# Connecter les signaux du PayloadManager
	_connect_payload_signals()


func _populate_payload_list() -> void:
	if not _payload_list_container:
		return
	for child in _payload_list_container.get_children():
		child.queue_free()

	var payloads := PayloadManager.get_payloads()

	if payloads.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucun payload disponible. Cliquez sur \"Telecharger\" pour recuperer la liste."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_payload_list_container.add_child(empty_label)
		return

	for p: PayloadDefinition in payloads:
		var row := _create_payload_row(p)
		_payload_list_container.add_child(row)
		_payload_list_container.add_child(HSeparator.new())


func _create_payload_row(p: PayloadDefinition) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Ligne 1 : Nom + Compatibilite drones
	var line1 := HBoxContainer.new()
	vbox.add_child(line1)

	var name_label := Label.new()
	name_label.text = p.name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line1.add_child(name_label)

	# Badges de compatibilite drone
	if p.actif_riff:
		var riff_label := Label.new()
		riff_label.text = "RIFF"
		riff_label.add_theme_color_override("font_color", Color(0.29, 0.56, 0.85))
		riff_label.add_theme_font_size_override("font_size", 12)
		line1.add_child(riff_label)
	if p.actif_emo:
		var emo_label := Label.new()
		emo_label.text = "EMO"
		emo_label.add_theme_color_override("font_color", Color(0.49, 0.78, 0.89))
		emo_label.add_theme_font_size_override("font_size", 12)
		line1.add_child(emo_label)
	if not p.actif_riff and not p.actif_emo:
		var none_label := Label.new()
		none_label.text = "Aucun drone"
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		none_label.add_theme_font_size_override("font_size", 12)
		line1.add_child(none_label)

	# Ligne 2 : Commentaire (si present)
	if not p.commentaire.is_empty():
		var comment_label := Label.new()
		comment_label.text = p.commentaire
		comment_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		comment_label.add_theme_font_size_override("font_size", 12)
		comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(comment_label)

	return panel


func _on_payload_download_pressed() -> void:
	if _payload_download_btn:
		_payload_download_btn.text = "Telechargement en cours..."
		_payload_download_btn.disabled = true
	PayloadManager.download_payloads()


func _connect_payload_signals() -> void:
	if not PayloadManager.payloads_loaded.is_connected(_on_payloads_updated):
		PayloadManager.payloads_loaded.connect(_on_payloads_updated)
	if not PayloadManager.payloads_download_failed.is_connected(_on_payloads_download_failed):
		PayloadManager.payloads_download_failed.connect(_on_payloads_download_failed)
	if not PayloadManager.download_finished.is_connected(_on_payload_download_finished):
		PayloadManager.download_finished.connect(_on_payload_download_finished)


func _disconnect_payload_signals() -> void:
	if PayloadManager.payloads_loaded.is_connected(_on_payloads_updated):
		PayloadManager.payloads_loaded.disconnect(_on_payloads_updated)
	if PayloadManager.payloads_download_failed.is_connected(_on_payloads_download_failed):
		PayloadManager.payloads_download_failed.disconnect(_on_payloads_download_failed)
	if PayloadManager.download_finished.is_connected(_on_payload_download_finished):
		PayloadManager.download_finished.disconnect(_on_payload_download_finished)
	if PayloadManager.update_check_completed.is_connected(_on_payload_update_check):
		PayloadManager.update_check_completed.disconnect(_on_payload_update_check)
	if PayloadManager.update_check_failed.is_connected(_on_payload_update_check_failed):
		PayloadManager.update_check_failed.disconnect(_on_payload_update_check_failed)


func _on_payload_update_check(update_available: bool) -> void:
	if _payload_update_banner:
		_payload_update_banner.visible = update_available


func _on_payload_update_check_failed() -> void:
	pass


func _on_payloads_updated() -> void:
	if _payload_status_label:
		_payload_status_label.text = PayloadManager.get_last_download_date_formatted()
	if _payload_count_label:
		_payload_count_label.text = str(PayloadManager.get_payload_count())
	if _payload_update_banner:
		_payload_update_banner.visible = false
	_populate_payload_list()


func _on_payloads_download_failed(error_msg: String) -> void:
	if _payload_status_label:
		_payload_status_label.text = "Erreur: %s" % error_msg
		_payload_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _on_payload_download_finished() -> void:
	if _payload_download_btn:
		_payload_download_btn.text = "Telecharger la derniere version"
		_payload_download_btn.disabled = false
