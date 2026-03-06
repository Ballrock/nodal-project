# Spec : Interface Nodale sur Timeline

### TL;DR

POC d'une interface nodale drag & drop en Godot 4.6 / GDScript, inspirée des blueprints Unreal. Les **boîtes** (nodes) sont disposées sur un **axe temporel continu** (horizontal). Chaque boîte possède des **emplacements de liaison directionnels** (entrées à gauche, sorties à droite) reliables par des **câbles**. L'utilisateur peut configurer le nombre d'emplacements via une **interface secondaire**, **zoomer** sur une boîte (caméra + vue détaillée), et bénéficier d'un **magnétisme** à la fois sur les connexions et sur le positionnement temporel.

---

## 1. Glossaire

| Terme | Définition |
|---|---|
| **Boîte** (Box/Node) | Élément graphique rectangulaire représentant une unité logique, positionné sur la timeline |
| **Emplacement de liaison** (Slot) | Port d'entrée (gauche) ou de sortie (droite) sur une boîte, permettant de créer des connexions |
| **Câble** (Link/Wire) | Courbe de Bézier reliant un slot de sortie d'une boîte à un slot d'entrée d'une autre boîte |
| **Timeline** | Axe horizontal représentant le temps continu (en secondes), support de positionnement des boîtes |
| **Canvas** | Zone de travail 2D pannable et zoomable contenant la timeline et les boîtes |
| **Panneau de configuration** | Interface secondaire (panneau latéral) pour paramétrer une boîte sélectionnée |
| **Flotte** (Fleet) | Groupe de drones d'un même type (RIFF ou EMO) avec un nombre défini, géré via le volet latéral gauche |
| **Volet Flottes** (FleetPanel) | Panneau latéral gauche collapsible listant les flottes définies |
| **Dialogue de Flotte** (FleetDialog) | Dialogue modal centré pour créer ou modifier une flotte |
| **Figure Flotte** (FleetFigure) | Boîte spéciale non supprimable, sans entrées, avec un slot de sortie par flotte définie |

---

## 2. Architecture des scènes

```
Main (Control, plein écran)
├── VSplitContainer (séparation canvas / timeline NLE)
│   ├── CanvasArea (Control — zone de travail nodal, indépendante de la timeline)
│   │   ├── Background (ColorRect — fond sombre)
│   │   ├── FigureContainer (Control — parent de toutes les figures)
│   │   │   ├── Figure_0 (scène instanciée)
│   │   │   ├── Figure_1 …
│   │   │   └── Figure_N …
│   │   ├── LinksLayer (Control — rendu des câbles via _draw())
│   │   └── Minimap (Control — vue d'ensemble en bas à droite)
│   └── TimelinePanel (PanelContainer — panneau NLE en bas, ~200px)
│       ├── TimelineRuler (Control — graduation horizontale en secondes)
│       └── TrackAreaWrapper (Control — clip, expand)
│           └── TrackArea (Control — zone des segments, rangées dynamiques)
│               ├── TimelineSegment_0
│               └── TimelineSegment_N …
├── FleetPanel (PanelContainer — volet latéral gauche, overlay ~250px, collapsible)
│   ├── FleetPanelHeader (HBoxContainer — titre "Flottes" + bouton +)
│   └── FleetList (VBoxContainer — liste scrollable des flottes)
├── FleetDialog (Control — dialogue modal centré, masqué par défaut)
│   └── FleetForm (VBoxContainer — nom, type de drone, nombre)
├── ConfigPanel (Control — panneau latéral de configuration, masqué par défaut)
│   ├── SlotListEditor (liste d'emplacements modifiable)
│   └── FigurePropertiesEditor (propriétés générales de la figure)
├── Toolbar (HBoxContainer — barre d'outils en haut)
└── ZoomDetailOverlay (Control — vue détaillée plein écran d'une boîte, masquée par défaut)
```

---

## 3. La Timeline

> **Principe de découplage** : le canvas (partie haute) et la timeline (partie basse) sont **indépendants**.
> Le drag d'une boîte sur le canvas ne modifie pas sa position temporelle, et inversement.
> Seule la **sélection** est synchronisée (cliquer un clip sélectionne la boîte sur le canvas, et inversement).
> À terme, des **règles d'ordonnancement** pourront alerter l'utilisateur si l'ordre des nœuds sur le graphe ne correspond pas à leur position chronologique sur la timeline.

### 3.1. Représentation

- Le panneau Timeline NLE (en bas) affiche les clips sur un axe horizontal gradué en secondes.
- Échelle visuelle ajustée au niveau de zoom : plus on zoome, plus les subdivisions sont fines (→ millisecondes).
- Lignes verticales de graduation en arrière-plan du panneau (style grille).

