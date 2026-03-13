class_name PyroEffectDefinition
extends Resource

## Definition d'un type d'effet pyrotechnique (catalogue global telecharge).
## Base sur le format JSON de Firebase (export_pyro_data.json).

@export var id: StringName = &""
@export var name: String = ""
@export var fabricant: String = ""
@export var is_assemblage: bool = false
@export var type: String = ""
@export var calibre: String = ""
@export var poids: float = 0.0
@export var taille_infla: float = 0.0
@export var code_onu: String = ""
@export var categorie: String = ""
@export var classe: String = ""
@export var distance_securite_verticale: float = 0.0
@export var distance_securite_horizontale: float = 0.0
@export var hauteur_effet: float = 0.0
@export var largeur_effet: float = 0.0
@export var ae: bool = false
@export var duree: float = 0.0
@export var longueur: float = 0.0
@export var nb_effets: float = 0.0
@export var poussee: bool = false
@export var valeur_poussee: float = 0.0
@export var tube: String = ""
@export var poids_residuel: float = 0.0


func to_dict() -> Dictionary:
	return {
		"id": str(id),
		"name": name,
		"fabricant": fabricant,
		"isAssemblage": is_assemblage,
		"type": type,
		"calibre": calibre,
		"poids": poids,
		"tailleInfla": taille_infla,
		"codeONU": code_onu,
		"categorie": categorie,
		"classe": classe,
		"distanceSecuriteVerticale": distance_securite_verticale,
		"distanceSecuriteHorizontale": distance_securite_horizontale,
		"hauteurEffet": hauteur_effet,
		"largeurEffet": largeur_effet,
		"ae": ae,
		"duree": duree,
		"longueur": longueur,
		"nbEffets": nb_effets,
		"poussee": poussee,
		"valeurPoussee": valeur_poussee,
		"tube": tube,
		"poidsResiduel": poids_residuel,
	}


static func from_dict(d: Dictionary) -> PyroEffectDefinition:
	var e := PyroEffectDefinition.new()
	e.id = StringName(str(d.get("id", "")))
	e.name = str(d.get("name", ""))
	e.fabricant = str(d.get("fabricant", ""))
	e.is_assemblage = bool(d.get("isAssemblage", false))
	e.type = str(d.get("type", "")).strip_edges()
	e.calibre = str(d.get("calibre", ""))
	e.poids = _safe_float(d.get("poids"))
	e.taille_infla = _safe_float(d.get("tailleInfla"))
	e.code_onu = str(d.get("codeONU", ""))
	e.categorie = str(d.get("categorie", ""))
	e.classe = str(d.get("classe", ""))
	e.distance_securite_verticale = _safe_float(d.get("distanceSecuriteVerticale"))
	e.distance_securite_horizontale = _safe_float(d.get("distanceSecuriteHorizontale"))
	e.hauteur_effet = _safe_float(d.get("hauteurEffet"))
	e.largeur_effet = _safe_float(d.get("largeurEffet"))
	e.ae = bool(d.get("ae", false))
	e.duree = _safe_float(d.get("duree"))
	e.longueur = _safe_float(d.get("longueur"))
	e.nb_effets = _safe_float(d.get("nbEffets"))
	e.poussee = bool(d.get("poussee", false))
	e.valeur_poussee = _safe_float(d.get("valeurPoussee"))
	e.tube = str(d.get("tube", ""))
	e.poids_residuel = _safe_float(d.get("poidsResiduel"))
	return e


## Cree une PyroEffectDefinition depuis le format JSON telecharge (format serveur).
static func from_download_dict(d: Dictionary) -> PyroEffectDefinition:
	var e := from_dict(d)
	e.id = StringName(e.name)
	return e


static func _safe_float(value) -> float:
	if value == null:
		return 0.0
	return float(value)


## Retourne les types d'effets uniques depuis une liste de definitions.
static func get_unique_types(effects: Array[PyroEffectDefinition]) -> Array[String]:
	var types: Array[String] = []
	for e in effects:
		var t := e.type.strip_edges()
		if not t.is_empty() and not types.has(t):
			types.append(t)
	types.sort()
	return types
