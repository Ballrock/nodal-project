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

## Stack

- **Moteur** : Godot 4.6
- **Langage** : GDScript uniquement
- **Renderer** : Forward Plus
