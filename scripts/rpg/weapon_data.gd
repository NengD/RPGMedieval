class_name WeaponData
extends Resource
## Une arme (ou un bouclier). Fichiers : data/weapons/*.tres. Ajouter une arme = ajouter un fichier
## (voir docs/AJOUTER_UNE_ARME.md). Les chiffres de combat viennent d'ici, plus de game_config.gd.

@export var id: StringName = &""                      # arme.epee_longue
@export var display_name: StringName = &""            # clé de traduction
@export var category: WeaponCategory
@export var model: PackedScene                        # .glb : origine = prise, repères Grip_L / Tip / Nock_*
## Rotation (degrés) appliquée au modèle quand l'arme est tenue : pour une arme asymétrique (hache : le tranchant doit regarder devant).
@export var held_rotation_deg := Vector3.ZERO
@export var hands := 1                                # 1 ou 2 (la 2e main se pose sur le repère Grip_L)
@export var length := 1.0                             # m (indicatif : le modèle fait foi)
@export var weight := 1.5                             # kg

## Dégâts par type, en proportions (la somme est normalisée) : { DamageType.Type -> part }.
@export var damage_mix: Dictionary = {DamageType.Type.TRANCHANT: 1.0}
## Les coups, un par geste (index = AttackStep.slot : 0 haut, 1 droite, 2 estoc, 3 gauche).
@export var attacks: Array[AttackStep] = []
## Ordre d'enchaînement du combo (numéros de geste).
@export var combo_order: Array[int] = [1, 3, 0, 2]
## Bouclier : part du coût d'endurance conservée en parant (0,7 = parer coûte 30 % de moins).
@export var guard_cost_factor := 1.0

## Exigences : { attribut -> minimum }. Chaque point manquant ralentit les attaques (EquipmentComponent).
@export var stat_requirements: Dictionary = {}
@export var stat_bonuses: Array[StatModifier] = []
## Arc / arbalète : munition utilisée.
@export var ammo: AmmoData
## Sons (plus tard) : { événement -> chemin }.
@export var sounds: Dictionary = {}

static var _default_sword: WeaponData


func kind() -> int:
	return category.kind if category != null else WeaponCategory.Kind.MELEE


func is_two_handed() -> bool:
	return hands >= 2


func attack_for(slot: int) -> AttackStep:
	return attacks[clampi(slot, 0, attacks.size() - 1)]


## L'épée longue d'origine, construite avec les valeurs de game_config.gd. Sert quand un personnage n'a pas d'arme
## équipée : le combat est alors exactement celui d'avant.
static func default_sword() -> WeaponData:
	if _default_sword == null:
		_default_sword = from_config()
	return _default_sword


static func from_config() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"arme.epee_longue"
	w.display_name = &"ARME_EPEE_LONGUE"
	w.hands = 1
	w.weight = 1.4
	w.length = 1.0
	for i in 4:
		w.attacks.append(AttackStep.make(i, GameConfig.ATTACK_WINDUP[i], GameConfig.ATTACK_STRIKE[i], GameConfig.ATTACK_RECOVERY[i], GameConfig.ATTACK_STAMINA[i], GameConfig.ATTACK_DAMAGE[i], GameConfig.ATTACK_REACH[i], GameConfig.ATTACK_ARC_DEG[i]))
	w.combo_order = []
	for s in GameConfig.COMBO_ORDER:
		w.combo_order.append(int(s))
	return w


## Fabrique une arme de mêlée en modifiant les chiffres de l'épée longue (outil de génération des données).
## k : facteurs { "windup", "strike", "recovery", "stamina", "damage", "reach" (ajout en m), "arc" }
static func derived_melee(p_id: String, name_key: String, cat: WeaponCategory, p_model: PackedScene, p_hands: int, p_weight: float, mix: Dictionary, k: Dictionary, order: Array) -> WeaponData:
	var w := WeaponData.new()
	w.id = StringName(p_id)
	w.display_name = StringName(name_key)
	w.category = cat
	w.model = p_model
	w.hands = p_hands
	w.weight = p_weight
	w.damage_mix = mix
	for i in 4:
		w.attacks.append(AttackStep.make(i,
			GameConfig.ATTACK_WINDUP[i] * float(k.get("windup", 1.0)),
			GameConfig.ATTACK_STRIKE[i] * float(k.get("strike", 1.0)),
			GameConfig.ATTACK_RECOVERY[i] * float(k.get("recovery", 1.0)),
			GameConfig.ATTACK_STAMINA[i] * float(k.get("stamina", 1.0)),
			GameConfig.ATTACK_DAMAGE[i] * float(k.get("damage", 1.0)),
			GameConfig.ATTACK_REACH[i] + float(k.get("reach", 0.0)),
			GameConfig.ATTACK_ARC_DEG[i] * float(k.get("arc", 1.0))))
	w.combo_order = []
	for s in order:
		w.combo_order.append(int(s))
	return w
