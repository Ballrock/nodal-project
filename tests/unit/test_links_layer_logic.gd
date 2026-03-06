extends GutTest

## Tests unitaires pour la logique de LinksLayer (sans rendu).

var _links_layer: LinksLayer = null
var _spawned: Array = []

# Classe helper pour simuler une Figure sans dépendances UI
class MockFigure extends Figure:
	var slots: Array[Slot] = []
	func _init(p_data: FigureData):
		self.data = p_data
		self.is_fleet_figure = false
	func get_all_slots() -> Array[Slot]:
		return slots
	func find_slot_by_id(id: StringName) -> Slot:
		for s in slots:
			if s.data.id == id: return s
		return null
	func free_all():
		for s in slots:
			s.queue_free()
		self.queue_free()

func before_each() -> void:
	_links_layer = LinksLayer.new()
	add_child_autofree(_links_layer)
	_spawned = []

func after_each() -> void:
	for fig in _spawned:
		fig.free_all()
	_spawned = []


func _create_mock_figure(name: String, inputs: int = 1, outputs: int = 1) -> MockFigure:
	var data = FigureData.create(name, Vector2.ZERO, inputs, outputs)
	var fig = MockFigure.new(data)
	_spawned.append(fig)
	
	# FigureData.create() génère déjà des IDs pour les SlotData, mais on va s'assurer
	# qu'ils sont prédictibles et uniques pour le test dans LinksLayer.
	for i in data.input_slots.size():
		var sd = data.input_slots[i]
		sd.id = StringName("in_%s_%d" % [name, i])
		var s = Slot.new()
		s.data = sd
		s.owner_figure = fig
		fig.slots.append(s)
		
	for i in data.output_slots.size():
		var sd = data.output_slots[i]
		sd.id = StringName("out_%s_%d" % [name, i])
		var s = Slot.new()
		s.data = sd
		s.owner_figure = fig
		fig.slots.append(s)
	
	return fig


func test_add_remove_link() -> void:
	var fig_a = _create_mock_figure("A")
	var fig_b = _create_mock_figure("B")
	_links_layer.set_figures([fig_a, fig_b])
	
	var ld = LinkData.create(fig_a.data.id, fig_a.get_all_slots()[1].data.id, 
							fig_b.data.id, fig_b.get_all_slots()[0].data.id)
	
	_links_layer.add_link(fig_a.get_all_slots()[1], fig_b.get_all_slots()[0], ld)
	assert_eq(_links_layer.get_all_link_data().size(), 1)
	
	_links_layer.remove_link(ld)
	assert_eq(_links_layer.get_all_link_data().size(), 0)


func test_is_valid_connection_basic() -> void:
	var fig_a = _create_mock_figure("A")
	var fig_b = _create_mock_figure("B")
	_links_layer.set_figures([fig_a, fig_b])
	
	var out_a = fig_a.get_all_slots()[1] # Output
	var in_b = fig_b.get_all_slots()[0]  # Input
	
	# Valide : Out -> In
	assert_true(_links_layer.call("_is_valid_connection", out_a, in_b))
	# Invalide : Out -> Out
	var out_b = fig_b.get_all_slots()[1]
	assert_false(_links_layer.call("_is_valid_connection", out_a, out_b))
	# Invalide : Self-loop
	var in_a = fig_a.get_all_slots()[0]
	assert_false(_links_layer.call("_is_valid_connection", out_a, in_a))


func test_is_valid_connection_input_already_connected() -> void:
	var fig_a = _create_mock_figure("A")
	var fig_b = _create_mock_figure("B")
	var fig_c = _create_mock_figure("C")
	_links_layer.set_figures([fig_a, fig_b, fig_c])
	
	var out_a = fig_a.get_all_slots()[1]
	var in_b = fig_b.get_all_slots()[0]
	var out_c = fig_c.get_all_slots()[1]
	
	# Connecte A -> B
	var ld = LinkData.create(fig_a.data.id, out_a.data.id, fig_b.data.id, in_b.data.id)
	_links_layer.add_link(out_a, in_b, ld)
	
	# Tente C -> B (invalide car B est déjà pris)
	assert_false(_links_layer.call("_is_valid_connection", out_c, in_b))
	# Par contre _can_connect_or_replace doit être vrai (pour le snap de remplacement)
	assert_true(_links_layer.call("_can_connect_or_replace", out_c, in_b))


