class_name Enemy
extends CharacterBody3D
## Ennemi (capsule rouge sombre) avec une IA en machine à états.
## Décision (que faire ?) séparée du mouvement (comment y aller ?) :
##  - _update_defense : surveille tes attaques et décide de parer (de façon imparfaite) ;
##  - _decide : choisit s'approcher / tourner autour / attaquer / reculer et retourne la vitesse voulue ;
##  - _physics_process : applique la vitesse (avec gravité et collisions).

enum Mode { APPROACH, CIRCLE, ATTACK, DEFEND, RETREAT, STAGGERED, DEAD, COVER, EVADE }
const MODE_NAMES := ["s'approche", "tourne autour de toi", "attaque", "se défend", "RECULE (fatigué)", "déséquilibré", "vaincu", "se met à couvert", "charge en zigzag"]
const _BASE_COLOR := Color(0.55, 0.15, 0.18)

var combatant: Combatant
var weapon: WeaponVisual
var target: Player
var difficulty := GameConfig.DEFAULT_DIFFICULTY
var mode: int = Mode.APPROACH
var ai_enabled := GameConfig.ENEMY_AI_ENABLED_AT_START   # false = immobile, ne frappe pas, ne pare pas (comme un mannequin)
var aggressive := true           # false = il ne lance jamais d'attaque (pour s'entraîner / tests)

var _pivot: Node3D
var _mat: StandardMaterial3D
var _circle_sign := 1.0
var _circle_timer := 2.0
var _attack_cd := 1.5
var _last_dirs: Array = []
var _retreating := false
var _seen_threat := false
var _threat_time := 0.0
var _plan_parry := false
var _plan_dir := 0
var _plan_raise_at := 0.0
var _guard_wanted := false
var _guard_dir := 0
var _guard_release := 0.0
var _stuck_timer := 0.0
# face aux tirs
var cover_objects: Array = []        # [{pos: Vector3, radius: float}] donné par la scène (piliers, caisses)
var _arrow_guard := 0.0
var _handled_arrows := {}
var _cover_active := false
var _cover_point := Vector3.ZERO
var _cover_time := 0.0
var _cover_cooldown := 0.0
var _zig_sign := 1.0
var _zig_timer := 0.0


func _ready() -> void:
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PLAYER
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = GameConfig.ENEMY_RADIUS
	shape.height = GameConfig.ENEMY_HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = GameConfig.ENEMY_HEIGHT * 0.5
	add_child(col)

	_pivot = Node3D.new()
	add_child(_pivot)
	var capsule := CapsuleMesh.new()
	capsule.radius = GameConfig.ENEMY_RADIUS
	capsule.height = GameConfig.ENEMY_HEIGHT
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _BASE_COLOR
	capsule.material = _mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.position.y = GameConfig.ENEMY_HEIGHT * 0.5
	_pivot.add_child(mesh)
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.18, 0.18, 0.3)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.2, 0.2, 0.2)
	nose_mesh.material = nose_mat
	nose.mesh = nose_mesh
	nose.position = Vector3(0, GameConfig.ENEMY_HEIGHT * 0.5 + 0.55, -GameConfig.ENEMY_RADIUS)
	_pivot.add_child(nose)

	combatant = Combatant.new()
	combatant.body = self
	combatant.team = 1
	combatant.radius = GameConfig.ENEMY_RADIUS
	add_child(combatant)
	weapon = WeaponVisual.new()
	_pivot.add_child(weapon)
	weapon.bind(combatant)
	combatant.damaged.connect(_on_damaged)
	combatant.hit_resolved.connect(_on_hit_resolved)
	combatant.died.connect(_on_died)
	set_difficulty(difficulty)


func set_difficulty(level: int) -> void:
	difficulty = clampi(level, 0, 2)
	combatant.speed_scale = GameConfig.AI_SPEED_SCALE[difficulty]
	combatant.damage_scale = GameConfig.AI_DAMAGE_SCALE[difficulty]
	combatant.max_health = GameConfig.AI_MAX_HEALTH[difficulty]
	combatant.health = combatant.max_health


