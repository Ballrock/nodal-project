class_name EffectDefinition
extends Resource

## Définition d'un type d'effet (catalogue global).

enum Category { PYRO = 0, SMOKE = 1, STROBE = 2, LASER = 3 }

@export var id: StringName = &""
@export var name: String = ""
@export var category: int = Category.PYRO
@export var compatible_nacelle_ids: Array[StringName] = []
@export var variants: Array[String] = []


static func create(p_name: String, p_category: int = Category.PYRO, p_nacelle_ids: Array[StringName] = [], p_variants: Array[String] = []) -> EffectDefinition:
	var data := EffectDefinition.new()
	data.id = StringName(str(ResourceUID.create_id()))
	data.name = p_name
	data.category = p_category
	data.compatible_nacelle_ids = p_nacelle_ids
	data.variants = p_variants
	return data


func get_category_label() -> String:
	match category:
		Category.PYRO: return "Pyrotechnique"
		Category.SMOKE: return "Fumée"
		Category.STROBE: return "Stroboscopique"
		Category.LASER: return "Laser"
		_: return "Inconnu"


func is_compatible_with_nacelle(nacelle_id: StringName) -> bool:
	return compatible_nacelle_ids.has(nacelle_id)


func to_dict() -> Dictionary:
	var nacelle_ids_str: Array[String] = []
	for nid in compatible_nacelle_ids:
		nacelle_ids_str.append(str(nid))
	return {
		"id": str(id),
		"name": name,
		"category": category,
		"compatible_nacelle_ids": nacelle_ids_str,
		"variants": variants,
	}


static func from_dict(d: Dictionary) -> EffectDefinition:
	var e := EffectDefinition.new()
	e.id = StringName(str(d.get("id", "")))
	e.name = str(d.get("name", ""))
	e.category = int(d.get("category", 0))
	var nids = d.get("compatible_nacelle_ids", [])
	e.compatible_nacelle_ids = []
	for nid in nids:
		e.compatible_nacelle_ids.append(StringName(str(nid)))
	var vars_arr = d.get("variants", [])
	e.variants = []
	for v in vars_arr:
		e.variants.append(str(v))
	return e
