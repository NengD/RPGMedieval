class_name EquipmentComponent
extends RefCounted
## Ce qu'un personnage porte. Étape 2 : armures (protection, poids, modificateurs de stats, sauvegarde).
## Les modèles 3D, les couches visibles et les armes arrivent aux étapes 3 et 4 sans changer cette interface.

signal changed

## Part du corps touchée en moyenne par emplacement (la somme fait 1) : sert à moyenner la protection.
const SLOT_SHARE := {
	ArmorData.Slot.TETE: 0.10, ArmorData.Slot.COU: 0.03, ArmorData.Slot.TORSE: 0.30, ArmorData.Slot.EPAULES: 0.07,
	ArmorData.Slot.BRAS: 0.12, ArmorData.Slot.MAINS: 0.04, ArmorData.Slot.TAILLE: 0.06, ArmorData.Slot.JAMBES: 0.22,
	ArmorData.Slot.PIEDS: 0.04, ArmorData.Slot.CAPE: 0.02,
}
## Dans un même emplacement, la meilleure couche compte en entier et les autres pour ce coefficient.
const LAYER_REST_WEIGHT := 0.25
const MAX_PROTECTION := 0.9

var stats: Stats
var combatant: Combatant
var items: Dictionary = {}   # "slot:couche" -> ArmorData


func _init(p_stats: Stats = null, p_combatant: Combatant = null) -> void:
	stats = p_stats
	combatant = p_combatant


static func _key(slot: int, layer: int) -> String:
	return "%d:%d" % [slot, layer]


func equip(piece: ArmorData) -> void:
	unequip(piece.slot, piece.layer)
	items[_key(piece.slot, piece.layer)] = piece
	_refresh_after(piece, true)


func unequip(slot: int, layer: int) -> ArmorData:
	var k := _key(slot, layer)
	var old: ArmorData = items.get(k)
	if old != null:
		items.erase(k)
		_refresh_after(old, false)
	return old


func get_piece(slot: int, layer: int) -> ArmorData:
	return items.get(_key(slot, layer))


func pieces() -> Array[ArmorData]:
	var out: Array[ArmorData] = []
	for k in items:
		out.append(items[k])
	return out


func total_weight() -> float:
	var w := 0.0
	for p in pieces():
		w += p.weight
	return w


## Protection moyenne du corps par type de dégâts : { Type -> 0..MAX_PROTECTION }.
func get_protection() -> Dictionary:
	var result := {}
	for t in [DamageType.Type.TRANCHANT, DamageType.Type.CONTONDANT, DamageType.Type.PERFORANT]:
		var total := 0.0
		for slot in SLOT_SHARE:
			var values: Array[float] = []
			for p in pieces():
				if p.slot == slot:
					values.append(float(p.protection().get(t, 0.0)))
			if values.is_empty():
				continue
			values.sort()
			values.reverse()
			var slot_value := values[0]
			for i in range(1, values.size()):
				slot_value += values[i] * LAYER_REST_WEIGHT
			total += float(SLOT_SHARE[slot]) * minf(slot_value, MAX_PROTECTION)
		result[t] = minf(total, MAX_PROTECTION)
	return result


## Parties du corps à cacher (l'étape 4 s'en sert pour l'affichage).
func hidden_regions() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in pieces():
		for r in p.hidden_body_regions:
			if not out.has(r):
				out.append(r)
	return out


func _refresh_after(piece: ArmorData, added: bool) -> void:
	var source := "equipement:%s" % piece.id
	if stats != null:
		stats.remove_by_source(source)
		if added:
			for m in piece.stat_modifiers:
				var copy := StatModifier.make(m.stat, m.flat, m.percent, source, m.duration)
				stats.add_modifier(copy)
		stats.carried_weight = total_weight()
	if combatant != null:
		combatant.protection = get_protection()
	changed.emit()


# ------------------------------------------------------------------ sauvegarde

func capture_state() -> Dictionary:
	var ids: Array = []
	for p in pieces():
		ids.append(str(p.id))
	return {"armure": ids}


func restore_state(d: Dictionary) -> void:
	for p in pieces():
		unequip(p.slot, p.layer)
	for id in d.get("armure", []):
		var piece := Registry.get_data(StringName(id)) as ArmorData
		if piece != null:
			equip(piece)
		else:
			push_warning("Pièce d'équipement inconnue à la restauration : %s" % id)
