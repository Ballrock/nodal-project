extends GutTest

## Tests unitaires pour les modèles de données (BoxData, SlotData, LinkData, FleetData, GraphData).


# ── BoxData ───────────────────────────────────────────────

func test_box_data_create_default() -> void:
	var box := BoxData.create()
	assert_ne(box.id, &"", "BoxData doit avoir un id non-vide")
	assert_eq(box.title, "Nouvelle boîte")
	assert_eq(box.position, Vector2.ZERO)
	assert_eq(box.input_slots.size(), 1, "1 entrée par défaut")
	assert_eq(box.output_slots.size(), 1, "1 sortie par défaut")


func test_box_data_create_custom() -> void:
	var box := BoxData.create("Test", Vector2(100, 200), 3, 2)
	assert_eq(box.title, "Test")
	assert_eq(box.position, Vector2(100, 200))
	assert_eq(box.input_slots.size(), 3)
	assert_eq(box.output_slots.size(), 2)


func test_box_data_create_zero_slots() -> void:
	var box := BoxData.create("Vide", Vector2.ZERO, 0, 0)
	assert_eq(box.input_slots.size(), 0)
	assert_eq(box.output_slots.size(), 0)


func test_box_data_unique_ids() -> void:
	var box_a := BoxData.create()
	var box_b := BoxData.create()
	assert_ne(box_a.id, box_b.id, "Chaque BoxData doit avoir un id unique")


func test_box_data_slots_have_correct_direction() -> void:
	var box := BoxData.create("Dir", Vector2.ZERO, 2, 2)
	for slot in box.input_slots:
		assert_eq(slot.direction, SlotData.Direction.SLOT_INPUT)
	for slot in box.output_slots:
		assert_eq(slot.direction, SlotData.Direction.SLOT_OUTPUT)


func test_box_data_slots_have_sequential_index() -> void:
	var box := BoxData.create("Idx", Vector2.ZERO, 3, 3)
	for i in box.input_slots.size():
		assert_eq(box.input_slots[i].index, i)
	for i in box.output_slots.size():
		assert_eq(box.output_slots[i].index, i)


func test_box_data_has_start_end_time_defaults() -> void:
	var box := BoxData.create()
	assert_eq(box.start_time, 0.0, "start_time par défaut = 0.0s")
	assert_eq(box.end_time, 1.0, "end_time par défaut = 1.0s")


func test_box_data_has_track_default() -> void:
	var box := BoxData.create()
	assert_eq(box.track, 0, "track par défaut = 0")


func test_box_data_create_with_times() -> void:
	var box := BoxData.create("T", Vector2.ZERO, 1, 1, 2.5, 5.0, 3)
	assert_eq(box.start_time, 2.5)
	assert_eq(box.end_time, 5.0)
	assert_eq(box.track, 3)


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
	var link := LinkData.create(&"box_1", &"slot_out", &"box_2", &"slot_in")
	assert_ne(link.id, &"")
	assert_eq(link.source_box_id, &"box_1")
	assert_eq(link.source_slot_id, &"slot_out")
	assert_eq(link.target_box_id, &"box_2")
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
	assert_eq(graph.boxes.size(), 0)
	assert_eq(graph.links.size(), 0)
	assert_eq(graph.timeline_scale, 100.0)


func test_graph_data_add_box() -> void:
	var graph := GraphData.new()
	var box := BoxData.create("A", Vector2.ZERO)
	graph.boxes.append(box)
	assert_eq(graph.boxes.size(), 1)
	assert_eq(graph.boxes[0].title, "A")


func test_graph_data_add_link() -> void:
	var graph := GraphData.new()
	var box_a := BoxData.create("A", Vector2.ZERO, 1, 1)
	var box_b := BoxData.create("B", Vector2(200, 0), 1, 1)
	graph.boxes.append(box_a)
	graph.boxes.append(box_b)

	var link := LinkData.create(
		box_a.id, box_a.output_slots[0].id,
		box_b.id, box_b.input_slots[0].id
	)
	graph.links.append(link)
	assert_eq(graph.links.size(), 1)
	assert_eq(graph.links[0].source_box_id, box_a.id)
	assert_eq(graph.links[0].target_box_id, box_b.id)
