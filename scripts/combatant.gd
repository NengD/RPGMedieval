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

enum State { IDLE, WINDUP, STRIKE, RECOVERY, STAGGER }
enum Dir { UP, RIGHT, DOWN, LEFT }
enum Result { HIT, BLOCKED, PARRIED, GUARD_BROKEN, DODGED }

var body: Node3D                 # le corps dans le monde (position / orientation)
var team := 0                    # 0 = héros, 1 = ennemis
var radius := 0.4
var max_health := GameConfig.PLAYER_MAX_HEALTH
var health := GameConfig.PLAYER_MAX_HEALTH
var invincible := false          # le mannequin ne meurt jamais
var dead := false
var damage_scale := 1.0
var speed_scale := 1.0           # > 1 : attaques plus rapides
var invulnerable := false        # activé par le pas de côté (esquive)

var state: int = State.IDLE
var state_time := 0.0
var state_duration := 0.0
var attack_dir: int = Dir.UP
var stagger_perfect := false     # déséquilibre causé par une parade parfaite

var guard_held := false
var guard_dir: int = Dir.UP
var guard_time := 0.0            # depuis combien de temps la garde est effective

var stamina := GameConfig.STAMINA_MAX
var exhausted := false

var _regen_timer := 0.0
var _strike_done := false
var _queued_dir := -1
var _queue_time := 0.0


## Côté de garde qu'il faut présenter face à un coup de direction `dir` (gauche/droite inversés).
static func mirror(dir: int) -> int:
	if dir == Dir.RIGHT:
		return Dir.LEFT
	if dir == Dir.LEFT:
		return Dir.RIGHT
	return dir


func _ready() -> void:
	add_to_group(&"combatants")


func reset() -> void:
	health = max_health
	stamina = GameConfig.STAMINA_MAX
	exhausted = false
	dead = false
	state = State.IDLE
	state_time = 0.0
	guard_held = false
	guard_time = 0.0
	invulnerable = false
	_regen_timer = 0.0
	_queued_dir = -1


func is_attacking() -> bool:
	return state == State.WINDUP or state == State.STRIKE


func is_busy() -> bool:
	return state != State.IDLE


## La garde protège seulement quand on est libre de ses mouvements et pas épuisé.
func is_guarding() -> bool:
	return guard_held and state == State.IDLE and not exhausted and not dead


func set_guard(held: bool, dir: int) -> void:
	if held and guard_held and dir != guard_dir:
		guard_time = 0.0   # changer de côté recommence la fenêtre de parade parfaite
	guard_held = held
	guard_dir = dir


func spend_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_regen_timer = GameConfig.STAMINA_REGEN_DELAY
	if stamina <= 0.0 and not exhausted:
		exhausted = true
		_regen_timer = GameConfig.EXHAUSTED_DELAY


func request_attack(dir: int) -> bool:
	if dead:
		return false
	if state == State.RECOVERY:
		_queued_dir = dir               # mémorisé : partira dès la fin de la récupération
		_queue_time = GameConfig.ATTACK_BUFFER
		return false
	if state != State.IDLE or exhausted or stamina <= 0.0:
		return false
	attack_dir = dir
	_strike_done = false
	spend_stamina(GameConfig.ATTACK_STAMINA[dir])
	var windup: float = GameConfig.ATTACK_WINDUP[dir]
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
func receive_hit(attacker: Combatant, dir: int, damage: float) -> int:
	if dead:
		return Result.DODGED
	if invulnerable:
		hit_resolved.emit(Result.DODGED, dir, 0.0, attacker)
		return Result.DODGED

	if is_guarding() and guard_dir == mirror(dir):
		# Bon côté : parade parfaite si la garde vient d'être levée
		if guard_time <= GameConfig.PERFECT_PARRY_WINDOW:
			attacker.stagger(GameConfig.PARRY_STAGGER, true)
			hit_resolved.emit(Result.PARRIED, dir, 0.0, attacker)
			return Result.PARRIED
		var cost := damage * GameConfig.BLOCK_STAMINA_FACTOR
		if stamina > cost:
			spend_stamina(cost)
			hit_resolved.emit(Result.BLOCKED, dir, 0.0, attacker)
			return Result.BLOCKED
		# Plus assez d'endurance : la garde se brise
		spend_stamina(stamina)
		var dealt := damage * GameConfig.GUARD_BREAK_DAMAGE_FACTOR
		stagger(GameConfig.GUARD_BREAK_STAGGER)
		take_damage(dealt, attacker)
		hit_resolved.emit(Result.GUARD_BROKEN, dir, dealt, attacker)
		return Result.GUARD_BROKEN

	# Mauvais côté ou pas de garde : le coup passe
	var dealt := damage * (GameConfig.STAGGER_DAMAGE_BONUS if state == State.STAGGER else 1.0)
	stagger(GameConfig.HIT_STUN)
	take_damage(dealt, attacker)
	hit_resolved.emit(Result.HIT, dir, dealt, attacker)
	return Result.HIT


func _physics_process(delta: float) -> void:
	if dead:
		return
	# Endurance
	if _regen_timer > 0.0:
		_regen_timer -= delta
	else:
		stamina = minf(GameConfig.STAMINA_MAX, stamina + GameConfig.STAMINA_REGEN * delta)
		if exhausted and stamina >= GameConfig.EXHAUSTED_RECOVER:
			exhausted = false
	guard_time = guard_time + delta if is_guarding() else 0.0
	_queue_time -= delta

	state_time += delta
	match state:
		State.WINDUP:
			if state_time >= state_duration:
				var strike: float = GameConfig.ATTACK_STRIKE[attack_dir]
				_enter(State.STRIKE, strike / speed_scale)
		State.STRIKE:
			_strike_check()
			if state_time >= state_duration:
				var recovery: float = GameConfig.ATTACK_RECOVERY[attack_dir]
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
		var reach: float = GameConfig.MELEE_RANGE + GameConfig.ATTACK_REACH[attack_dir]
		var arc: float = GameConfig.ATTACK_ARC_DEG[attack_dir]
		if dist > reach + c.radius:
			continue
		if dist > 0.01 and rad_to_deg(fwd.angle_to(to)) > arc * 0.5:
			continue
		_strike_done = true
		var dmg: float = GameConfig.ATTACK_DAMAGE[attack_dir] * damage_scale
		var result := c.receive_hit(self, attack_dir, dmg)
		strike_result.emit(result, c)
		return
