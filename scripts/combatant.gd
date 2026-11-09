class_name Combatant
extends Node
## Cerveau du combat corps à corps, partagé par le héros, le mannequin et (étape 3) l'ennemi.
## Gère : attaque en 3 temps (préparation / coup / récupération), parade directionnelle,
## parade parfaite, endurance, déséquilibre, vie. Aucune dépendance à l'affichage.

signal attack_started(dir: int)
signal staggered(perfect: bool)
signal damaged(amount: float, attacker: Combatant)
## Côté victime : un coup vient d'être résolu (result = Result.*).
signal hit_resolved(result: int, dir: int, amount: float, attacker: Combatant)
## Côté attaquant : son coup a touché quelqu'un (result = ce qui est arrivé à la victime).
signal strike_result(result: int, victim: Combatant)
signal died
## Côté tireur : son tir a touché (result = Result.*, amount = dégâts, head = tir à la tête).
signal projectile_result(result: int, victim: Combatant, amount: float, head: bool)

enum State { IDLE, WINDUP, STRIKE, RECOVERY, STAGGER }
enum Dir { UP, RIGHT, DOWN, LEFT }
enum Result { HIT, BLOCKED, PARRIED, GUARD_BROKEN, DODGED }

var body: Node3D                 # le corps dans le monde (position / orientation)
var team := 0                    # 0 = héros, 1 = ennemis
var radius := 0.4
## Statistiques (attributs, valeurs dérivées, modificateurs). Avec les valeurs par défaut, tout vaut ce que
## donnait game_config.gd avant : le combat est identique.
var stats := Stats.new()
var equipment := EquipmentComponent.new(stats, self)
## Part de chaque type de dégâts absorbée par l'armure portée : { DamageType.Type -> 0..0,9 }
var protection: Dictionary = {}
## Type de dégâts du dernier coup reçu (pour la couleur des chiffres flottants).
var last_damage_type: int = DamageType.Type.TRANCHANT
var instance_id := ""
## Arme de mêlée tenue (null = épée longue d'origine, construite avec les valeurs de game_config.gd).
var weapon: WeaponData


func get_weapon() -> WeaponData:
	return weapon if weapon != null else WeaponData.default_sword()


## Le coup du geste `slot` (0 haut, 1 droite, 2 estoc, 3 gauche) avec l'arme tenue.
func attack_step(slot: int) -> AttackStep:
	return get_weapon().attack_for(slot)

var max_health: float:
	get: return stats.get_derived(&"vie_max")
	set(v): stats.set_base_derived(&"vie_max", v)
var health := GameConfig.PLAYER_MAX_HEALTH
var invincible := false          # le mannequin ne meurt jamais
var dead := false
var damage_scale := 1.0
var _speed_scale := 1.0
## > 1 : attaques plus rapides (réglage de difficulté × vitesse d'attaque des stats)
var speed_scale: float:
	get: return _speed_scale * stats.get_derived(&"vitesse_attaque")
	set(v): _speed_scale = v
var invulnerable := false        # activé par le pas de côté (esquive)

var state: int = State.IDLE
var state_time := 0.0
var state_duration := 0.0
var attack_dir: int = Dir.UP
var stagger_perfect := false     # déséquilibre causé par une parade parfaite

var guard_held := false
var guard_dir: int = Dir.UP
var guard_time := 0.0            # depuis combien de temps la garde est effective

var stamina := GameConfig.STAMINA_MAX   # même valeur que endurance_max par défaut
var exhausted := false

var _regen_timer := 0.0
var _strike_done := false
var _queued_dir := -1
var combo_index := 0
var _combo_idle := 0.0
const AUTO := 9              # request_attack(AUTO) : coup suivant du combo
var _queue_time := 0.0


func _ready() -> void:
	add_to_group(&"combatants")
	if body:
		body.set_meta(&"combatant", self)   # permet aux flèches de retrouver le combattant touché


func reset() -> void:
	health = max_health
	stamina = stats.get_derived(&"endurance_max")
	exhausted = false
	dead = false
	state = State.IDLE
	state_time = 0.0
	guard_held = false
	guard_time = 0.0
	invulnerable = false
	_regen_timer = 0.0
	_queued_dir = -1
	combo_index = 0
	_combo_idle = 0.0


func is_attacking() -> bool:
	return state == State.WINDUP or state == State.STRIKE


func is_busy() -> bool:
	return state != State.IDLE


## La garde protège seulement quand on est libre de ses mouvements et pas épuisé.
func is_guarding() -> bool:
	return guard_held and state == State.IDLE and not exhausted and not dead


func set_guard(held: bool, dir: int = GameConfig.GUARD_POSE) -> void:
	guard_held = held
	guard_dir = dir   # sert seulement à choisir la pose de garde affichée


