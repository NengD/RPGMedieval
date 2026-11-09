class_name OutfitData
extends Resource
## Une tenue complète : liste de pièces (ArmorData) et variante de couleur de chacune. Fichiers : data/outfits/*.tres.

@export var id: StringName = &""                   # tenue.chevalier_plates
@export var display_name: StringName = &""         # clé de traduction
@export var pieces: Array[StringName] = []         # identifiants de pièces (armure.*)
@export var variants: Dictionary = {}              # identifiant de pièce -> numéro de variante de couleur
