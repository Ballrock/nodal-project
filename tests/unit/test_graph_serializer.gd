extends GutTest

## Tests unitaires pour GraphSerializer (sérialisation / désérialisation).


# ── Helpers ──────────────────────────────────────────────────

func _make_figure_data(title: String = "Test", inputs: int = 1, outputs: int = 1) -> FigureData:
	return FigureData.create(title, Vector2(100, 200), inputs, outputs, 1.0, 3.0, 0)


func _make_link_data(src_fig: FigureData, src_slot: SlotData, tgt_fig: FigureData, tgt_slot: SlotData) -> LinkData:
	return LinkData.create(src_fig.id, src_slot.id, tgt_fig.id, tgt_slot.id)


func _make_fleet_data(name: String = "Fleet1") -> FleetData:
	return FleetData.create(name, FleetData.DroneType.DRONE_RIFF, 5)


# ── SlotData round-trip ──────────────────────────────────────

func test_slot_data_round_trip() -> void:
	var slot := SlotData.create("input_0", SlotData.Direction.SLOT_INPUT, 0)
	var dict := {
		"id": str(slot.id),
		"label": slot.label,
		"direction": slot.direction,
		"index": slot.index,
	}
	var restored := GraphSerializer.dict_to_slot_data(dict)
	assert_eq(restored.id, slot.id, "id préservé")
	assert_eq(restored.label, slot.label, "label préservé")
	assert_eq(restored.direction, slot.direction, "direction préservée")
	assert_eq(restored.index, slot.index, "index préservé")


# ── FigureData round-trip ────────────────────────────────────

func test_figure_data_round_trip() -> void:
	var fig := _make_figure_data("RoundTrip", 2, 3)
	fig.color = Color(0.5, 0.6, 0.7, 1.0)

	# Sérialise manuellement (imite _figure_data_to_dict via serialize_graph)
	var dict := {
		"id": str(fig.id),
		"title": fig.title,
		"position_x": fig.position.x,
		"position_y": fig.position.y,
		"color_r": fig.color.r,
		"color_g": fig.color.g,
		"color_b": fig.color.b,
		"color_a": fig.color.a,
		"start_time": fig.start_time,
		"end_time": fig.end_time,
		"track": fig.track,
		"input_slots": [],
		"output_slots": [],
	}
	for s in fig.input_slots:
		dict["input_slots"].append({"id": str(s.id), "label": s.label, "direction": s.direction, "index": s.index})
	for s in fig.output_slots:
		dict["output_slots"].append({"id": str(s.id), "label": s.label, "direction": s.direction, "index": s.index})

	var restored := GraphSerializer.dict_to_figure_data(dict)
	assert_eq(restored.id, fig.id)
	assert_eq(restored.title, "RoundTrip")
	assert_eq(restored.position, fig.position)
	assert_almost_eq(restored.color.r, fig.color.r, 0.001)
	assert_almost_eq(restored.color.g, fig.color.g, 0.001)
	assert_almost_eq(restored.color.b, fig.color.b, 0.001)
	assert_eq(restored.start_time, fig.start_time)
	assert_eq(restored.end_time, fig.end_time)
	assert_eq(restored.input_slots.size(), 2)
	assert_eq(restored.output_slots.size(), 3)
	assert_eq(restored.input_slots[0].id, fig.input_slots[0].id)
	assert_eq(restored.output_slots[1].id, fig.output_slots[1].id)


# ── LinkData round-trip ──────────────────────────────────────

func test_link_data_round_trip() -> void:
	var fig_a := _make_figure_data("A", 1, 1)
	var fig_b := _make_figure_data("B", 1, 1)
	var link := _make_link_data(fig_a, fig_a.output_slots[0], fig_b, fig_b.input_slots[0])

	var dict := {
		"id": str(link.id),
		"source_figure_id": str(link.source_figure_id),
		"source_slot_id": str(link.source_slot_id),
		"target_figure_id": str(link.target_figure_id),
		"target_slot_id": str(link.target_slot_id),
	}
	var restored := GraphSerializer.dict_to_link_data(dict)
	assert_eq(restored.id, link.id)
	assert_eq(restored.source_figure_id, link.source_figure_id)
	assert_eq(restored.source_slot_id, link.source_slot_id)
	assert_eq(restored.target_figure_id, link.target_figure_id)
	assert_eq(restored.target_slot_id, link.target_slot_id)


# ── FleetData round-trip ─────────────────────────────────────

