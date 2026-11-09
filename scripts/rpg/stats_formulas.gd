class_name StatsFormulas
extends Resource
## Comment les attributs agissent sur les valeurs dérivées (data/stats_formulas.tres : équilibrage sans toucher au code).
## Une valeur dérivée = valeur de base × (1 + par_point × (attribut − attribut_neutre)).
## À attributs neutres, elle vaut exactement sa valeur de base : le combat reste identique à celui d'avant.

@export var neutral := 10.0
## id dérivé -> { "attribute": id d'attribut, "per_point": effet par point d'écart }
@export var derived: Dictionary = {
	&"vie_max": {"attribute": &"vigueur", "per_point": 0.03},
	&"endurance_max": {"attribute": &"endurance", "per_point": 0.03},
	&"recuperation_endurance": {"attribute": &"endurance", "per_point": 0.02},
	&"vitesse_attaque": {"attribute": &"agilite", "per_point": 0.015},
	&"charge_max": {"attribute": &"force", "per_point": 0.05},
}
