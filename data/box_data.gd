class_name BoxData
extends Resource

## Données persistantes d'une boîte nodale.

@export var id: StringName = &""
@export var title: String = "Nouvelle boîte"
@export var position: Vector2 = Vector2.ZERO
@export var color: Color = Color("4a90d9")
## Début de la figure sur la timeline (en secondes).
@export var start_time: float = 0.0
## Fin de la figure sur la timeline (en secondes).
@export var end_time: float = 1.0
## Index de la piste sur le panneau timeline NLE.
@export var track: int = 0
@export var input_slots: Array[SlotData] = []
@export var output_slots: Array[SlotData] = []


## Génère un identifiant unique pour cette boîte.
## p_inputs / p_outputs : nombre d'entrées / sorties (défaut 1/1 cf. spec §4.5).
static func create(
	p_title: String = "Nouvelle boîte",
	p_position: Vector2 = Vector2.ZERO,
	p_inputs: int = 1,
	p_outputs: int = 1,
	p_start_time: float = 0.0,
	p_end_time: float = 1.0,
	p_track: int = 0,
) -> BoxData:
	var data := BoxData.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.title = p_title
	data.position = p_position
	data.start_time = p_start_time
	data.end_time = p_end_time
	data.track = p_track
	data.input_slots = []
	data.output_slots = []
	for i in p_inputs:
		data.input_slots.append(
			SlotData.create("input_%d" % i, SlotData.Direction.SLOT_INPUT, i)
		)
	for i in p_outputs:
		data.output_slots.append(
			SlotData.create("output_%d" % i, SlotData.Direction.SLOT_OUTPUT, i)
		)
	return data
