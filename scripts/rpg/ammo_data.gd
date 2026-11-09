class_name AmmoData
extends Resource
## Munition (flèche, carreau). Modèle : pointe à l'origine, hampe vers +Z Godot (voir tools/blender/make_weapons.py).

@export var id: StringName = &""                  # munition.fleche
@export var display_name: StringName = &""
@export var model: PackedScene
@export var length := 0.7
@export var damage_type: DamageType.Type = DamageType.Type.PERFORANT
@export var weight := 0.05
