class_name Stats
extends RefCounted
## Composant de statistiques d'un personnage : attributs, valeurs dérivées, modificateurs.
## Les attributs de base sont la seule vérité ; les valeurs dérivées sont recalculées à chaque lecture.

signal changed

const ATTRIBUTES: Array[StringName] = [&"force", &"endurance", &"agilite", &"vigueur"]
const FORMULAS_PATH := "res://data/stats_formulas.tres"

var formulas: StatsFormulas
var base: Dictionary = {}              # attribut -> valeur de base (10 = neutre)
var overrides: Dictionary = {}         # dérivé -> valeur de base imposée (ex. points de vie de l'ennemi)
var modifiers: Array[StatModifier] = []
var carried_weight := 0.0              # poids porté (mis à jour par l'équipement)


static func _default_derived() -> Dictionary:
	return {
		&"vie_max": GameConfig.PLAYER_MAX_HEALTH,
		&"endurance_max": GameConfig.STAMINA_MAX,
		&"recuperation_endurance": GameConfig.STAMINA_REGEN,
		&"vitesse_attaque": 1.0,
		&"charge_max": 40.0,
	}


func _init() -> void:
	if ResourceLoader.exists(FORMULAS_PATH):
		formulas = load(FORMULAS_PATH)
	if formulas == null:
		formulas = StatsFormulas.new()
	for a in ATTRIBUTES:
		base[a] = formulas.neutral


# ------------------------------------------------------------------ lecture

func _sum(stat: StringName) -> Vector2:   # x = plat, y = pourcentage
	var s := Vector2.ZERO
	for m in modifiers:
		if m.stat == stat:
			s.x += m.flat
			s.y += m.percent
	return s


func get_attribute(id: StringName) -> float:
	var s := _sum(id)
	return (float(base.get(id, formulas.neutral)) + s.x) * (1.0 + s.y)


func get_derived(id: StringName) -> float:
	var def: Dictionary = formulas.derived.get(id, {})
	var start: float = float(overrides[id]) if overrides.has(id) else float(_default_derived().get(id, 0.0))
	if not def.is_empty():
		start *= 1.0 + float(def["per_point"]) * (get_attribute(def["attribute"]) - formulas.neutral)
	var s := _sum(id)
	return (start + s.x) * (1.0 + s.y)


## Valeur d'une statistique quelconque (attribut ou dérivée).
func get_value(id: StringName) -> float:
	return get_attribute(id) if base.has(id) else get_derived(id)


func is_overloaded() -> bool:
	return carried_weight > get_derived(&"charge_max")


# ------------------------------------------------------------------ écriture

func set_base_derived(id: StringName, value: float) -> void:
	overrides[id] = value
	changed.emit()


func add_modifier(m: StatModifier) -> void:
	modifiers.append(m)
	changed.emit()


func remove_modifier(m: StatModifier) -> void:
	modifiers.erase(m)
	changed.emit()


## Retire tout ce qui vient d'une source (ex. quand on enlève une armure). Retourne le nombre retiré.
func remove_by_source(source: String) -> int:
	var before := modifiers.size()
	var kept: Array[StatModifier] = []
	for m in modifiers:
		if m.source != source:
			kept.append(m)
	modifiers = kept
	if modifiers.size() != before:
		changed.emit()
	return before - modifiers.size()


## Fait avancer les modificateurs temporaires.
func tick(delta: float) -> void:
	var expired := false
	for m in modifiers:
		if m.duration >= 0.0:
			m.time_left -= delta
			if m.time_left <= 0.0:
				expired = true
	if expired:
		var kept: Array[StatModifier] = []
		for m in modifiers:
			if m.duration < 0.0 or m.time_left > 0.0:
				kept.append(m)
		modifiers = kept
		changed.emit()


# ------------------------------------------------------------------ sauvegarde

func capture_state() -> Dictionary:
	var mods: Array = []
	for m in modifiers:
		mods.append(m.to_dict())
	var ov := {}
	for k in overrides:
		ov[str(k)] = overrides[k]
	var b := {}
	for k in base:
		b[str(k)] = base[k]
	return {"base": b, "overrides": ov, "modifiers": mods, "carried_weight": carried_weight}


func restore_state(d: Dictionary) -> void:
	for k in d.get("base", {}):
		base[StringName(k)] = float(d["base"][k])
	overrides.clear()
	for k in d.get("overrides", {}):
		overrides[StringName(k)] = float(d["overrides"][k])
	modifiers.clear()
	for md in d.get("modifiers", []):
		modifiers.append(StatModifier.from_dict(md))
	carried_weight = float(d.get("carried_weight", 0.0))
	changed.emit()
