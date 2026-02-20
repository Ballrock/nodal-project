extends GutTest

## Tests unitaires pour les modèles de données (FigureData, SlotData, LinkData, FleetData, GraphData).


# ── FigureData ───────────────────────────────────────────────

func test_figure_data_create_default() -> void:
	var figure := FigureData.create()
	assert_ne(figure.id, &"", "FigureData doit avoir un id non-vide")
	assert_eq(figure.title, "Nouvelle figure")
	assert_eq(figure.position, Vector2.ZERO)
	assert_eq(figure.input_slots.size(), 1, "1 entrée par défaut")
	assert_eq(figure.output_slots.size(), 1, "1 sortie par défaut")


func test_figure_data_create_custom() -> void:
	var figure := FigureData.create("Test", Vector2(100, 200), 3, 2)
	assert_eq(figure.title, "Test")
	assert_eq(figure.position, Vector2(100, 200))
	assert_eq(figure.input_slots.size(), 3)
	assert_eq(figure.output_slots.size(), 2)


func test_figure_data_create_zero_slots() -> void:
	var figure := FigureData.create("Vide", Vector2.ZERO, 0, 0)
	assert_eq(figure.input_slots.size(), 0)
	assert_eq(figure.output_slots.size(), 0)


func test_figure_data_unique_ids() -> void:
	var figure_a := FigureData.create()
	var figure_b := FigureData.create()
	assert_ne(figure_a.id, figure_b.id, "Chaque FigureData doit avoir un id unique")


func test_figure_data_slots_have_correct_direction() -> void:
	var figure := FigureData.create("Dir", Vector2.ZERO, 2, 2)
	for slot in figure.input_slots:
		assert_eq(slot.direction, SlotData.Direction.SLOT_INPUT)
	for slot in figure.output_slots:
		assert_eq(slot.direction, SlotData.Direction.SLOT_OUTPUT)


func test_figure_data_slots_have_sequential_index() -> void:
	var figure := FigureData.create("Idx", Vector2.ZERO, 3, 3)
	for i in figure.input_slots.size():
		assert_eq(figure.input_slots[i].index, i)
	for i in figure.output_slots.size():
		assert_eq(figure.output_slots[i].index, i)


func test_figure_data_has_start_end_time_defaults() -> void:
	var figure := FigureData.create()
	assert_eq(figure.start_time, 0.0, "start_time par défaut = 0.0s")
	assert_eq(figure.end_time, 1.0, "end_time par défaut = 1.0s")


func test_figure_data_has_track_default() -> void:
	var figure := FigureData.create()
	assert_eq(figure.track, 0, "track par défaut = 0")


func test_figure_data_create_with_times() -> void:
	var figure := FigureData.create("T", Vector2.ZERO, 1, 1, 2.5, 5.0, 3)
	assert_eq(figure.start_time, 2.5)
	assert_eq(figure.end_time, 5.0)
	assert_eq(figure.track, 3)


# ── SlotData ──────────────────────────────────────────────

func test_slot_data_create() -> void:
	var slot := SlotData.create("my_slot", SlotData.Direction.SLOT_OUTPUT, 2)
	assert_ne(slot.id, &"")
	assert_eq(slot.label, "my_slot")
	assert_eq(slot.direction, SlotData.Direction.SLOT_OUTPUT)
	assert_eq(slot.index, 2)


func test_slot_data_unique_ids() -> void:
	var a := SlotData.create("a", SlotData.Direction.SLOT_INPUT, 0)
	var b := SlotData.create("b", SlotData.Direction.SLOT_INPUT, 1)
	assert_ne(a.id, b.id)


# ── LinkData ──────────────────────────────────────────────

func test_link_data_create() -> void:
	var link := LinkData.create(&"figure_1", &"slot_out", &"figure_2", &"slot_in")
	assert_ne(link.id, &"")
	assert_eq(link.source_figure_id, &"figure_1")
	assert_eq(link.source_slot_id, &"slot_out")
	assert_eq(link.target_figure_id, &"figure_2")
	assert_eq(link.target_slot_id, &"slot_in")


func test_link_data_unique_ids() -> void:
	var a := LinkData.create(&"b1", &"s1", &"b2", &"s2")
	var b := LinkData.create(&"b1", &"s1", &"b2", &"s2")
	assert_ne(a.id, b.id, "Chaque LinkData doit avoir un id unique, même avec les mêmes paramètres")


# ── FleetData ─────────────────────────────────────────────

func test_fleet_data_create_default() -> void:
	var fleet := FleetData.create()
	assert_ne(fleet.id, &"")
	assert_eq(fleet.name, "Nouvelle flotte")
	assert_eq(fleet.drone_type, FleetData.DroneType.DRONE_RIFF)
	assert_eq(fleet.drone_count, 1)


func test_fleet_data_create_custom() -> void:
	var fleet := FleetData.create("Alpha", FleetData.DroneType.DRONE_EMO, 5)
	assert_eq(fleet.name, "Alpha")
	assert_eq(fleet.drone_type, FleetData.DroneType.DRONE_EMO)
	assert_eq(fleet.drone_count, 5)


func test_fleet_data_drone_type_label() -> void:
	var fleet_riff := FleetData.create("R", FleetData.DroneType.DRONE_RIFF, 1)
	assert_eq(fleet_riff.get_drone_type_label(), "RIFF")

	var fleet_emo := FleetData.create("E", FleetData.DroneType.DRONE_EMO, 1)
	assert_eq(fleet_emo.get_drone_type_label(), "EMO")


# ── GraphData ─────────────────────────────────────────────

func test_graph_data_default() -> void:
	var graph := GraphData.new()
	assert_eq(graph.figures.size(), 0)
	assert_eq(graph.links.size(), 0)
	assert_eq(graph.timeline_scale, 100.0)


func test_graph_data_add_figure() -> void:
	var graph := GraphData.new()
	var figure := FigureData.create("A", Vector2.ZERO)
	graph.figures.append(figure)
	assert_eq(graph.figures.size(), 1)
	assert_eq(graph.figures[0].title, "A")


func test_graph_data_add_link() -> void:
	var graph := GraphData.new()
	var figure_a := FigureData.create("A", Vector2.ZERO, 1, 1)
	var figure_b := FigureData.create("B", Vector2(200, 0), 1, 1)
	graph.figures.append(figure_a)
	graph.figures.append(figure_b)

	var link := LinkData.create(
		figure_a.id, figure_a.output_slots[0].id,
		figure_b.id, figure_b.input_slots[0].id
	)
	graph.links.append(link)
	assert_eq(graph.links.size(), 1)
	assert_eq(graph.links[0].source_figure_id, figure_a.id)
	assert_eq(graph.links[0].target_figure_id, figure_b.id)