### 3.2. Navigation

- **Pan** : clic molette maintenu + déplacement souris, ou clic droit maintenu + déplacement.
- **Scroll / Zoom (différencié par OS)** :
  - **Windows / Linux** :
    - Molette verticale (sans modificateur) → **scroll horizontal** (pan gauche/droite).
    - `Ctrl + Molette` → **zoom** timeline (centré sur le curseur). Facteur ×1.15 par cran.
  - **macOS** :
    - Scroll horizontal (trackpad deux doigts, ou `WHEEL_LEFT` / `WHEEL_RIGHT`) → **scroll horizontal** (pan gauche/droite).
    - `Ctrl + Molette verticale` → **zoom** timeline (centré sur le curseur). Facteur ×1.15 par cran.
    - La molette verticale seule ne fait rien sur la timeline (réservée au scroll natif du trackpad).
  - **Commun** : `WHEEL_LEFT` / `WHEEL_RIGHT` (molette horizontale matérielle) → scroll horizontal sur les deux OS.
- **Barre de défilement iOS-style** : lors de tout scroll ou zoom, une fine barre horizontale semi-transparente (4 px) apparaît en bas de la zone des segments. Elle reste visible ~0.8 s puis disparaît en fondu (0.4 s). La taille du « thumb » reflète le ratio largeur visible / durée totale (1 h).
- **Limites de zoom dynamiques** (calculées à partir de la largeur visible du track area)  :
  - Dézoom maximal : affiche environ **1 heure** de durée (`min_scale = largeur_visible / 3600`).
  - Zoom maximal : affiche environ **1 minute** de durée (`max_scale = largeur_visible / 60`).
  - Les bornes sont recalculées à chaque action de zoom pour s’adapter à la taille de la fenêtre.
- **Scroll horizontal** : limité à **1 heure maximum** (3600 s). Le temps 0 est toujours au bord gauche de la zone des segments.
- **Temps 0 au début** : la graduation et les segments partagent le même repère horizontal — le temps 0 s’affiche au bord gauche du panneau.

### 3.4. Panneau Timeline NLE (en bas)

- Panneau dédié en bas de l'écran (~200 px de haut), séparé du canvas par un `VSplitContainer` redimensionnable.
- Affiche les **boîtes sous forme de segments** (blocs rectangulaires colorés) positionnés horizontalement selon leur `start_time` / `end_time`.
- **Pistes multiples (tracks)** : chaque boîte est assignée à une piste (`track: int`). Les pistes sont empilées verticalement (~30 px de haut chacune). Les labels de pistes sont affichés à gauche (~120 px).
- **TimelineRuler** : graduation horizontale en haut du panneau, synchronisée avec l'échelle temporelle (`timeline_scale`).
- **Interactions sur les segments** :
  - **Drag horizontal** : déplace le segment dans le temps (modifie `start_time` et `end_time` en conservant la durée). **Indépendant** de la position de la boîte sur le canvas.
  - **Resize des bords** : zones de grip (5 px) aux extrémités gauche/droite du segment. Le curseur change en `CURSOR_HSIZE`. Modifie `start_time` (bord gauche) ou `end_time` (bord droit) individuellement.
  - **Sélection synchronisée** : cliquer un segment sélectionne la boîte correspondante sur le canvas, et inversement. Le segment sélectionné a un contour surligné.
- **Apparence des segments** : rectangle arrondi, couleur = `figure_data.color`, label = `figure_data.title`, hauteur = hauteur de la piste.
- **Scroll horizontal** synchronisé entre le ruler et la zone des segments.
- **Magnétisme** : le snap temporel (§3.3) s'applique aussi lors du drag/resize des segments.

### 3.3. Magnétisme temporel des boîtes

- Lors du drag d'une boîte, sa position X snappe sur les graduations temporelles les plus proches si elle est dans un **seuil de magnétisme** configurable (défaut : 20 px écran).
- Le snap est **optionnel** : maintenir `Shift` pendant le drag le désactive temporairement.
- Indicateur visuel : une ligne verticale surlignée apparaît quand le snap est actif.

---

## 4. Les Boîtes (Box)

### 4.1. Structure visuelle

```
┌──────────────────────────────┐
│  [Titre de la boîte]         │
├──────────────────────────────┤
│ ● input_0       output_0 ●  │
│ ● input_1       output_1 ●  │
│ ● input_2                    │
└──────────────────────────────┘
```

- **En-tête** : barre colorée avec le nom de la boîte (texte éditable par double-clic).
- **Corps** : zone contenant les emplacements de liaison, alignés verticalement.
  - Entrées (●) à gauche, sorties (●) à droite.
  - Chaque slot a un label optionnel.
