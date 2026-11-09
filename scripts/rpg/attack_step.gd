class_name AttackStep
extends Resource
## Un coup d'arme : son geste (animation), ses durées, son coût et sa portée.
## C'est ce qui remplace les tableaux ATTACK_* de game_config.gd (qui gardent les valeurs de l'épée longue).

## Numéro de geste : 0 haut, 1 droite, 2 estoc, 3 gauche (choisit l'animation et la pose de l'arme).
@export var slot := 0
@export var windup := 0.5       # préparation (s)
@export var strike := 0.12      # le coup lui-même (s)
@export var recovery := 0.5     # récupération (s)
@export var stamina := 24.0
@export var damage := 20.0
@export var reach := 0.0        # portée en plus de MELEE_RANGE (m)
@export var arc_deg := 110.0    # largeur du cône de frappe


static func make(p_slot: int, p_windup: float, p_strike: float, p_recovery: float, p_stamina: float, p_damage: float, p_reach: float, p_arc: float) -> AttackStep:
	var s := AttackStep.new()
	s.slot = p_slot
	s.windup = p_windup
	s.strike = p_strike
	s.recovery = p_recovery
	s.stamina = p_stamina
	s.damage = p_damage
	s.reach = p_reach
	s.arc_deg = p_arc
	return s
