class_name MigrationBase
extends RefCounted

## Classe de base pour les migrations de settings.
## Chaque migration doit etendre cette classe et surcharger :
##   get_version()     → timestamp (YYYYMMDDHHMMSS) identifiant la migration
##   get_description() → description courte de la migration
##   up(data)          → transformation des donnees


func get_version() -> int:
	push_error("%s.get_version() non surcharge" % get_script().resource_path)
	return -1


func get_description() -> String:
	push_error("%s.get_description() non surcharge" % get_script().resource_path)
	return ""


func up(data: Dictionary) -> Dictionary:
	push_error("%s.up() non surcharge" % get_script().resource_path)
	return data
