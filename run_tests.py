#!/usr/bin/env python3
"""
Script de test GUT pour le projet Nodal
Exécute les tests unitaires à l'aide de GUT (fichier à la racine du projet)
"""

import subprocess
import sys
import os
from pathlib import Path

def find_godot():
    """Trouve le chemin vers l'exécutable Godot"""
    # Vérifier d'abord dans PATH
    if subprocess.run(['which', 'godot'], capture_output=True).returncode == 0:
        return 'godot'
    if subprocess.run(['which', 'godot4'], capture_output=True).returncode == 0:
        return 'godot4'
    
    # Vérifier les chemins courants (y compris les chemins macOS avec espaces)
    common_paths = [
        '/Applications/Godot.app/Contents/MacOS/Godot',
        '/Applications/Godot 4.6.app/Contents/MacOS/Godot',
        '/Applications/Godot 4.5.app/Contents/MacOS/Godot',
        '/Applications/Godot 4.4.app/Contents/MacOS/Godot',
        Path.home() / '.cargo' / 'bin' / 'godot',
        '/usr/bin/godot',
        '/usr/local/bin/godot',
    ]
    
    # Chercher aussi les versions Godot dans /Applications via glob
    for app in sorted(Path('/Applications').glob('Godot*.app'), reverse=True):
        godot_bin = app / 'Contents' / 'MacOS' / 'Godot'
        if godot_bin.exists():
            common_paths.insert(0, godot_bin)
    
    for path in common_paths:
        if Path(path).exists():
            return str(path)
    
    # Tenter de résoudre un alias shell (zsh/bash)
    try:
        result = subprocess.run(
            ['zsh', '-ic', 'command -v godot'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            resolved = result.stdout.strip()
            if resolved and Path(resolved).exists():
                return resolved
    except Exception:
        pass
    
    return None

def main():
    # Trouver le chemin du projet
    project_dir = Path(__file__).parent.absolute()
    
    # Trouver Godot
    godot_cmd = find_godot()
    if not godot_cmd:
        print("Erreur: Godot n'est pas installé ou pas trouvé dans PATH", file=sys.stderr)
        print("\nInstallation suggérée:", file=sys.stderr)
        print("  macOS: brew install godot", file=sys.stderr)
        print("  Linux: sudo apt install godot", file=sys.stderr)
        sys.exit(1)
    
    print(f"Utilisation de Godot: {godot_cmd}")
    print(f"Répertoire du projet: {project_dir}")
    print()
    
    # Exécuter les tests GUT
    os.chdir(project_dir)
    try:
        result = subprocess.run(
            [godot_cmd, '--headless', '-s', 'addons/gut/gut_cmdln.gd'] + sys.argv[1:],
            text=True
        )
        sys.exit(result.returncode)
    except KeyboardInterrupt:
        print("\nTests interrompus par l'utilisateur", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"Erreur lors de l'exécution des tests: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
