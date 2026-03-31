# AGENTS.md

## Source de vérité

Toute implémentation dans ce projet doit se baser sur **[SPEC.md](./SPEC.md)**.

Ce fichier constitue la référence unique pour :
- L'architecture des scènes Godot
- Le comportement de chaque composant (boîtes, slots, câbles, timeline, panneaux)
- Le modèle de données (`BoxData`, `SlotData`, `LinkData`, `GraphData`)
- La structure des fichiers cible
- Les raccourcis clavier
- Les règles de magnétisme

## Règles pour les agents

1. **Lire SPEC.md en premier** avant toute tâche de génération de code ou d'architecture.
2. **Respecter les noms** définis dans la spec (noms de scènes, scripts, classes, variables).
3. **Ne pas dévier des décisions techniques** listées en bas de la spec sans mise à jour explicite de celle-ci.
4. **Si la spec est ambiguë**, demander une clarification avant d'implémenter — ne pas improviser.
5. **Toute modification de comportement** doit être répercutée dans SPEC.md pour maintenir la cohérence.
6. **Tester les implémentations** vérifier avec l'intellisense de Godot qu'il n'y a pas d'erreurs. Double check l'implémentation
7. **Lorsque qu'un nouveau besoin est exprimé**, vérifier s'il est déjà couvert par la spec avant de proposer une solution et si ce n'est pas le cas, proposer une mise à jour de la spec avant d'implémenter.
8. **Mettre en place les tests unitaires** pour toute nouvelle fonctionnalité ou modification significative, en suivant la structure définie dans le projet.
9. **TU DOIS ABSOLUMENT Éxecuter l'application et les tests** pour s'assurer que tout fonctionne correctement après chaque modification majeure.
10. **La couverture de test unitaire doit être d'au moins 80% des lignes de code (Line Coverage)**. Tout nouveau fichier source doit être accompagné de son fichier de test couvrant l'essentiel de sa logique interne.
11. **NE RIEN FAIRE SANS QUE CE N'AIT ETE EXPLICITEMENT DEMANDÉ**. Toute tâche doit être validée par une demande explicite avant d'être exécutée, même si elle semble évidente ou nécessaire.
12. **Utiliser au maximum la doc GODOT et les ressources officielles** notamment : [Documentation Godot](https://docs.godotengine.org/fr/stable/), [API Godot](https://docs.godotengine.org/fr/stable/classes/index.html), [Tutoriels Godot](https://docs.godotengine.org/fr/stable/getting_started/step_by_step/index.html), [Création d'application](https://docs.godotengine.org/en/stable/tutorials/ui/creating_applications.html#desktop-integration).
13. **TU NE DOIS JAMAIS FAIRE DE COMMIT PUSH** Toute modifications doit être validée localement uniquement.
14. **Créer un test E2E avec screenshots pour chaque interface ou modification d'interface**. Si un test E2E n'existe pas encore pour l'écran modifié, en créer un dans `tests/e2e/`. Le test doit utiliser `_take_screenshot()` à chaque étape clé du workflow. Les anciens screenshots sont automatiquement nettoyés à chaque nouveau run.
15. **Servir les screenshots après les tests E2E** en lançant `./serve_screenshots.sh` à la racine du projet. Cela permet de visualiser les résultats à distance (ex: via Remote Control) sur `http://<IP_LOCALE>:8899/`.

## Couverture des tests

La couverture est calculée automatiquement par l'addon `coverage` via les hooks GUT (`pre_run_script` et `post_run_script`).

**Objectif cible :** 80.0% des lignes exécutables.
**Mesure actuelle :** **65.0%** (Total Coverage: 2283/3513 lines).

Pour recalculer le taux :
```bash
# Détection du binaire Godot
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}

# Lancer les tests avec hooks de couverture
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```
Les résultats détaillés par fichier s'affichent à la fin du run et sont sauvegardés dans `coverage.json`.

## Stack

- **Moteur** : Godot 4.6
- **Langage** : GDScript uniquement
- **Renderer** : Forward Plus

## Environnement Godot

- **Priorité** : La variable d'environnement `GODOT_PATH` est utilisée en priorité si elle est définie.
- **Local (macOS)** : `/Applications/Godot.app/Contents/MacOS/Godot` par défaut.
- **Remote (Linux / Claude Code web)** : `godot` (installé dans `/usr/local/bin/godot`).
- **Windows** : Définir `GODOT_PATH` dans un fichier `.env` ou via `$env:GODOT_PATH = "C:\chemin\vers\godot.exe"`.

Pour déterminer quel binaire utiliser dans les scripts (bash) :

```bash
# Détection automatique (Bash)
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}
```

Pour PowerShell (Windows) :

```powershell
# Détection automatique (PowerShell)
$GODOT = if ($env:GODOT_PATH) { $env:GODOT_PATH } else { (Get-Command godot -ErrorAction SilentlyContinue).Source ?? "C:\Path\To\Godot.exe" }
```

## Running the Project

```bash
# Open in Godot editor (local macOS)
"/Applications/Godot.app/Contents/MacOS/Godot" --editor --path .

# Run the project directly
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}
$GODOT --path .
```

## Exécution des tests GUT

GUT est configuré avec `"should_exit": true` dans `.gutconfig.json`, ce qui fait quitter Godot automatiquement après les tests. Le `timeout` sert uniquement de filet de sécurité.

```bash
# Détection du binaire Godot
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}

# Lancer tous les tests (unitaires + E2E)
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```

```bash
# Lancer un fichier de test spécifique
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_example.gd
```

## Tests E2E (end-to-end)

Les tests E2E se trouvent dans `tests/e2e/` et étendent la classe de base `tests/unit/e2e_test_base.gd`.
Ils simulent de vrais clics, drags et interactions souris sur l'application complète (Main.tscn).

**Structure :**
- `tests/unit/e2e_test_base.gd` — Classe de base avec helpers de simulation (`_simulate_click`, `_simulate_drag`, `_simulate_link_drag`, `_take_screenshot`, etc.)
- `tests/e2e/test_e2e_figure_workflow.gd` — Sélection, drag, ajout de slots, pan, zoom, double-clic, menu details
- `tests/e2e/test_e2e_link_workflow.gd` — Création de liens via slots, règles de connexion, suppression, verrouillage
- `tests/e2e/test_e2e_full_workflow.gd` — Workflows complets : create→link→save→load, sélection croisée canvas↔timeline
- `tests/e2e/test_e2e_screenshots.gd` — Test avec capture d'écran à chaque étape (screenshots sauvegardés dans `tests/e2e/screenshots/`)
- `tests/e2e/test_e2e_payload_settings.gd` — Paramétrage des payloads : navigation, ajout, modification, suppression

```bash
# Lancer uniquement les tests E2E (headless)
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/e2e

# Lancer les tests E2E avec screenshots (SANS --headless, nécessite un affichage)
timeout 60 $GODOT --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_screenshots.gd

# Servir les screenshots en local pour visualisation à distance
./serve_screenshots.sh        # port 8899 par défaut
./serve_screenshots.sh 9000   # port personnalisé
```

**Nettoyage automatique :** Les anciens dossiers de screenshots sont supprimés automatiquement à chaque nouveau run E2E (seul le run courant est conservé).

**Note :** Les tests E2E utilisent `extends "res://tests/unit/e2e_test_base.gd"` car GUT en mode headless ne résout pas les `class_name`. Le fichier de base est donc placé dans `tests/unit/` pour la résolution de chemin.