func reset_to(pos: Vector3) -> void:
	position = pos
	velocity = Vector3.ZERO
	combatant.reset()
	set_difficulty(difficulty)
	_pivot.rotation = Vector3.ZERO
	_pivot.position = Vector3.ZERO
	_mat.albedo_color = _BASE_COLOR
	_retreating = false
	_seen_threat = false
	_guard_wanted = false
	_last_dirs.clear()
	_cover_active = false
	_arrow_guard = 0.0
	_handled_arrows.clear()
	for child in get_children():
		if child is Arrow:
			child.queue_free()
	_attack_cd = 1.5
	if target:
		var to := target.global_position - global_position
		rotation.y = atan2(-to.x, -to.z)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var c := combatant
	if not is_on_floor():
		velocity.y -= GameConfig.GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	if c.dead:
		mode = Mode.DEAD
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return

	if not ai_enabled:
		combatant.set_guard(false, 0)
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		_cover_active = false
		move_and_slide()
		return

	var to := target.global_position - global_position
	to.y = 0.0
	var dist := maxf(to.length(), 0.01)
	var dir_to := to / dist
	if c.state != Combatant.State.STAGGER:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))

	_update_defense(delta, dist)
	var desired := _decide(delta, dist, dir_to)

	var factor := 1.0
	match c.state:
		Combatant.State.STAGGER:
			factor = 0.0
		Combatant.State.WINDUP, Combatant.State.STRIKE, Combatant.State.RECOVERY:
			factor = GameConfig.ATTACK_MOVE_FACTOR
	if c.guard_held:
		factor = minf(factor, GameConfig.GUARD_MOVE_FACTOR)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired * factor, GameConfig.ENEMY_ACCELERATION * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	# Anti-blocage (pilier, caisse) : si on veut avancer mais qu'on n'avance pas, on change de sens
	if desired.length() > 1.0 and factor > 0.5 and Vector3(velocity.x, 0.0, velocity.z).length() < 0.4:
		_stuck_timer += delta
		if _stuck_timer > 0.6:
			_circle_sign = -_circle_sign
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0


# ---------------------------------------------------------------- défense

func _update_defense(delta: float, dist: float) -> void:
	var c := combatant
	var pc := target.combatant
	var relevant: bool = pc.is_attacking() and not pc.dead \
		and dist <= GameConfig.MELEE_RANGE + GameConfig.ATTACK_REACH[pc.attack_dir] + GameConfig.PLAYER_RADIUS + 0.3
	if relevant and not c.is_attacking():
		if not _seen_threat:
			_seen_threat = true
			_threat_time = 0.0
			_plan_threat(pc)
		_threat_time += delta
		if _plan_parry and _threat_time >= _plan_raise_at:
			_guard_wanted = true
			_guard_dir = _plan_dir
			_guard_release = 0.3
	else:
		_seen_threat = false
		if _guard_wanted:
			_guard_release -= delta
			if _guard_release <= 0.0:
				_guard_wanted = false
	_check_arrows(delta)
	c.set_guard(_guard_wanted or _arrow_guard > 0.0, _guard_dir if _guard_wanted else Combatant.Dir.UP)


## Décide, une fois par coup du joueur, si l'ennemi tente de parer, de quel côté et quand.
func _plan_threat(pc: Combatant) -> void:
	var parry_chance: float = GameConfig.AI_PARRY_CHANCE[difficulty]
	_plan_parry = randf() < parry_chance
	if not _plan_parry:
		return
	var react: float = GameConfig.AI_REACTION_TIME[difficulty]
	var wrong: float = GameConfig.AI_WRONG_SIDE_CHANCE[difficulty]
	var perfect: float = GameConfig.AI_PERFECT_PARRY_CHANCE[difficulty]
	var needed := Combatant.mirror(pc.attack_dir)
	_plan_dir = needed
	if randf() < wrong:
		_plan_dir = (needed + 1 + randi() % 3) % 4   # un autre côté que le bon
	_plan_raise_at = react
	if randf() < perfect and pc.state == Combatant.State.WINDUP:
		# parade parfaite : lever la garde juste avant l'impact
		var impact_in := pc.state_duration - pc.state_time
		_plan_raise_at = maxf(react, impact_in - 0.12)


# ---------------------------------------------------------------- décision