func spend_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_regen_timer = GameConfig.STAMINA_REGEN_DELAY
	if stamina <= 0.0 and not exhausted:
		exhausted = true
		_regen_timer = GameConfig.EXHAUSTED_DELAY


func request_attack(dir: int = AUTO) -> bool:
	if dead:
		return false
	if state == State.RECOVERY:
		_queued_dir = dir               # mémorisé : partira dès la fin de la récupération
		_queue_time = GameConfig.ATTACK_BUFFER
		return false
	if state != State.IDLE or exhausted or stamina <= 0.0:
		return false
	if dir == AUTO:
		if _combo_idle > GameConfig.COMBO_RESET_TIME:
			combo_index = 0
		var order: Array[int] = get_weapon().combo_order
		dir = order[combo_index % order.size()]
		combo_index = (combo_index + 1) % order.size()
	attack_dir = dir
	_strike_done = false
	var step := attack_step(dir)
	spend_stamina(step.stamina)
	var windup: float = step.windup
	_enter(State.WINDUP, windup / speed_scale)
	attack_started.emit(dir)
	return true


## Un pas de côté peut interrompre la récupération.
func cancel_recovery() -> void:
	if state == State.RECOVERY:
		_queued_dir = -1
		_enter(State.IDLE, 0.0)


func stagger(duration: float, perfect := false) -> void:
	if state == State.STAGGER and state_duration - state_time >= duration:
		return
	_queued_dir = -1
	combo_index = 0
	stagger_perfect = perfect
	_enter(State.STAGGER, duration)
	staggered.emit(perfect)


func take_damage(amount: float, attacker: Combatant = null) -> void:
	if dead:
		return
	if not invincible:
		health = maxf(0.0, health - amount)
	damaged.emit(amount, attacker)
	if health <= 0.0 and not invincible:
		dead = true
		guard_held = false
		_enter(State.IDLE, 0.0)
		died.emit()


## Un coup arrive. Retourne un Result.
func receive_hit(attacker: Combatant, dir: int, damage_in: Variant) -> int:
	var packet := DamagePacket.of(damage_in, DamageType.Type.TRANCHANT)
	var damage := packet.total()
	last_damage_type = packet.dominant_type()
	if dead:
		return Result.DODGED
	if invulnerable:
		hit_resolved.emit(Result.DODGED, dir, 0.0, attacker)
		return Result.DODGED

	if is_guarding():
		# Parade parfaite si la garde vient d'être levée
		if guard_time <= GameConfig.PERFECT_PARRY_WINDOW:
			attacker.stagger(GameConfig.PARRY_STAGGER, true)
			hit_resolved.emit(Result.PARRIED, dir, 0.0, attacker)
			return Result.PARRIED
		var cost := damage * GameConfig.BLOCK_STAMINA_FACTOR * equipment.guard_cost_factor()
		if stamina > cost:
			spend_stamina(cost)
			hit_resolved.emit(Result.BLOCKED, dir, 0.0, attacker)
			return Result.BLOCKED
		# Plus assez d'endurance : la garde se brise
		spend_stamina(stamina)
		var dealt := packet.after_protection(protection) * GameConfig.GUARD_BREAK_DAMAGE_FACTOR
		stagger(GameConfig.GUARD_BREAK_STAGGER)
		take_damage(dealt, attacker)
		hit_resolved.emit(Result.GUARD_BROKEN, dir, dealt, attacker)
		return Result.GUARD_BROKEN

	# Pas de garde : le coup passe
	var dealt := packet.after_protection(protection) * (GameConfig.STAGGER_DAMAGE_BONUS if state == State.STAGGER else 1.0)
	stagger(GameConfig.HIT_STUN)
	take_damage(dealt, attacker)
	hit_resolved.emit(Result.HIT, dir, dealt, attacker)
	return Result.HIT


