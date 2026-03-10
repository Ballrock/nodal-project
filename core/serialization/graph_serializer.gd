class_name GraphSerializer
extends RefCounted

## Utilitaire de sérialisation / désérialisation du graphe complet.
## Convertit l'état du graphe (figures, liens, flottes) en JSON et inversement.

const SAVE_VERSION := 1


# ── Sérialisation ─────────────────────────────────────────

## Construit un Dictionary représentant l'intégralité du graphe.
static func serialize_graph(
	figures_by_id: Dictionary,
	links_layer: LinksLayer,
	fleet_panel: FleetPanel,
	fleet_to_slot: Dictionary,
	canvas_zoom: float,
	timeline_scale: float,
) -> Dictionary:
	var data := {}
	data["version"] = SAVE_VERSION
	data["canvas_zoom"] = canvas_zoom
	data["timeline_scale"] = timeline_scale

	# Figures
	var figures_array: Array = []
	for id: StringName in figures_by_id:
		var figure: Figure = figures_by_id[id]
		var fig_dict := _figure_data_to_dict(figure.data)
		fig_dict["is_fleet_figure"] = figure.is_fleet_figure
		figures_array.append(fig_dict)
	data["figures"] = figures_array

	# Liens
	var links_array: Array = []
	for ld: LinkData in links_layer.get_all_link_data():
		links_array.append(_link_data_to_dict(ld))
	data["links"] = links_array

	# Flottes
	var fleets_array: Array = []
	for fleet: FleetData in fleet_panel.get_fleets():
		fleets_array.append(_fleet_data_to_dict(fleet))
	data["fleets"] = fleets_array

	# Mapping fleet.id → slot.id
	var mapping := {}
	for fleet_id: StringName in fleet_to_slot:
		var slot_data: SlotData = fleet_to_slot[fleet_id]
		mapping[str(fleet_id)] = str(slot_data.id)
	data["fleet_to_slot"] = mapping

	# Paramètres du projet (Scénographie)
	data["project_settings"] = SettingsManager.get_project_settings_dict()

	return data


static func _figure_data_to_dict(fd: FigureData) -> Dictionary:
	return {
		"id": str(fd.id),
		"title": fd.title,
		"position_x": fd.position.x,
		"position_y": fd.position.y,
		"color_r": fd.color.r,
		"color_g": fd.color.g,
		"color_b": fd.color.b,
		"color_a": fd.color.a,
		"start_time": fd.start_time,
		"end_time": fd.end_time,
		"track": fd.track,
		"input_slots": fd.input_slots.map(func(s: SlotData) -> Dictionary: return _slot_data_to_dict(s)),
		"output_slots": fd.output_slots.map(func(s: SlotData) -> Dictionary: return _slot_data_to_dict(s)),
	}


static func _slot_data_to_dict(sd: SlotData) -> Dictionary:
	return {
		"id": str(sd.id),
		"label": sd.label,
		"direction": sd.direction,
		"index": sd.index,
	}


static func _link_data_to_dict(ld: LinkData) -> Dictionary:
	return {
		"id": str(ld.id),
		"source_figure_id": str(ld.source_figure_id),
		"source_slot_id": str(ld.source_slot_id),
		"target_figure_id": str(ld.target_figure_id),
		"target_slot_id": str(ld.target_slot_id),
		"is_locked": ld.is_locked,
	}


static func _fleet_data_to_dict(fd: FleetData) -> Dictionary:
	return {
		"id": str(fd.id),
		"name": fd.name,
		"drone_type": fd.drone_type,
		"drone_count": fd.drone_count,
	}


# ── Désérialisation ──────────────────────────────────────

static func dict_to_figure_data(d: Dictionary) -> FigureData:
	var fd := FigureData.new()
	fd.id = StringName(str(d["id"]))
	fd.title = str(d["title"])
	fd.position = Vector2(float(d["position_x"]), float(d["position_y"]))
	fd.color = Color(
		float(d["color_r"]),
		float(d["color_g"]),
		float(d["color_b"]),
		float(d["color_a"]),
	)
	fd.start_time = float(d["start_time"])
	fd.end_time = float(d["end_time"])
	fd.track = int(d.get("track", 0))
	fd.input_slots = []
	for sd_dict: Dictionary in d.get("input_slots", []):
		fd.input_slots.append(dict_to_slot_data(sd_dict))
	fd.output_slots = []
	for sd_dict: Dictionary in d.get("output_slots", []):
		fd.output_slots.append(dict_to_slot_data(sd_dict))
	return fd


static func dict_to_slot_data(d: Dictionary) -> SlotData:
	var sd := SlotData.new()
	sd.id = StringName(str(d["id"]))
	sd.label = str(d["label"])
	sd.direction = int(d["direction"])
	sd.index = int(d["index"])
	return sd


static func dict_to_link_data(d: Dictionary) -> LinkData:
	var ld := LinkData.new()
	ld.id = StringName(str(d["id"]))
	ld.source_figure_id = StringName(str(d["source_figure_id"]))
	ld.source_slot_id = StringName(str(d["source_slot_id"]))
	ld.target_figure_id = StringName(str(d["target_figure_id"]))
	ld.target_slot_id = StringName(str(d["target_slot_id"]))
	ld.is_locked = bool(d.get("is_locked", false))
	return ld


static func dict_to_fleet_data(d: Dictionary) -> FleetData:
	var fd := FleetData.new()
	fd.id = StringName(str(d["id"]))
	fd.name = str(d["name"])
	fd.drone_type = int(d["drone_type"])
	fd.drone_count = int(d["drone_count"])
	return fd


# ── Fichier I/O ──────────────────────────────────────────

## Sauvegarde le dictionnaire sérialisé dans un fichier JSON.
static func save_to_file(path: String, data: Dictionary) -> Error:
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_string)
	file.close()
	return OK


## Charge un fichier JSON et retourne le Dictionary désérialisé.
## Retourne un Dictionary vide en cas d'erreur.
static func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("GraphSerializer: fichier introuvable — %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GraphSerializer: impossible d'ouvrir — %s" % path)
		return {}
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_error("GraphSerializer: erreur JSON ligne %d — %s" % [json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		push_error("GraphSerializer: le fichier ne contient pas un objet JSON valide.")
		return {}
	return json.data