func _decide(delta: float, dist: float, dir_to: Vector3) -> Vector3:
	var c := combatant
	var side := Vector3(-dir_to.z, 0.0, dir_to.x)
	_attack_cd -= delta
	_circle_timer -= delta
	if _circle_timer <= 0.0:
		if randf() < 0.5:
			_circle_sign = -_circle_sign
		_circle_timer = randf_range(1.5, 3.5)

	# Fatigue : il recule pour récupérer
	if c.exhausted or c.stamina < GameConfig.ENEMY_RETREAT_STAMINA:
		_retreating = true
	elif _retreating and c.stamina >= GameConfig.ENEMY_RESUME_STAMINA and not c.exhausted:
		_retreating = false

	var desired := Vector3.ZERO
	if c.state == Combatant.State.STAGGER:
		mode = Mode.STAGGERED
		return desired
	if _retreating:
		mode = Mode.RETREAT
		if dist < GameConfig.ENEMY_RETREAT_DISTANCE:
			desired = -dir_to * GameConfig.ENEMY_RETREAT_SPEED
		else:
			desired = side * _circle_sign * GameConfig.ENEMY_CIRCLE_SPEED * 0.4
	elif c.is_attacking() or c.state == Combatant.State.RECOVERY:
		mode = Mode.ATTACK
		if dist > 1.8:
			desired = dir_to * GameConfig.ENEMY_WALK_SPEED
	elif _guard_wanted:
		mode = Mode.DEFEND
		desired = side * _circle_sign * 0.8
	elif _ranged_threat(dist):
		desired = _ranged_response(delta, dist, dir_to, side)
	elif dist > GameConfig.ENEMY_ENGAGE_DISTANCE + 0.4:
		mode = Mode.APPROACH
		desired = dir_to * GameConfig.ENEMY_WALK_SPEED
	else:
		mode = Mode.CIRCLE
		desired = side * _circle_sign * GameConfig.ENEMY_CIRCLE_SPEED
		desired += dir_to * clampf(dist - GameConfig.ENEMY_CIRCLE_DISTANCE, -1.0, 1.0) * 1.5
		if aggressive and _attack_cd <= 0.0 and c.state == Combatant.State.IDLE and not _seen_threat \
				and not c.exhausted and c.stamina >= GameConfig.ENEMY_MIN_ATTACK_STAMINA and dist <= 3.3:
			_start_attack(dist)

	# Reste dans l'arène : près des murs, il est ramené vers le centre
	var p := global_position
	if maxf(absf(p.x), absf(p.z)) > GameConfig.ARENA_HALF_SIZE - 2.5:
		desired += Vector3(-p.x, 0.0, -p.z).normalized() * 2.0
	return desired


func _start_attack(dist: float) -> void:
	var dir := _choose_dir(dist)
	if not combatant.request_attack(dir):
		return
	var interval: float = GameConfig.AI_ATTACK_INTERVAL[difficulty]
	_attack_cd = interval * randf_range(0.8, 1.3)
	_last_dirs.append(dir)
	if _last_dirs.size() > 2:
		_last_dirs.pop_front()


## Direction variée : évite de répéter, et évite (parfois) le côté que le joueur garde.
func _choose_dir(dist: float) -> int:
	var w := [1.0, 1.0, 1.0, 1.0]
	if dist > GameConfig.MELEE_RANGE + GameConfig.PLAYER_RADIUS - 0.1:
		w = [0.0, 0.0, 1.0, 0.0]   # trop loin pour un coup de taille : seul l'estoc porte
	for d in _last_dirs:
		w[d] *= 0.35
	var pc := target.combatant
	var smart: float = GameConfig.AI_SMART_CHANCE[difficulty]
	if pc.guard_held and randf() < smart:
		for d in 4:
			if Combatant.mirror(d) == pc.guard_dir:
				w[d] *= 0.08
	var total := 0.0
	for x in w:
		total += x
	var roll := randf() * total
	for d in 4:
		roll -= w[d]
		if roll <= 0.0:
			return d
	return Combatant.Dir.UP


# ---------------------------------------------------------------- face aux tirs

## Le héros tient un arc ou une arbalète et reste à distance : l'ennemi doit réagir.
func _ranged_threat(dist: float) -> bool:
	var threat: bool = target.weapon_kind != Player.Weapon.SWORD and not target.combatant.dead \
		and dist > GameConfig.ENEMY_ENGAGE_DISTANCE + 1.0
	if not threat:
		_cover_active = false
	return threat


