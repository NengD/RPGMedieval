class_name ArmorData
extends Resource
## Une pièce d'armure ou d'habit (les modèles 3D arrivent à l'étape 4). Données dans data/armor/*.tres.

enum Slot { TETE, COU, TORSE, EPAULES, BRAS, MAINS, TAILLE, JAMBES, PIEDS, CAPE }
enum Layer { VETEMENT, GAMBISON, MAILLES, PLAQUES, SURCOT }

@export var id: StringName = &""                 # armure.haubert_mailles
@export var display_name: StringName = &""       # clé de traduction
@export var slot: Slot = Slot.TORSE
@export var layer: Layer = Layer.VETEMENT
@export var material: MaterialData
@export var protection_override: Dictionary = {}  # { Type -> 0..1 } ; vide = coefficients de la matière
@export var coverage := 1.0                       # part du corps couverte par cette pièce (0..1)
@export var weight := 0.0                         # kg
@export var stat_modifiers: Array[StatModifier] = []
@export var hidden_body_regions: Array[StringName] = []
@export var model: PackedScene                    # .glb de assets/armor/ (coque skinnée sur le squelette de base)
## Variantes de couleur du tissu (matériaux « teinte_* » du modèle) ; vide = couleur d'origine.
@export var color_variants: Array[Color] = []


func protection() -> Dictionary:
	var src: Dictionary = protection_override if not protection_override.is_empty() else (material.protection() if material != null else {})
	var out := {}
	for k in src:
		out[k] = float(src[k]) * coverage
	return out
