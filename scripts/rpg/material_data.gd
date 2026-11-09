class_name MaterialData
extends Resource
## Une matière d'armure (tissu, cuir, gambison, mailles, plaques) : part de chaque type de dégâts qu'elle absorbe.
## Fichiers : data/materials/*.tres (coefficients faciles à équilibrer).

@export var id: StringName = &""                 # materiau.mailles
@export var display_name: StringName = &""       # clé de traduction
@export var tranchant := 0.0
@export var contondant := 0.0
@export var perforant := 0.0


func protection() -> Dictionary:
	return {DamageType.Type.TRANCHANT: tranchant, DamageType.Type.CONTONDANT: contondant, DamageType.Type.PERFORANT: perforant}
