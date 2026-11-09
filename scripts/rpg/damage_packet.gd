class_name DamagePacket
extends RefCounted
## Un coup ou un tir : des dégâts répartis par type (permet les mélanges, ex. masse à pointes).

var amounts: Dictionary = {}   # DamageType.Type -> float
var source_id := ""            # identifiant de l'arme (arme.epee_longue), vide si inconnu


## Construit un paquet à partir d'un nombre (tout dans `default_type`) ou renvoie le paquet tel quel.
static func of(value: Variant, default_type: int = DamageType.Type.TRANCHANT) -> DamagePacket:
	if value is DamagePacket:
		return value
	var p := DamagePacket.new()
	p.amounts[default_type] = float(value)
	return p


static func mixed(total_amount: float, mix: Dictionary) -> DamagePacket:
	var p := DamagePacket.new()
	var sum := 0.0
	for k in mix:
		sum += float(mix[k])
	for k in mix:
		p.amounts[k] = total_amount * float(mix[k]) / maxf(sum, 0.0001)
	return p


func total() -> float:
	var t := 0.0
	for k in amounts:
		t += float(amounts[k])
	return t


## Type qui pèse le plus (pour la couleur des chiffres).
func dominant_type() -> int:
	var best: int = DamageType.Type.TRANCHANT
	var best_v := -1.0
	for k in amounts:
		if float(amounts[k]) > best_v:
			best_v = float(amounts[k])
			best = k
	return best


## Dégâts restants après protection ; protection = { Type -> part absorbée 0..1 }.
func after_protection(protection: Dictionary) -> float:
	var t := 0.0
	for k in amounts:
		t += float(amounts[k]) * (1.0 - clampf(float(protection.get(k, 0.0)), 0.0, 0.95))
	return t
