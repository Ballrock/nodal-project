class_name PayloadDefinition
extends Resource

## Definition d'un type de payload (catalogue global telecharge).
## Base sur le format JSON distant (export_payload_data.json).

@export var id: StringName = &""
@export var name: String = ""
@export var commentaire: String = ""
@export var actif_emo: bool = false
@export var actif_riff: bool = false


func to_dict() -> Dictionary:
	return {
		"_id": str(id),
		"type": name,
		"commentaire": commentaire,
		"actifEMO": actif_emo,
		"actifRIFF": actif_riff,
	}


static func from_dict(d: Dictionary) -> PayloadDefinition:
	var p := PayloadDefinition.new()
	p.id = StringName(str(d.get("_id", d.get("id", ""))))
	p.name = str(d.get("type", d.get("name", "")))
	p.commentaire = str(d.get("commentaire", "")) if d.get("commentaire") != null else ""
	p.actif_emo = bool(d.get("actifEMO", d.get("actif_emo", false)))
	p.actif_riff = bool(d.get("actifRIFF", d.get("actif_riff", false)))
	return p


## Cree une PayloadDefinition depuis le format JSON telecharge (format serveur).
static func from_download_dict(d: Dictionary) -> PayloadDefinition:
	return from_dict(d)


## Retourne les indices de types de drones compatibles (0=RIFF, 1=EMO).
func get_compatible_drone_type_indices() -> Array[int]:
	var result: Array[int] = []
	if actif_riff:
		result.append(0)
	if actif_emo:
		result.append(1)
	return result
