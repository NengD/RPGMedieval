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
var variants: Dictionary = {}   # "slot:couche" -> numéro de variante de couleur
var _batch := 0
## Armes tenues : emplacement -> WeaponData. Emplacements : main_hand (mêlée), off_hand (bouclier), bow, crossbow.
var weapons: Dictionary = {}
const REQUIREMENT_PENALTY := 0.03   # ralentissement des attaques par point d'attribut manquant


func _init(p_stats: Stats = null, p_combatant: Combatant = null) -> void:
	stats = p_stats
	combatant = p_combatant


static func _key(slot: int, layer: int) -> String:
	return "%d:%d" % [slot, layer]


func equip(piece: ArmorData, variant := 0) -> void:
	unequip(piece.slot, piece.layer)
	items[_key(piece.slot, piece.layer)] = piece
	variants[_key(piece.slot, piece.layer)] = variant
	_refresh_after(piece, true)


func unequip(slot: int, layer: int) -> ArmorData:
	var k := _key(slot, layer)
	var old: ArmorData = items.get(k)
	if old != null:
		items.erase(k)
		variants.erase(k)
		_refresh_after(old, false)
	return old


func get_variant(piece: ArmorData) -> int:
	return int(variants.get(_key(piece.slot, piece.layer), 0))


## Change la couleur d'une pièce déjà portée.
func set_variant(piece: ArmorData, variant: int) -> void:
	var k := _key(piece.slot, piece.layer)
	if items.has(k):
		variants[k] = variant
		changed.emit()


## Retire toute l'armure (les armes ne bougent pas).
func clear_armor() -> void:
	_batch += 1
	for p in pieces():
		unequip(p.slot, p.layer)
	_batch -= 1
	changed.emit()


## Équipe une tenue complète (un seul signal `changed` à la fin).
func equip_outfit(outfit: OutfitData) -> void:
	_batch += 1
	for p in pieces():
		unequip(p.slot, p.layer)
	for pid in outfit.pieces:
		var piece := Registry.get_data(pid) as ArmorData
		if piece != null:
			equip(piece, int(outfit.variants.get(str(pid), 0)))
		else:
			push_warning("Pièce de tenue inconnue : %s" % pid)
	_batch -= 1
	changed.emit()


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
	for slot in weapons:
		w += (weapons[slot] as WeaponData).weight
	return w


# ------------------------------------------------------------------ armes

static func slot_for(w: WeaponData) -> StringName:
	match w.kind():
		WeaponCategory.Kind.SHIELD: return &"off_hand"
		WeaponCategory.Kind.BOW: return &"bow"
		WeaponCategory.Kind.CROSSBOW: return &"crossbow"
	return &"main_hand"


func get_weapon(slot: StringName) -> WeaponData:
	return weapons.get(slot)


## Équipe une arme. Retourne false si c'est impossible (bouclier avec une arme à deux mains).
func equip_weapon(w: WeaponData) -> bool:
	var slot := slot_for(w)
	if slot == &"off_hand" and weapons.has(&"main_hand") and (weapons[&"main_hand"] as WeaponData).is_two_handed():
		return false
	var old: WeaponData = weapons.get(slot)
	if old != null:
		_remove_weapon_modifiers(old)
	weapons[slot] = w
	if slot == &"main_hand":
		if w.is_two_handed() and weapons.has(&"off_hand"):
			_remove_weapon_modifiers(weapons[&"off_hand"])
			weapons.erase(&"off_hand")
		if combatant != null:
			combatant.weapon = w
			combatant.combo_index = 0
	_apply_weapon_modifiers(w)
	_after_weapon_change()
	return true


func unequip_weapon(slot: StringName) -> void:
	var old: WeaponData = weapons.get(slot)
	if old == null:
		return
	_remove_weapon_modifiers(old)
	weapons.erase(slot)
	if slot == &"main_hand" and combatant != null:
		combatant.weapon = null
	_after_weapon_change()


## Part du coût d'endurance conservée en parant (bouclier = moins d'endurance).
func guard_cost_factor() -> float:
	var off: WeaponData = weapons.get(&"off_hand")
	return off.guard_cost_factor if off != null else 1.0


func missing_requirement_points(w: WeaponData) -> float:
	var missing := 0.0
	if stats == null:
		return 0.0
	for attr in w.stat_requirements:
		missing += maxf(0.0, float(w.stat_requirements[attr]) - stats.get_attribute(StringName(attr)))
	return missing


func _apply_weapon_modifiers(w: WeaponData) -> void:
	if stats == null:
		return
	var source := "equipement:%s" % w.id
	for m in w.stat_bonuses:
		stats.add_modifier(StatModifier.make(m.stat, m.flat, m.percent, source, m.duration))
	var missing := missing_requirement_points(w)
	if missing > 0.0:
		stats.add_modifier(StatModifier.make(&"vitesse_attaque", 0.0, -REQUIREMENT_PENALTY * missing, source))


func _remove_weapon_modifiers(w: WeaponData) -> void:
	if stats != null:
		stats.remove_by_source("equipement:%s" % w.id)


func _after_weapon_change() -> void:
	if stats != null:
		stats.carried_weight = total_weight()
	changed.emit()


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
	if _batch == 0:
		changed.emit()


# ------------------------------------------------------------------ sauvegarde

func capture_state() -> Dictionary:
	var ids: Array = []
	for p in pieces():
		ids.append(str(p.id))
	var weapon_ids := {}
	for slot in weapons:
		weapon_ids[str(slot)] = str((weapons[slot] as WeaponData).id)
	var variant_ids := {}
	for p in pieces():
		var v := get_variant(p)
		if v != 0:
			variant_ids[str(p.id)] = v
	return {"armure": ids, "armes": weapon_ids, "variantes": variant_ids}


func restore_state(d: Dictionary) -> void:
	_batch += 1
	for p in pieces():
		unequip(p.slot, p.layer)
	var saved_variants: Dictionary = d.get("variantes", {})
	for id in d.get("armure", []):
		var piece := Registry.get_data(StringName(id)) as ArmorData
		if piece != null:
			equip(piece, int(saved_variants.get(id, 0)))
		else:
			push_warning("Pièce d'équipement inconnue à la restauration : %s" % id)
	for slot in weapons.keys():
		unequip_weapon(slot)
	var saved: Dictionary = d.get("armes", {})
	for slot in saved:
		var w := Registry.get_data(StringName(saved[slot])) as WeaponData
		if w != null:
			equip_weapon(w)
		else:
			push_warning("Arme inconnue à la restauration : %s" % saved[slot])
	_batch -= 1
	changed.emit()
