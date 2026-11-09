class_name WeaponCategory
extends Resource
## Famille d'armes : épée à une main, hache, masse, lance, deux mains, bouclier, arc, arbalète.
## Elle porte le jeu d'animations commun (data/categories/*.tres). Tant qu'un pack Mixamo manque pour une
## famille, `anim_set` reste vide et elle réutilise le jeu de l'épée (voir docs/GUIDE_MIXAMO.md).

enum Kind { MELEE, SHIELD, BOW, CROSSBOW }

@export var id: StringName = &""                  # categorie.epee_une_main
@export var display_name: StringName = &""        # clé de traduction
@export var kind: Kind = Kind.MELEE
@export var two_handed := false
## Jeu d'animations : rôle -> nom d'animation de la bibliothèque (vide = jeu de l'épée).
@export var anim_set: Dictionary = {}
