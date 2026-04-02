extends GutTest

## Tests unitaires pour PayloadDefinition.


func test_from_download_dict() -> void:
	var d := {"_id": "abc-123", "type": "LED", "commentaire": null, "actifEMO": true, "actifRIFF": true}
	var p := PayloadDefinition.from_download_dict(d)
	assert_eq(str(p.id), "abc-123")
	assert_eq(p.name, "LED")
	assert_eq(p.commentaire, "")
	assert_true(p.actif_emo)
	assert_true(p.actif_riff)


func test_from_download_dict_partial() -> void:
	var d := {"_id": "xyz", "type": "Laser", "actifRIFF": true, "actifEMO": false}
	var p := PayloadDefinition.from_download_dict(d)
	assert_eq(str(p.id), "xyz")
	assert_eq(p.name, "Laser")
	assert_true(p.actif_riff)
	assert_false(p.actif_emo)


func test_from_dict_with_internal_keys() -> void:
	var d := {"id": "internal-id", "name": "Strobe", "actif_riff": false, "actif_emo": true}
	var p := PayloadDefinition.from_dict(d)
	assert_eq(str(p.id), "internal-id")
	assert_eq(p.name, "Strobe")
	assert_false(p.actif_riff)
	assert_true(p.actif_emo)


func test_to_dict() -> void:
	var p := PayloadDefinition.new()
	p.id = &"test-id"
	p.name = "Smoke"
	p.commentaire = "Un commentaire"
	p.actif_emo = true
	p.actif_riff = false
	var d := p.to_dict()
	assert_eq(d["_id"], "test-id")
	assert_eq(d["type"], "Smoke")
	assert_eq(d["commentaire"], "Un commentaire")
	assert_true(d["actifEMO"])
	assert_false(d["actifRIFF"])


func test_roundtrip() -> void:
	var original := {"_id": "round-trip", "type": "FireJet", "commentaire": "test", "actifEMO": false, "actifRIFF": true}
	var p := PayloadDefinition.from_download_dict(original)
	var d := p.to_dict()
	assert_eq(d["_id"], "round-trip")
	assert_eq(d["type"], "FireJet")
	assert_eq(d["commentaire"], "test")
	assert_false(d["actifEMO"])
	assert_true(d["actifRIFF"])


func test_get_compatible_drone_type_indices_riff_only() -> void:
	var p := PayloadDefinition.new()
	p.actif_riff = true
	p.actif_emo = false
	assert_eq(p.get_compatible_drone_type_indices(), [0])


func test_get_compatible_drone_type_indices_emo_only() -> void:
	var p := PayloadDefinition.new()
	p.actif_riff = false
	p.actif_emo = true
	assert_eq(p.get_compatible_drone_type_indices(), [1])


func test_get_compatible_drone_type_indices_both() -> void:
	var p := PayloadDefinition.new()
	p.actif_riff = true
	p.actif_emo = true
	assert_eq(p.get_compatible_drone_type_indices(), [0, 1])


func test_get_compatible_drone_type_indices_none() -> void:
	var p := PayloadDefinition.new()
	p.actif_riff = false
	p.actif_emo = false
	assert_eq(p.get_compatible_drone_type_indices(), [])


func test_from_dict_empty() -> void:
	var d := {}
	var p := PayloadDefinition.from_dict(d)
	assert_eq(str(p.id), "")
	assert_eq(p.name, "")
	assert_eq(p.commentaire, "")
	assert_false(p.actif_emo)
	assert_false(p.actif_riff)


func test_from_download_dict_with_commentaire() -> void:
	var d := {"_id": "c1", "type": "Strobe", "commentaire": "Effet stroboscopique", "actifEMO": true, "actifRIFF": false}
	var p := PayloadDefinition.from_download_dict(d)
	assert_eq(p.commentaire, "Effet stroboscopique")
