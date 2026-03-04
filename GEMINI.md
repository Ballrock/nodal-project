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
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot 4.6.app/Contents/MacOS/Godot")}
```

Pour PowerShell (Windows) :

```powershell
# Détection automatique (PowerShell)
$GODOT = if ($env:GODOT_PATH) { $env:GODOT_PATH } else { (Get-Command godot -ErrorAction SilentlyContinue).Source ?? "C:\Path\To\Godot.exe" }
```

## Running the Project

```bash
# Open in Godot editor (local macOS)
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .

# Run the project directly
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot 4.6.app/Contents/MacOS/Godot")}
$GODOT --path .
```

## Exécution des tests GUT

GUT est configuré avec `"should_exit": true` dans `.gutconfig.json`, ce qui fait quitter Godot automatiquement après les tests. Le `timeout` sert uniquement de filet de sécurité.

```bash
# Détection du binaire Godot
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot 4.6.app/Contents/MacOS/Godot")}

# Lancer tous les tests GUT
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```
# Lancer un fichier de test spécifique
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/test_example.gd
```
