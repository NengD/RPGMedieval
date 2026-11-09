class_name StatModifier
extends Resource
## Un bonus ou malus sur une statistique (attribut ou valeur dérivée).
## Les modificateurs plats s'additionnent, les pourcentages aussi (jamais de produit : pas d'explosion).

@export var stat: StringName = &""
@export var flat := 0.0
@export var percent := 0.0           # 0.10 = +10 %
@export var source := ""             # "equipement:armure.gambison", "effet:potion_force", "blessure:bras"
@export var duration := -1.0         # secondes ; négatif = permanent
var time_left := -1.0


static func make(p_stat: StringName, p_flat: float, p_percent: float, p_source: String, p_duration := -1.0) -> StatModifier:
	var m := StatModifier.new()
	m.stat = p_stat
	m.flat = p_flat
	m.percent = p_percent
	m.source = p_source
	m.duration = p_duration
	m.time_left = p_duration
	return m


func to_dict() -> Dictionary:
	return {"stat": str(stat), "flat": flat, "percent": percent, "source": source, "duration": duration, "time_left": time_left}


static func from_dict(d: Dictionary) -> StatModifier:
	var m := make(StringName(str(d.get("stat", ""))), float(d.get("flat", 0.0)), float(d.get("percent", 0.0)), str(d.get("source", "")), float(d.get("duration", -1.0)))
	m.time_left = float(d.get("time_left", m.duration))
	return m