func test_fleet_data_round_trip() -> void:
	var fleet := _make_fleet_data("Drone Squad")
	fleet.drone_type = FleetData.DroneType.DRONE_EMO
	fleet.drone_count = 12

	var dict := {
		"id": str(fleet.id),
		"name": fleet.name,
		"drone_type": fleet.drone_type,
		"drone_count": fleet.drone_count,
	}
	var restored := GraphSerializer.dict_to_fleet_data(dict)
	assert_eq(restored.id, fleet.id)
	assert_eq(restored.name, "Drone Squad")
	assert_eq(restored.drone_type, FleetData.DroneType.DRONE_EMO)
	assert_eq(restored.drone_count, 12)


# ── File I/O ─────────────────────────────────────────────────

func test_save_and_load_file() -> void:
	var path := "user://test_serializer_tmp.json"
	var data := {"version": 1, "test_key": "test_value", "number": 42}

	var err := GraphSerializer.save_to_file(path, data)
	assert_eq(err, OK, "La sauvegarde doit réussir")

	var loaded := GraphSerializer.load_from_file(path)
	assert_eq(loaded.get("version"), 1)
	assert_eq(loaded.get("test_key"), "test_value")
	assert_eq(loaded.get("number"), 42)

	# Nettoyage
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_load_nonexistent_file() -> void:
	var loaded := GraphSerializer.load_from_file("user://does_not_exist_xyz.json")
	assert_push_error("fichier introuvable")
	assert_true(loaded.is_empty(), "Charger un fichier inexistant doit retourner un dict vide")


# ── Version ──────────────────────────────────────────────────

func test_save_version_included() -> void:
	var path := "user://test_version_tmp.json"
	var data := {"version": GraphSerializer.SAVE_VERSION, "figures": []}

	GraphSerializer.save_to_file(path, data)
	var loaded := GraphSerializer.load_from_file(path)
	assert_eq(loaded.get("version"), GraphSerializer.SAVE_VERSION)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ── Full Serialization ───────────────────────────────────────

func test_serialize_graph_full() -> void:
	# 1. Figures
	var fig_a_data := _make_figure_data("FigA", 1, 1)
	var fig_b_data := _make_figure_data("FigB", 2, 2)
	
	# On instancie Figure mais on ne l'ajoute pas forcément à l'arbre pour éviter @onready
	# serialize_graph accède à figure.data et figure.is_fleet_figure
	var fig_a := Figure.new()
	fig_a.data = fig_a_data
	fig_a.is_fleet_figure = false
	
	var fig_b := Figure.new()
	fig_b.data = fig_b_data
	fig_b.is_fleet_figure = true # Mock FleetFigure
	
	var figures_by_id := {
		fig_a_data.id: fig_a,
		fig_b_data.id: fig_b
	}
	
	# 2. Liens (Mock LinksLayer)
	var link_data := _make_link_data(fig_a_data, fig_a_data.output_slots[0], fig_b_data, fig_b_data.input_slots[0])
	var mock_links_layer = double(LinksLayer).new()
	stub(mock_links_layer, "get_all_link_data").to_return([link_data])
	
	# 3. Flottes (Mock FleetPanel)
	var fleet_data := _make_fleet_data("MyFleet")
	var mock_fleet_panel = double(FleetPanel).new()
	stub(mock_fleet_panel, "get_fleets").to_return([fleet_data])
	
	# 4. Mapping fleet_to_slot
	var fleet_to_slot := {
		fleet_data.id: fig_b_data.output_slots[0]
	}
	
	# 5. Serialization
	var serialized := GraphSerializer.serialize_graph(
		figures_by_id,
		mock_links_layer,
		mock_fleet_panel,
		fleet_to_slot,
		0.75, # canvas_zoom
		150.0 # timeline_scale
	)
	
	# 6. Verifications
	assert_eq(serialized["version"], GraphSerializer.SAVE_VERSION)
	assert_eq(serialized["canvas_zoom"], 0.75)
	assert_eq(serialized["timeline_scale"], 150.0)
	
	assert_eq(serialized["figures"].size(), 2)
	var s_fig_a = serialized["figures"][0] if serialized["figures"][0]["id"] == str(fig_a_data.id) else serialized["figures"][1]
	assert_eq(s_fig_a["title"], "FigA")
	assert_eq(s_fig_a["is_fleet_figure"], false)
	
	var s_fig_b = serialized["figures"][1] if serialized["figures"][1]["id"] == str(fig_b_data.id) else serialized["figures"][0]
	assert_eq(s_fig_b["is_fleet_figure"], true)
	
	assert_eq(serialized["links"].size(), 1)
	assert_eq(serialized["links"][0]["source_figure_id"], str(fig_a_data.id))
	
	assert_eq(serialized["fleets"].size(), 1)
	assert_eq(serialized["fleets"][0]["name"], "MyFleet")
	
	assert_eq(serialized["fleet_to_slot"][str(fleet_data.id)], str(fig_b_data.output_slots[0].id))
	
	# Cleanup
	fig_a.free()
	fig_b.free()