## Soit il se met derrière un pilier / une caisse, soit il charge en zigzag.
func _ranged_response(delta: float, _dist: float, dir_to: Vector3, side: Vector3) -> Vector3:
	_cover_cooldown -= delta
	if not _cover_active and _cover_cooldown <= 0.0:
		var chance: float = GameConfig.AI_COVER_CHANCE[difficulty]
		if randf() < chance and _find_cover():
			_cover_active = true
			_cover_time = GameConfig.ENEMY_COVER_MAX_TIME
		else:
			_cover_cooldown = 2.5   # nouvelle décision dans 2,5 s
	if _cover_active:
		mode = Mode.COVER
		_cover_time -= delta
		var to_cover := _cover_point - global_position
		to_cover.y = 0.0
		if _cover_time <= 0.0:
			_cover_active = false
			_cover_cooldown = 3.0
			return Vector3.ZERO
		if to_cover.length() > 0.5:
			return to_cover.normalized() * GameConfig.ENEMY_RETREAT_SPEED * 1.3
		return Vector3.ZERO   # arrivé : il attend à l'abri
	mode = Mode.EVADE
	_zig_timer -= delta
	if _zig_timer <= 0.0:
		_zig_sign = -_zig_sign
		_zig_timer = randf_range(0.35, 0.7)
	return dir_to * GameConfig.ENEMY_WALK_SPEED * GameConfig.ENEMY_CHARGE_SPEED_FACTOR + side * _zig_sign * GameConfig.ENEMY_ZIGZAG_SPEED


## Cherche le point d'abri le plus proche : derrière un obstacle, du côté opposé au tireur.
func _find_cover() -> bool:
	var best := Vector3.ZERO
	var best_dist := INF
	var shooter := target.global_position
	for obj in cover_objects:
		var center: Vector3 = obj.pos
		var away := Vector3(center.x - shooter.x, 0.0, center.z - shooter.z)
		if away.length() < 0.1:
			continue
		var point := center + away.normalized() * (float(obj.radius) + 0.8)
		point.y = 0.0
		if maxf(absf(point.x), absf(point.z)) > GameConfig.ARENA_HALF_SIZE - 1.3:
			continue
		if point.distance_to(shooter) < 4.0:
			continue
		var d := global_position.distance_to(point)
		if d < best_dist and d < 12.0:
			best_dist = d
			best = point
	if best_dist == INF:
		return false
	_cover_point = best
	return true


## Surveille les flèches en vol : s'il en voit une arriver, il lève la garde (selon sa difficulté).
func _check_arrows(delta: float) -> void:
	_arrow_guard = maxf(0.0, _arrow_guard - delta)
	if combatant.is_attacking() or combatant.dead:
		return
	var react: float = GameConfig.AI_REACTION_TIME[difficulty]
	var chest := global_position + Vector3(0.0, 1.1, 0.0)
	for node in get_tree().get_nodes_in_group(&"arrows"):
		var a := node as Arrow
		if a == null or not a.flying or a.team == combatant.team:
			continue
		var id := a.get_instance_id()
		if _handled_arrows.has(id) or a.age < react:
			continue   # il ne l'a pas encore vue partir
		var t_hit := a.time_to_reach(chest, 0.9)
		if t_hit < 0.0 or t_hit > 0.6:
			continue
		_handled_arrows[id] = true
		var chance: float = GameConfig.AI_ARROW_GUARD_CHANCE[difficulty]
		if randf() < chance:
			_arrow_guard = t_hit + 0.3
	if _handled_arrows.size() > 40:
		_handled_arrows.clear()


# ---------------------------------------------------------------- réactions

func _process(_delta: float) -> void:
	var col := _BASE_COLOR
	match combatant.state:
		Combatant.State.WINDUP, Combatant.State.STRIKE:
			col = Color(0.95, 0.25, 0.1)
		Combatant.State.STAGGER:
			col = Color(0.35, 0.55, 1.0)
	if combatant.dead:
		col = Color(0.25, 0.25, 0.25)
	_mat.albedo_color = _mat.albedo_color.lerp(col, 0.35)


func _on_damaged(amount: float, _attacker: Combatant) -> void:
	FloatingText.spawn(self, "-%d" % int(round(amount)), Color(1.0, 0.85, 0.2), GameConfig.ENEMY_HEIGHT + 0.1)
	_mat.albedo_color = Color(1, 1, 1)


func _on_hit_resolved(result: int, _dir: int, _amount: float, _attacker: Combatant) -> void:
	match result:
		Combatant.Result.BLOCKED:
			FloatingText.spawn(self, "paré", Color(0.5, 0.8, 1.0), GameConfig.ENEMY_HEIGHT + 0.1)
		Combatant.Result.PARRIED:
			FloatingText.spawn(self, "PARADE PARFAITE", Color(0.4, 1.0, 1.0), GameConfig.ENEMY_HEIGHT + 0.1)
		Combatant.Result.GUARD_BROKEN:
			FloatingText.spawn(self, "GARDE BRISÉE", Color(1.0, 0.55, 0.1), GameConfig.ENEMY_HEIGHT + 0.1)


func _on_died() -> void:
	_guard_wanted = false
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
