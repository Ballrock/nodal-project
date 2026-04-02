# res://core/settings/settings_migrator.gd
class_name SettingsMigrator
extends RefCounted

## Systeme de migration versionnee des settings persistees.
## Les migrations sont auto-decouvertes depuis le dossier migrations/.
## Chaque fichier migration_XXX.gd doit etendre MigrationBase.

const MIGRATIONS_DIR := "res://core/settings/migrations/"


static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("_version", 0))
	var migrations := _discover_migrations()

	for m: MigrationBase in migrations:
		var m_version: int = m.get_version()
		if version < m_version:
			data = m.up(data)
			data["_version"] = m_version

	return data


static func get_current_version() -> int:
	var migrations := _discover_migrations()
	if migrations.is_empty():
		return 0
	return migrations[migrations.size() - 1].get_version()


static func _discover_migrations() -> Array[MigrationBase]:
	var migrations: Array[MigrationBase] = []
	var dir := DirAccess.open(MIGRATIONS_DIR)
	if not dir:
		push_warning("SettingsMigrator: dossier migrations introuvable: %s" % MIGRATIONS_DIR)
		return migrations

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("migration_") and file_name.ends_with(".gd") and file_name != "migration_base.gd":
			var script = load(MIGRATIONS_DIR + file_name)
			if script:
				var instance = script.new()
				if instance is MigrationBase:
					migrations.append(instance)
				else:
					push_warning("SettingsMigrator: %s n'etend pas MigrationBase" % file_name)
		file_name = dir.get_next()

	migrations.sort_custom(func(a: MigrationBase, b: MigrationBase): return a.get_version() < b.get_version())
	return migrations


## Retourne les noms des contraintes qui referencent un item donne.
static func find_referencing_constraints(item_id: String, category_filter: int, constraints_data: Array) -> Array[String]:
	var referencing: Array[String] = []
	for d in constraints_data:
		if not d is Dictionary:
			continue
		var cat: int = int(d.get("category", -1))
		var val: String = str(d.get("value", ""))
		if cat == category_filter and val == item_id:
			referencing.append(str(d.get("name", "Contrainte")))
	return referencing
