#!/bin/bash

# Script pour exécuter les tests GUT
# Usage: ./run_tests.sh [options]

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Déterminer le chemin vers Godot en fonction du système
if command -v godot &> /dev/null; then
    GODOT_CMD="godot"
elif command -v godot4 &> /dev/null; then
    GODOT_CMD="godot4"
else
    # Si Godot n'est pas trouvé dans PATH, essayer les chemins courants
    if [ -f "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
        GODOT_CMD="/Applications/Godot.app/Contents/MacOS/Godot"
    elif [ -f "$HOME/.cargo/bin/godot" ]; then
        GODOT_CMD="$HOME/.cargo/bin/godot"
    else
        echo "Erreur: Godot n'est pas installé ou pas trouvé dans PATH"
        exit 1
    fi
fi

echo "Utilisation de Godot: $GODOT_CMD"
echo "Répertoire du projet: $PROJECT_DIR"
echo ""

# Exécuter les tests GUT en mode headless
cd "$PROJECT_DIR"
"$GODOT_CMD" --headless -s addons/gut/gut_cmdln.gd "$@"

exit $?