func test_is_valid_connection_one_link_per_target_figure() -> void:
	var fig_a = _create_mock_figure("A", 1, 2) # 1 in, 2 out
	var fig_b = _create_mock_figure("B", 2, 1) # 2 in, 1 out
	_links_layer.set_figures([fig_a, fig_b])
	
	# Fig A: [0]=in, [1]=out0, [2]=out1
	var out_a0 = fig_a.get_all_slots()[1]
	var out_a1 = fig_a.get_all_slots()[2]
	
	# Fig B: [0]=in0, [1]=in1, [2]=out0
	var in_b0 = fig_b.get_all_slots()[0]
	var in_b1 = fig_b.get_all_slots()[1]
	
	# Avant tout lien : les deux sont valides
	assert_true(_links_layer.call("_is_valid_connection", out_a0, in_b0), "Premier lien doit être valide")
	assert_true(_links_layer.call("_is_valid_connection", out_a1, in_b1), "Deuxième lien (alternatif) doit être valide")
	
	# On crée le premier lien (A.out0 -> B.in0)
	var ld = LinkData.create(fig_a.data.id, out_a0.data.id, fig_b.data.id, in_b0.data.id)
	_links_layer.add_link(out_a0, in_b0, ld)
	
	# Maintenant, un DEUXIÈME lien depuis la MÊME sortie (A.out0) vers la MÊME figure (B)
	# mais sur une entrée différente (in_b1) est invalide.
	assert_false(_links_layer.call("_is_valid_connection", out_a0, in_b1), "Deuxième lien depuis même sortie vers même figure doit être invalide")


func test_has_link_from_output_to_figure() -> void:
	var fig_a = _create_mock_figure("A")
	var fig_b = _create_mock_figure("B")
	_links_layer.set_figures([fig_a, fig_b])
	
	var out_a = fig_a.get_all_slots()[1]
	var in_b = fig_b.get_all_slots()[0]
	
	assert_false(_links_layer.call("_has_link_from_output_to_figure", out_a.data.id, fig_b.data.id))
	
	var ld = LinkData.create(fig_a.data.id, out_a.data.id, fig_b.data.id, in_b.data.id)
	_links_layer.add_link(out_a, in_b, ld)
	
	assert_true(_links_layer.call("_has_link_from_output_to_figure", out_a.data.id, fig_b.data.id))


func test_is_valid_connection_different_roles() -> void:
	var fig_a = _create_mock_figure("A")
	var fig_b = _create_mock_figure("B")
	_links_layer.set_figures([fig_a, fig_b])
	
	var in_a = fig_a.get_all_slots()[0]
	var out_a = fig_a.get_all_slots()[1]
	var in_b = fig_b.get_all_slots()[0]
	var out_b = fig_b.get_all_slots()[1]
	
	# Out -> In : Valide
	assert_true(_links_layer.call("_is_valid_connection", out_a, in_b), "Out -> In doit être valide")
	# In -> Out : Valide (sera inversé à la création)
	assert_true(_links_layer.call("_is_valid_connection", in_a, out_b), "In -> Out doit être valide")
	# In -> In : Invalide
	assert_false(_links_layer.call("_is_valid_connection", in_a, in_b), "In -> In doit être invalide")
	# Out -> Out : Invalide
	assert_false(_links_layer.call("_is_valid_connection", out_a, out_b), "Out -> Out doit être invalide")


func test_find_links_for_slot() -> void:
	var fig_a = _create_mock_figure("A")
	var fig_b = _create_mock_figure("B")
	_links_layer.set_figures([fig_a, fig_b])
	
	var out_a = fig_a.get_all_slots()[1]
	var in_b = fig_b.get_all_slots()[0]
	var ld = LinkData.create(fig_a.data.id, out_a.data.id, fig_b.data.id, in_b.data.id)
	_links_layer.add_link(out_a, in_b, ld)
	
	assert_eq(_links_layer.find_links_for_slot(out_a.data.id).size(), 1)
	assert_eq(_links_layer.find_links_for_slot(in_b.data.id).size(), 1)
	assert_eq(_links_layer.find_links_for_slot(&"nothing").size(), 0)