## Un tir (flèche, carreau) arrive. `dir` = direction de vol. Retourne un Result.
func receive_projectile(attacker: Combatant, damage_in: Variant, dir: Vector3, head: bool) -> int:
	var packet := DamagePacket.of(damage_in, DamageType.Type.PERFORANT)
	var damage := packet.total()
	last_damage_type = packet.dominant_type()
	if dead:
		return Result.DODGED
	if invulnerable:
		hit_resolved.emit(Result.DODGED, -1, 0.0, attacker)
		return Result.DODGED
	# La garde arrête les tirs venant de face (peu importe le côté choisi)
	var fwd := -body.global_transform.basis.z
	fwd.y = 0.0
	var to_shooter := Vector3(-dir.x, 0.0, -dir.z)
	var frontal := to_shooter.length() < 0.01 or fwd.normalized().angle_to(to_shooter.normalized()) <= deg_to_rad(GameConfig.GUARD_ARC_DEG * 0.5)
	if is_guarding() and frontal:
		if guard_time <= GameConfig.PERFECT_PARRY_WINDOW:
			hit_resolved.emit(Result.PARRIED, -1, 0.0, attacker)
			return Result.PARRIED
		var cost := damage * GameConfig.BLOCK_STAMINA_FACTOR * GameConfig.PROJECTILE_BLOCK_FACTOR * equipment.guard_cost_factor()
		if stamina > cost:
			spend_stamina(cost)
			hit_resolved.emit(Result.BLOCKED, -1, 0.0, attacker)
			return Result.BLOCKED
		spend_stamina(stamina)
		var broken := packet.after_protection(protection) * GameConfig.GUARD_BREAK_DAMAGE_FACTOR
		stagger(GameConfig.GUARD_BREAK_STAGGER)
		take_damage(broken, attacker)
		hit_resolved.emit(Result.GUARD_BROKEN, -1, broken, attacker)
		return Result.GUARD_BROKEN
	var dealt := packet.after_protection(protection) * (GameConfig.STAGGER_DAMAGE_BONUS if state == State.STAGGER else 1.0)
	if state != State.STAGGER:
		stagger(GameConfig.PROJECTILE_STUN)
	take_damage(dealt, attacker)
	hit_resolved.emit(Result.HIT, -1, dealt, attacker)
	return Result.HIT


func _physics_process(delta: float) -> void:
	if dead:
		return
	# Endurance
	if _regen_timer > 0.0:
		_regen_timer -= delta
	else:
		stamina = minf(stats.get_derived(&"endurance_max"), stamina + stats.get_derived(&"recuperation_endurance") * delta)
		if exhausted and stamina >= GameConfig.EXHAUSTED_RECOVER:
			exhausted = false
	guard_time = guard_time + delta if is_guarding() else 0.0
	_queue_time -= delta
	stats.tick(delta)
	_combo_idle = _combo_idle + delta if state == State.IDLE else 0.0

	state_time += delta
	match state:
		State.WINDUP:
			if state_time >= state_duration:
				var strike: float = attack_step(attack_dir).strike
				_enter(State.STRIKE, strike / speed_scale)
		State.STRIKE:
			_strike_check()
			if state_time >= state_duration:
				var recovery: float = attack_step(attack_dir).recovery
				_enter(State.RECOVERY, recovery / speed_scale)
		State.RECOVERY, State.STAGGER:
			if state_time >= state_duration:
				_enter(State.IDLE, 0.0)
	if state == State.IDLE and _queued_dir >= 0:
		var d := _queued_dir
		_queued_dir = -1
		if _queue_time > 0.0:
			request_attack(d)


func _enter(new_state: int, duration: float) -> void:
	state = new_state
	state_time = 0.0
	state_duration = duration


func _strike_check() -> void:
	if _strike_done or body == null:
		return
	var fwd := -body.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for node in get_tree().get_nodes_in_group(&"combatants"):
		var c := node as Combatant
		if c == null or c == self or c.team == team or c.dead or c.body == null:
			continue
		var to := c.body.global_position - body.global_position
		to.y = 0.0
		var dist := to.length()
		var reach: float = GameConfig.MELEE_RANGE + attack_step(attack_dir).reach
		var arc: float = attack_step(attack_dir).arc_deg
		if dist > reach + c.radius:
			continue
		if dist > 0.01 and rad_to_deg(fwd.angle_to(to)) > arc * 0.5:
			continue
		_strike_done = true
		var dmg: float = attack_step(attack_dir).damage * damage_scale
		var packet := DamagePacket.mixed(dmg, get_weapon().damage_mix)
		packet.source_id = str(get_weapon().id)
		var result := c.receive_hit(self, attack_dir, packet)
		strike_result.emit(result, c)
		return


# ---------------------------------------------------------------- sauvegarde

func capture_state() -> Dictionary:
	return {
		"vie": health,
		"endurance": stamina,
		"epuise": exhausted,
		"mort": dead,
		"stats": stats.capture_state(),
		"equipement": equipment.capture_state(),
	}


func restore_state(d: Dictionary) -> void:
	stats.restore_state(d.get("stats", {}))
	equipment.restore_state(d.get("equipement", {}))
	health = float(d.get("vie", max_health))
	stamina = float(d.get("endurance", stats.get_derived(&"endurance_max")))
	exhausted = bool(d.get("epuise", false))
	dead = bool(d.get("mort", false))
	state = State.IDLE
	state_time = 0.0
	guard_held = false
	_queued_dir = -1
