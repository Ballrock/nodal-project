# Nodal Project

Editeur nodal de scenographies pour drones, construit avec Godot 4.6 en GDScript.

## Stack

- **Moteur** : Godot 4.6
- **Langage** : GDScript
- **Renderer** : Forward Plus
- **Tests** : GUT 9.x

## Prerequis

Installer [Godot 4.6+](https://godotengine.org/download).

Le binaire est detecte automatiquement :

| Plateforme | Chemin par defaut |
|---|---|
| macOS | `/Applications/Godot.app/Contents/MacOS/Godot` |
| Linux | `godot` (dans le PATH) |
| Windows | Definir `GODOT_PATH` dans l'environnement |

```bash
# Detection automatique
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}
```

## Lancer le projet

```bash
# Ouvrir dans l'editeur
$GODOT --editor --path .

# Lancer directement
$GODOT --path .
```

## Tests

```bash
# Tous les tests (unitaires + E2E)
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd

# Un fichier specifique
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_example.gd

# Tests E2E uniquement
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/e2e

# Tests E2E avec screenshots (necessite un affichage, pas de --headless)
timeout 60 $GODOT --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_screenshots.gd

# Visualiser les screenshots a distance
./serve_screenshots.sh        # port 8899 par defaut
```

La couverture est calculee automatiquement a chaque run et sauvegardee dans `coverage.json`.

## Bases de donnees distantes

Les catalogues nacelles, effets pyro et payloads sont telecharges depuis des API distantes et caches localement. La gestion se fait dans les parametres logiciel (Base de donnees).

| Catalogue | Manager | Source |
|---|---|---|
| Nacelles | `NacelleManager` | Google Cloud Storage |
| Effets Pyro | `PyroEffectManager` | Firebase Storage |
| Payloads | `PayloadManager` | Google Cloud Storage |

Ces managers sont des autoloads Godot. Ils gerent le telechargement, le cache local (`user://`), la verification de mises a jour, et la synchronisation avec `SettingsManager`.

## Migrations de settings

Les settings persistees (`user://settings.json`) sont versionnees via un systeme de migrations auto-decouvertes, inspire de [TypeORM](https://typeorm.io/migrations).

### Creer une migration

```bash
./scripts/generate_migration.sh "description de la migration"
```

Cela genere un fichier dans `core/settings/migrations/` :

```gdscript
extends MigrationBase

func get_version() -> int:
    return 20260402143000  # Timestamp YYYYMMDDHHMMSS

func get_description() -> String:
    return "Description courte"

func up(data: Dictionary) -> Dictionary:
    # Transformer les donnees
    return data
```

### Fonctionnement

- Le `SettingsMigrator` scanne `core/settings/migrations/` au demarrage
- Chaque fichier `migration_*.gd` etendant `MigrationBase` est decouvert automatiquement
- Les migrations sont triees par timestamp et executees dans l'ordre
- Seules celles dont la version est superieure au `_version` du fichier settings sont jouees
- Les migrations doivent etre idempotentes

## Structure du projet

```
core/
  data/               # Modeles de donnees (FigureData, SlotData, LinkData, etc.)
  settings/           # SettingsManager + migrations
  nacelle/            # NacelleManager (autoload)
  pyro_effect/        # PyroEffectManager (autoload)
  payload/            # PayloadManager (autoload)
  utils/              # Helpers (WindowHelper, SnapHelper)
features/
  workspace/          # Canvas nodal (figures, slots, liens, minimap)
  timeline/           # Timeline (segments, ruler, scrolling)
  fleet/              # Gestion de flotte (composition, contraintes)
ui/
  main/               # Scene principale
  components/         # Fenetres (settings, config, modales)
tests/
  unit/               # Tests unitaires GUT
  e2e/                # Tests end-to-end avec screenshots
scripts/
  generate_migration.sh
```