- **Dimensions** : largeur fixe par défaut (200 px), hauteur dynamique basée sur le nombre de slots.
- **Bouton +** : en bas de la zone des slots, un bouton "+" ajoute une paire entrée+sortie. Le nombre d'entrées est toujours égal au nombre de sorties.
- **Suppression d'emplacement** : clic droit sur le cercle d'un slot → menu contextuel avec deux options :
  - **Supprimer le lien** : supprime uniquement le(s) câble(s) connecté(s) à ce slot (ne touche pas l'emplacement).
  - **Supprimer l'emplacement** (texte rouge) : supprime la paire entrée+sortie correspondante (même index) et tous les câbles associés.
- **Exception** : la boîte Flotte (§14.3) n'a ni bouton + ni menu contextuel — ses slots sont gérés automatiquement.

### 4.2. Drag & Drop

- Clic gauche maintenu sur l'en-tête → déplacement libre sur le canvas.
- La position Y est libre (pas de contrainte verticale).
- La position X correspond à un temps sur la timeline.
- Pendant le drag :
  - Tous les câbles connectés suivent en temps réel.
  - Le magnétisme temporel (X) s'applique (cf. §3.3).
  - Un **indicateur fantôme** semi-transparent montre la position finale snappée.

### 4.3. Sélection

- Clic gauche sur une boîte → sélection (contour surligné).
- `Ctrl + clic` → sélection multiple.
- Clic dans le vide → désélection.
- Rectangle de sélection (clic gauche maintenu dans le vide + drag) → sélection de toutes les boîtes dans la zone.

### 4.4. Actions contextuelles (clic droit sur une boîte)

- Supprimer la boîte
- Dupliquer la boîte
- Ouvrir le panneau de configuration
- Zoomer sur la boîte

### 4.5. Création de boîte

- Clic droit sur le canvas (zone vide) → menu contextuel → "Ajouter une boîte".
- La boîte est créée à la position du curseur (snappée sur la timeline).
- Nombre initial d'emplacements par défaut : 1 entrée, 1 sortie.

---

## 5. Emplacements de liaison (Slots)

### 5.1. Caractéristiques d'un slot

- **Direction** : `INPUT` ou `OUTPUT`.
- **Index** : position ordinale dans la boîte (0, 1, 2…).
- **Label** : nom affiché (ex: "signal_in", "data_out").
- **Couleur** : optionnellement typée (pour représenter des types de données différents).
- **Connecté** : état booléen (change l'apparence du cercle : plein si connecté, vide sinon).

### 5.2. Ajout/suppression d'emplacements

- **Ajout** : bouton "+" directement sur la boîte (§4.1). Ajoute une paire entrée+sortie.
- **Suppression** : clic droit sur un slot → menu contextuel → "Supprimer l'emplacement" supprime la paire entrée+sortie au même index, ainsi que tous les câbles attachés aux deux slots.
- **Suppression de lien seul** : clic droit sur un slot → "Supprimer le lien" ne supprime que le(s) câble(s) sans toucher l'emplacement.
- Le nombre minimum est 0 entrées et 0 sorties (boîte sans connexions possible).

---

## 6. Câbles (Links)

### 6.1. Création d'un câble

- Clic gauche maintenu sur un slot de **sortie** → drag → une courbe de Bézier suit la souris.
- Relâcher sur un slot d'**entrée** d'une autre boîte → connexion établie.
- Relâcher dans le vide ou sur un endroit invalide → annulation (la courbe disparaît).
- **Règles de connexion** :
  - Sortie → Entrée uniquement (pas sortie → sortie ni entrée → entrée).
  - Pas de connexion d'une boîte vers elle-même (pas de self-loop).
  - Un slot d'entrée n'accepte qu'un seul câble (1:1 côté entrée).
  - Un slot de sortie peut avoir plusieurs câbles vers des **boîtes différentes** (1:N côté sortie, mais au plus 1 lien par boîte cible). Cela modélise la division d'une flotte entre plusieurs boîtes.
  - **Remplacement automatique (même sortie → même boîte)** : si un slot de sortie est déjà relié à un slot d'entrée sur une boîte B et que l'utilisateur tire un nouveau câble depuis cette même sortie vers un autre slot d'entrée de la même boîte B, l'ancien lien est automatiquement remplacé par le nouveau.
  - **Remplacement automatique (entrée déjà occupée)** : si un slot d'entrée est déjà connecté à une sortie et que l'utilisateur tire un nouveau câble depuis une autre sortie vers ce même slot d'entrée, l'ancien lien est automatiquement remplacé par le nouveau. L'interface autorise le magnétisme (snap) vers un input déjà occupé.

### 6.2. Magnétisme des connexions

- Lors du drag d'un câble, quand le curseur passe à proximité d'un slot compatible (dans un **rayon de magnétisme** de 30 px), le bout du câble snappe automatiquement sur le slot cible.
- Feedback visuel : le slot cible s'illumine / grandit légèrement.
- Si plusieurs slots sont dans le rayon, le plus proche est prioritaire.

### 6.3. Rendu

- Courbe de Bézier cubique, du slot source au slot cible.
- Points de contrôle calculés horizontalement (style Unreal/Blender) pour un rendu fluide.
- Couleur : hérite de la couleur du slot source (ou couleur neutre par défaut).
- Épaisseur : 2 px (3 px au survol).
- Survol d'un câble → surbrillance + possibilité de clic droit → "Supprimer la connexion".

### 6.4. Suppression

- Clic droit sur un câble → "Supprimer la connexion" (si déverrouillé).
- Suppression d'une boîte → tous ses câbles sont automatiquement supprimés.
- Suppression d'un slot (via le panneau de config après déconnexion) → les câbles associés sont supprimés.

### 6.5. Verrouillage (Lock)

- **Interaction** : Clic droit sur le câble (la ligne elle-même) → menu contextuel "Verrouiller le lien" ou "Déverrouiller le lien".
- **Comportement** : 
  - Un lien verrouillé ne peut pas être supprimé manuellement via le menu contextuel (l'option "Supprimer la connexion" est grisée).
  - Par défaut, un lien est déverrouillé.
- **Indicateur visuel** : Une icône de cadenas blanc s'affiche au milieu du câble (position $t=0.5$ sur la courbe de Bézier) lorsque le lien est verrouillé.
- **Données** : La propriété `is_locked: bool` est stockée dans `LinkData` et persistée en JSON.

---

## 7. Panneau de configuration (ConfigPanel)

### 7.1. Ouverture

- Double-clic sur une boîte, ou clic droit → "Configurer".
- S'affiche en panneau latéral droit (slide-in, ~300 px de large).
- Ne masque pas le canvas (le canvas se redimensionne ou le panneau est en overlay).

### 7.2. Contenu

| Section | Champs |
|---|---|
| **Général** | Nom de la boîte (texte), couleur de l'en-tête (color picker) |
| **Entrées** | Liste ordonnée des slots d'entrée : label (texte) + bouton supprimer + bouton réordonner (drag) |
| **Sorties** | Liste ordonnée des slots de sortie : label (texte) + bouton supprimer + bouton réordonner (drag) |
| **Actions** | Bouton "Ajouter entrée", "Ajouter sortie" |

### 7.3. Comportement

- Les modifications sont appliquées **en temps réel** sur la boîte visible dans le canvas.
- La réorganisation des slots (drag dans la liste) met à jour les positions des câbles connectés.
- Fermeture : bouton ✕ ou clic en dehors du panneau, ou touche `Escape`.

---

## 8. Zoom sur une boîte

### 8.1. Zoom caméra centré

- Double-clic sur une boîte (ou raccourci `F` avec une boîte sélectionnée) → la caméra anime un déplacement + zoom pour centrer la boîte et l'afficher à une taille confortable (~60% de la viewport).
- Animation de transition : easing `ease_in_out`, durée 0.3s.
- Le contexte (câbles, boîtes voisines) reste visible autour.

### 8.2. Vue détaillée (overlay)

- Raccourci `Enter` sur une boîte sélectionnée, ou option du menu contextuel → "Vue détaillée".
- Ouvre un overlay plein écran (`ZoomDetailOverlay`) qui affiche :
  - La boîte agrandie au centre avec tous ses slots et câbles visibles.
  - Les boîtes directement connectées (voisins de 1er degré) en version réduite sur les côtés.
  - Le panneau de configuration intégré dans l'overlay (à droite).
- Fermeture : touche `Escape` ou bouton retour → retour à la vue canvas avec animation inverse.

---

## 9. Magnétisme — Récapitulatif

| Contexte | Cible du snap | Seuil par défaut | Désactivation |
|---|---|---|---|
| Drag d'une boîte (axe X) | Graduations de la timeline | 20 px écran | Maintenir `Shift` |
| Drag d'un câble | Slot compatible le plus proche | 30 px écran | Maintenir `Alt` |

Les seuils sont des constantes configurables dans un fichier de config (`res://config/settings.tres` ou autoload singleton).

---

## 10. Modèle de données

**FigureData (Resource)**
- `id: StringName` — identifiant unique
- `title: String` — nom affiché
- `position: Vector2` — position libre sur le canvas (indépendante de la timeline)
- `color: Color` — couleur de l'en-tête
- `start_time: float` — début de la figure sur la timeline (en secondes, défaut 0.0)
- `end_time: float` — fin de la figure sur la timeline (en secondes, défaut 1.0)
- `track: int` — rangée calculée dynamiquement sur le panneau timeline NLE (auto-layout, non éditable)
- `input_slots: Array[SlotData]`
- `output_slots: Array[SlotData]`

**SlotData (Resource)**
- `id: StringName` — identifiant unique
- `label: String` — nom affiché
- `direction: int` — enum `SLOT_INPUT = 0`, `SLOT_OUTPUT = 1`
- `index: int` — position ordinale

**LinkData (Resource)**
- `id: StringName` — identifiant unique
- `source_figure_id: StringName`
- `source_slot_id: StringName`
- `target_figure_id: StringName`
- `target_slot_id: StringName`

**GraphData (Resource) — conteneur racine**
- `figures: Array[FigureData]`
- `links: Array[LinkData]`
- `timeline_scale: float` — pixels par seconde

**FleetData (Resource) — données d'une flotte de drones**
- `id: StringName` — identifiant unique
- `name: String` — nom de la flotte
- `drone_type: int` — enum `DRONE_RIFF = 0`, `DRONE_EMO = 1`
- `drone_count: int` — nombre de drones (≥ 1)

> **Note** : les flottes sont stockées dans une ressource séparée (pas dans GraphData). Elles sont liées au graphe via les slots de sortie de la FleetFigure — les câbles dans `GraphData.links` pointent vers ces slots.

---

## 11. Structure des fichiers cible

```
res://
├── project.godot
├── config/
│   └── settings.tres           # Constantes (seuils magnétisme, zoom limits…)
├── scenes/
│   ├── main.tscn               # Scène principale
│   ├── figure.tscn                # Scène d'une boîte (instanciée)
│   ├── slot.tscn               # Scène d'un slot (instanciée dans box)
│   ├── config_panel.tscn       # Panneau de configuration
│   ├── fleet_panel.tscn        # Volet latéral gauche des flottes
│   ├── fleet_dialog.tscn       # Dialogue modal de création/édition de flotte
│   └── zoom_detail_overlay.tscn
├── scripts/
│   ├── main.gd                 # Orchestration, input routing
│   ├── menu_manager.gd         # Configuration et routage des menus (Fichier, Élément)
│   ├── graph_serializer.gd     # Sérialisation / désérialisation JSON du graphe
│   ├── canvas_workspace.gd     # Pan, zoom, gestion du canvas
│   ├── figure.gd                  # Logique de la boîte (drag, sélection)
│   ├── slot.gd                 # Logique d'un slot (détection hover/snap)
│   ├── links_layer.gd          # Rendu et gestion des câbles (_draw)
│   ├── config_panel.gd         # Logique du panneau de configuration
│   ├── fleet_panel.gd          # Logique du volet Flottes
│   ├── fleet_dialog.gd         # Logique du dialogue de flotte
│   ├── zoom_detail_overlay.gd  # Vue détaillée
│   ├── snap_helper.gd          # Utilitaire magnétisme (timeline + slots)
│   ├── timeline_panel.gd       # Panneau NLE en bas (pistes + segments)
│   ├── timeline_ruler.gd       # Graduation horizontale du panneau timeline
│   └── timeline_segment.gd     # Segment (bloc) représentant une boîte sur la timeline
├── data/
│   ├── figure_data.gd             # class_name FigureData extends Resource
│   ├── slot_data.gd            # class_name SlotData extends Resource
│   ├── link_data.gd            # class_name LinkData extends Resource
│   ├── graph_data.gd           # class_name GraphData extends Resource
│   └── fleet_data.gd           # class_name FleetData extends Resource
└── themes/
    └── default_theme.tres      # Theme Godot (StyleBox, fonts, couleurs)
```

---

## 12. Raccourcis clavier

| Touche | Action |
|---|---|
| `Ctrl + S` | Sauvegarder le schéma (Fichier → Sauvegarder) |
| `Ctrl + O` | Charger un schéma (Fichier → Charger) |
| `Molette` (sur le canvas) | Zoom canvas (25%–100%, centré sur curseur) |
| `Molette` (sur la timeline, Windows/Linux) | Scroll horizontal timeline (pan gauche/droite) |
| `Ctrl + Molette` (sur la timeline) | Zoom timeline (centré sur curseur, bornes dynamiques 1min–1h) |
| `Scroll horizontal` (sur la timeline, macOS trackpad) | Scroll horizontal timeline (pan gauche/droite) |
| `Ctrl + Molette verticale` (sur la timeline, macOS) | Zoom timeline (centré sur curseur, bornes dynamiques 1min–1h) |
| `Clic molette` / `Clic droit + drag` | Pan canvas |
| `F` | Zoom caméra sur la boîte sélectionnée |
| `Enter` | Ouvrir la vue détaillée de la boîte sélectionnée |
| `Escape` | Fermer panneau/overlay, désélectionner |
| `Delete` / `Backspace` | Supprimer la sélection (boîtes + câbles) |
| `Ctrl + D` | Dupliquer la sélection |
| `Ctrl + A` | Tout sélectionner |
| `Shift` (maintenu) | Désactiver le magnétisme timeline pendant un drag |
| `Alt` (maintenu) | Désactiver le magnétisme des slots pendant un drag câble |
| `Escape` | Ferme aussi le FleetDialog si ouvert |

---

## 13. Vérification

- **Unitaire** : créer/supprimer une boîte, ajouter/retirer des slots, créer/supprimer un câble via script → vérifier la cohérence de `GraphData`.
- **Visuel** : lancer la scène → vérifier le rendu des boîtes, câbles Bézier, grille timeline.
- **Interaction** : drag boîte + vérifier snap timeline, drag câble + vérifier snap slot, zoom/pan fluide.
- **Panneau config** : ouvrir, modifier le nombre de slots, vérifier la mise à jour en temps réel.
- **Zoom** : `F` → animation vers la boîte, `Enter` → overlay détaillé, `Escape` → retour.
- **Flottes** : créer/modifier/supprimer une flotte → vérifier cohérence liste volet + slots FleetFigure + câbles.
- **Slots inline** : bouton + sur boîte classique → vérifier ajout de paire. Clic droit → menu contextuel → supprimer lien ou emplacement.
- **Connexions FleetFigure** : sortie FleetFigure → entrée boîte classique → câble établi, définit la flotte utilisée.

---

## 14. Volet Flottes (FleetPanel)

### 14.1. Position et apparence

- Panneau latéral **gauche**, largeur ~250 px, intégré dans un **HBoxContainer** (`CanvasHBox`) qui pousse la zone nodale horizontalement.
- Le FleetPanel **ne couvre pas** la timeline (la timeline occupe toute la largeur en bas).
- Style sombre cohérent avec le thème existant (fond semi-transparent `(0.12, 0.12, 0.15, 0.95)`).
- **Collapsible** via un bouton flèche (`◀`/`▶`) dans le header du volet.
- État initial : volet **déplié** au lancement.

### 14.2. Structure

- **Header** : titre "Flottes" à gauche, bouton **"+"** à droite.
  - Clic sur "+" → ouvre le FleetDialog (§15) en mode création.
  - Bouton flèche pour collapse/expand.
- **Corps** : liste verticale scrollable (`ScrollContainer` > `VBoxContainer`) des flottes.
  - Chaque flotte est affichée par son **nom** (un `Button` ou `Label` cliquable).
  - Clic sur un nom → ouvre le FleetDialog (§15) en mode édition de cette flotte.

### 14.3. Figure Flotte (FleetFigure)

- Boîte spéciale **créée automatiquement** au lancement du projet, **non supprimable**, **non duplicable**.
- **0 entrées**, autant de **sorties** que de flottes définies dans le volet.
- Chaque slot de sortie porte le **nom de la flotte** comme label.
- Visuellement distincte : couleur d'en-tête **verte** (`Color(0.33, 0.75, 0.42)`) pour la différencier des boîtes classiques.
- Draggable normalement sur le canvas.
- Non configurable via ConfigPanel — ses slots sont synchronisés automatiquement avec la liste des flottes.
- Pas de boutons +/− (les slots sont gérés par les opérations de création/suppression de flotte).

---

## 15. Dialogue de Flotte (FleetDialog)

### 15.1. Apparence

- Dialogue **modal** centré à l'écran.
- Fond assombri (`ColorRect` plein écran avec couleur `(0, 0, 0, 0.5)`).
- Panneau central (~400 px de large) avec fond sombre et bordure.

### 15.2. Champs du formulaire

| Champ | Type de contrôle | Contraintes |
|---|---|---|
| **Nom de la flotte** | `LineEdit` | Obligatoire, non vide |
| **Type de drone** | `OptionButton` avec options `RIFF` / `EMO` | Sélection obligatoire |
| **Nombre de drones** | `SpinBox` | Min 1, pas de max |

### 15.3. Boutons

- **Valider** : crée (mode création) ou met à jour (mode édition) la flotte.
  - En mode création : la flotte est ajoutée à la liste du volet **et** un slot de sortie correspondant est ajouté à la FleetFigure.
  - En mode édition : les données sont mises à jour, le label du slot de sortie correspondant dans la FleetFigure est mis à jour.
- **Annuler** : ferme le dialogue sans sauvegarder.
- **Supprimer** (mode édition uniquement) : supprime la flotte de la liste, supprime le slot de sortie correspondant de la FleetFigure, et nettoie tous les câbles associés.

### 15.4. Fermeture

- Bouton Annuler, touche `Escape`, ou clic sur le fond assombri.

---

## 16. Sérialisation / Désérialisation (Sauvegarde & Chargement)

### 16.1. Format

- Le graphe est sauvegardé au format **JSON** (`.json`), plus portable et lisible qu'un `.tres`.
- Version du format incluse (`version: 1`) pour compatibilité ascendante.

### 16.2. Contenu sauvegardé

| Donnée | Description |
|---|---|
| `version` | Entier (actuellement `1`) |
| `canvas_zoom` | Niveau de zoom du canvas (`float`, 0.25 – 1.0) |
| `timeline_scale` | Échelle de la timeline en px/s |
| `figures` | Tableau de toutes les figures (y compris la FleetFigure marquée `is_fleet_figure: true`) avec leurs slots, position, couleur, times… |
| `links` | Tableau de tous les câbles (ID source/cible figure + slot) |
| `fleets` | Tableau des flottes définies |
| `fleet_to_slot` | Mapping `fleet.id → slot.id` pour reconstruire la correspondance FleetFigure ↔ Flottes |

### 16.3. Sauvegarde

- Menu **Fichier → Sauvegarder** (`Ctrl+S`) → ouvre un `FileDialog` en mode sauvegarde.
- L'utilisateur choisit le chemin et le nom du fichier (filtre `*.json`).
- Le `GraphSerializer` collecte l'état complet (figures, liens, flottes, zoom, timeline) et écrit le JSON.

### 16.4. Chargement

- Menu **Fichier → Charger** (`Ctrl+O`) → ouvre un `FileDialog` en mode ouverture.
- Le fichier JSON est lu et parsé par `GraphSerializer`.
- L'état actuel est entièrement **effacé** (`_clear_graph`) puis **reconstruit** :
  1. Restauration du zoom canvas et de l'échelle timeline.
  2. Création des figures (la FleetFigure est identifiée par `is_fleet_figure` et recréée avec ses slots sauvegardés).
  3. Alimentation du volet Flottes.
  4. Reconstruction du mapping `fleet → slot`.
  5. Ajout des liens.
  6. Synchronisation de la timeline.

### 16.5. Scripts

| Fichier | Rôle |
|---|---|
| `scripts/graph_serializer.gd` | Classe statique `GraphSerializer` — sérialise/désérialise le graphe en JSON, lecture/écriture fichier |
| `scripts/menu_manager.gd` | Classe `MenuManager` — configure les PopupMenu (Fichier, Élément), émet les signaux `save_requested`, `load_requested`, `add_figure_requested` |

---

## 17. Workspace dynamique et Minimap

### 17.1. Workspace dynamique

- **Taille par défaut** : Le `FigureContainer` possède une taille initiale par défaut (ex: 5000x5000 px) pour permettre un confort de travail immédiat.
- **Auto-expansion** : Lorsqu'une figure est déplacée et qu'elle s'approche des bords du `FigureContainer` (marge de ~200 px), la taille du container s'agrandit automatiquement dans la direction du mouvement pour accueillir le nouveau contenu.
- **Auto-réduction** : Si l'espace devient superflu (figures supprimées ou regroupées vers le centre), le container réduit sa taille progressivement, sans jamais descendre en dessous de la taille minimale par défaut.
- **Centrage initial** : Au lancement ou lors d'un nouveau projet, la vue est centrée sur le milieu du workspace.

### 17.2 Minimap

- **Position** : Ancrée en **bas à droite** de la `CanvasArea`.
- **Apparence** : 
  - Rectangle semi-transparent (fond sombre type `(0, 0, 0, 0.3)`).
  - Taille fixe ou proportionnelle (ex: 200x150 px).
  - Affiche une representation simplifiée de toutes les figures du workspace (petits rectangles colorés).
  - Affiche les **liaisons** (câbles) entre les figures sous forme de lignes simples.
- **Indicateur de vue (Viewport)** : Un rectangle (souvent appelé "view rectangle" ou "gizmo") représente la zone actuellement visible par l'utilisateur sur le canvas.
- **Interaction** :
  - Cliquer ou draguer dans la minimap déplace instantanément la vue du canvas vers la zone correspondante.
  - La minimap se met à jour en temps réel lors du déplacement des figures, des liens ou du pan/zoom du canvas.


---

## 18. Icônes et Polices

### 18.1. Librairie d'icônes
Le projet utilise **Material Symbols** de Google (version Variable Font). Trois variantes sont disponibles dans `res://assets/fonts/` :
- `material_symbols_outlined.ttf`
- `material_symbols_rounded.ttf` (Recommandé par défaut)
- `material_symbols_sharp.ttf`

### 18.2. Utilisation via l'éditeur (UI)
Pour afficher une icône dans un `Label` ou un `Button` :
1. Dans l'inspecteur du nœud, allez dans **Theme Overrides > Fonts** et glissez l'un des fichiers `.ttf`.
2. Dans le champ **Text**, tapez le nom de l'icône en minuscules (ex: `settings`, `lock`, `add_circle`). Les ligatures transformeront automatiquement le texte en icône.
3. Pour changer le style (remplissage, épaisseur) :
   - Créez une **FontVariation** sur le slot Font.
   - Dans **Variation Coordinates**, ajoutez des axes :
     - `FILL` : `1.0` pour une icône pleine, `0.0` pour un contour.
     - `wght` : Épaisseur de 100 à 700 (400 par défaut).

### 18.3. Utilisation via Code (Rendu personnalisé)
Pour dessiner une icône dans un script via `_draw()` :
```gdscript
var font = preload("res://assets/fonts/material_symbols_rounded.ttf")
var icon_name = "lock"
var font_size = 16

# Calculer la taille pour le centrage
var size = font.get_string_size(icon_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
var pos = center_pos - Vector2(size.x / 2.0, -size.y / 4.0) # Ajustement ligne de base

draw_string(font, pos, icon_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
```


---

## Décisions techniques

- **GDScript** retenu comme langage unique.
- **Timeline continue** (secondes) plutôt que colonnes discrètes — offre plus de flexibilité au positionnement.
- **Liaisons directionnelles** (entrée/sortie) à la manière Unreal — un slot d'entrée accepte un seul câble, un slot de sortie peut en avoir plusieurs.
- **Zoom = caméra + vue détaillée** — deux niveaux complémentaires pour naviguer.
- **Zoom canvas via `scale` sur un nœud wrapper `CanvasContent`** : le zoom (25%–100%) est appliqué en modifiant `CanvasContent.scale`. Les coordonnées logiques des figures (`FigureData.position`) ne changent pas. `LinksLayer` utilise `to_local()` pour un rendu correct quelle que soit la transformation.
- **Rangées dynamiques timeline** : les segments sont répartis automatiquement sur des rangées par un algorithme d’interval partitioning greedy (tri par `start_time`, placement dans la première rangée libre). Pas de pistes fixes ni de labels à gauche. Les rangées sont recalculées après chaque déplacement ou resize de segment.
- **Scroll horizontal limité à 1 h** : le décalage horizontal de la timeline est borné entre 0 et `time_to_pixel(3600, scale) - largeur_visible`. Le temps 0 est toujours aligné avec le bord gauche de la zone des segments.
- **Zoom timeline avec bornes dynamiques** : la molette sur la timeline modifie `timeline_scale` (px/s), borné dynamiquement pour afficher entre 1 minute (zoom max) et 1 heure (dézoom max). Le temps sous le curseur reste fixe après zoom.
- Câbles rendus via `_draw()` sur un `Control` dédié (`LinksLayer`) plutôt que des `Line2D` individuels — meilleure perf et contrôle du rendu.
- Modèle de données basé sur des `Resource` Godot. Sauvegarde/chargement via **JSON** (`GraphSerializer`) pour portabilité et lisibilité.
- **FleetData séparée de GraphData** : ressource indépendante stockée dans son propre fichier. Liée au graphe via les slots de sortie de la FleetFigure (les câbles dans `GraphData.links` pointent vers ces slots).
- **Volet Flottes intégré (push)** : le FleetPanel est placé dans un `HBoxContainer` avec le `CanvasArea`, poussant la zone nodale horizontalement. Il ne couvre pas la timeline.
- **Dialogue modal** : bloque l'interaction avec le canvas pendant l'édition d'une flotte.
- **Contrainte #entrées = #sorties** pour les boîtes classiques : ajouter une entrée ajoute automatiquement une sortie, idem pour la suppression. La FleetFigure en est exemptée (0 entrées, N sorties).
- **Gestion inline des slots** : bouton "+" directement sur la boîte pour ajouter, clic droit → menu contextuel pour supprimer un lien ou un emplacement.
- **Liens stockés par ID** : `LinksLayer` stocke les liens par `SlotData.id` / `FigureData.id` et résout les nœuds `Slot` à la volée, pour survivre aux reconstructions de la scène interne des figures (_build_slots).
- **Gestion des menus externalisée** : la classe `MenuManager` (RefCounted) configure les PopupMenu et émet des signaux, pour découpler la logique menu de `main.gd`.
- **Sérialisation JSON** : `GraphSerializer` convertit l'état complet du graphe (figures, liens, flottes, zoom, timeline_scale, mapping fleet→slot) en JSON. Le chargement efface puis reconstruit l'état.
