class_name Player
extends CharacterBody3D
## Héros (capsule) : déplacement, pas de côté, et combat à l'épée (via Combatant).

var spawn_yaw := 0.0
var rig: CameraRig
var combatant: Combatant
var weapon: WeaponVisual
var facing_yaw := 0.0
var invulnerable := false
var is_dodging := false
## Direction choisie pour attaquer / parer : 0 haut, 1 droite, 2 bas, 3 gauche
var aim_dir: int = Combatant.Dir.UP
var aim_accum := Vector2.ZERO

var _body_pivot: Node3D
var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_elapsed := 0.0
var _dodge_cooldown := 0.0
var _dodge_dir := Vector3.ZERO
var _assist_yaw := NAN


func _ready() -> void:
	collision_layer = GameConfig.LAYER_PLAYER
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_ENEMY
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(GameConfig.MAX_SLOPE_DEG)

	var shape := CapsuleShape3D.new()
	shape.radius = GameConfig.PLAYER_RADIUS
	shape.height = GameConfig.PLAYER_HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = GameConfig.PLAYER_HEIGHT * 0.5
	add_child(col)

	# Apparence : capsule bleue + "nez" clair pour voir où regarde le héros
	_body_pivot = Node3D.new()
	_body_pivot.position.y = GameConfig.PLAYER_HEIGHT * 0.5
	add_child(_body_pivot)
	var capsule := CapsuleMesh.new()
	capsule.radius = GameConfig.PLAYER_RADIUS
	capsule.height = GameConfig.PLAYER_HEIGHT
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.45, 0.9)
	capsule.material = body_mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	_body_pivot.add_child(mesh)
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.18, 0.18, 0.3)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.95, 0.9, 0.7)
	nose_mesh.material = nose_mat
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 0.55, -GameConfig.PLAYER_RADIUS)
	_body_pivot.add_child(nose)

	# Combat
	combatant = Combatant.new()
	combatant.body = self
	combatant.team = 0
	combatant.radius = GameConfig.PLAYER_RADIUS
	add_child(combatant)
	weapon = WeaponVisual.new()
	add_child(weapon)
	weapon.bind(combatant)

	facing_yaw = spawn_yaw
	rotation.y = facing_yaw
	rig = CameraRig.new()
	rig.target = self
	rig.yaw = spawn_yaw
	add_child(rig)


func toggle_view() -> void:
	rig.toggle_view()


func facing_vector() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


func reset_to(pos: Vector3, yaw: float) -> void:
	position = pos
	velocity = Vector3.ZERO
	rig.yaw = yaw
	facing_yaw = yaw
	rotation.y = yaw
	is_dodging = false
	invulnerable = false
	_body_pivot.rotation = Vector3.ZERO
	combatant.reset()
	rig.snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed(&"toggle_view"):
		toggle_view()
	elif event is InputEventMouseMotion and captured:
		aim_accum += (event as InputEventMouseMotion).screen_relative
	elif event.is_action_pressed(&"attack") and captured:
		try_attack()


func _process(_delta: float) -> void:
	_body_pivot.visible = rig.blend > 0.25   # le corps disparaît en 1re personne


## Attaque dans la direction choisie (aim_dir).
func try_attack() -> bool:
	if combatant.dead or is_dodging:
		return false
	_assist_yaw = _find_assist_yaw()
	return combatant.request_attack(aim_dir)


func _find_assist_yaw() -> float:
	if rig.first_person:
		return NAN
	var best := NAN
	var best_angle := deg_to_rad(GameConfig.AIM_ASSIST_ANGLE_DEG)
	var cam_forward := Vector3(-sin(rig.yaw), 0.0, -cos(rig.yaw))
	for node in get_tree().get_nodes_in_group(&"combatants"):
		var c := node as Combatant
		if c == null or c.team == combatant.team or c.dead or c.body == null:
			continue
		var to := c.body.global_position - global_position
		to.y = 0.0
		if to.length() > GameConfig.AIM_ASSIST_RANGE or to.length() < 0.01:
			continue
		var angle := cam_forward.angle_to(to)
		if angle < best_angle:
			best_angle = angle
			best = atan2(-to.x, -to.z)
	return best


func _update_aim(delta: float) -> void:
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	aim_accum += look * GameConfig.STICK_AIM_GAIN * delta
	aim_accum *= exp(-GameConfig.AIM_DECAY * delta)
	if aim_accum.length() > GameConfig.AIM_THRESHOLD:
		if absf(aim_accum.x) > absf(aim_accum.y):
			aim_dir = Combatant.Dir.RIGHT if aim_accum.x > 0.0 else Combatant.Dir.LEFT
		else:
			aim_dir = Combatant.Dir.DOWN if aim_accum.y > 0.0 else Combatant.Dir.UP


func _move_factor() -> float:
	match combatant.state:
		Combatant.State.STAGGER:
			return 0.2
		Combatant.State.WINDUP, Combatant.State.STRIKE, Combatant.State.RECOVERY:
			return GameConfig.ATTACK_MOVE_FACTOR
	if combatant.guard_held:
		return GameConfig.GUARD_MOVE_FACTOR
	return 1.0


func _physics_process(delta: float) -> void:
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_update_aim(delta)

	# Garde / feinte (clic droit)
	var alive := not combatant.dead
	if alive and Input.is_action_just_pressed(&"guard") and combatant.state == Combatant.State.WINDUP:
		combatant.request_feint()
	combatant.set_guard(alive and Input.is_action_pressed(&"guard"), aim_dir)
	combatant.invulnerable = invulnerable
	if not combatant.is_attacking():
		_assist_yaw = NAN

	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back") if alive else Vector2.ZERO
	var wish := Basis(Vector3.UP, rig.yaw) * Vector3(input.x, 0.0, input.y)
	var on_floor := is_on_floor()

	_coyote = GameConfig.COYOTE_TIME if on_floor else _coyote - delta
	_jump_buffer = GameConfig.JUMP_BUFFER if Input.is_action_just_pressed(&"jump") else _jump_buffer - delta

	if not on_floor:
		velocity.y -= GameConfig.GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if alive and Input.is_action_just_pressed(&"dodge") and _can_dodge(on_floor):
		_start_dodge(wish)

	if is_dodging:
		_update_dodge(delta)
	else:
		var factor := _move_factor()
		var speed := GameConfig.WALK_SPEED
		if Input.is_action_pressed(&"sprint") and factor >= 1.0:
			speed = GameConfig.RUN_SPEED
		var target := wish * speed * factor
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var rate := GameConfig.ACCELERATION if target.length() > 0.01 else GameConfig.DECELERATION
		if not on_floor:
			rate *= GameConfig.AIR_CONTROL
		horizontal = horizontal.move_toward(target, rate * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		if alive and _jump_buffer > 0.0 and _coyote > 0.0 and combatant.state != Combatant.State.STAGGER:
			velocity.y = GameConfig.JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0

	move_and_slide()
	_update_facing(wish, delta)


func _update_facing(wish: Vector3, delta: float) -> void:
	var in_combat := combatant.state in [Combatant.State.WINDUP, Combatant.State.STRIKE, Combatant.State.RECOVERY] or combatant.guard_held
	if rig.first_person:
		facing_yaw = rig.yaw
	elif is_dodging or combatant.state == Combatant.State.STAGGER:
		pass   # orientation figée
	elif in_combat:
		var target_yaw := rig.yaw if is_nan(_assist_yaw) else _assist_yaw
		facing_yaw = lerp_angle(facing_yaw, target_yaw, 1.0 - exp(-GameConfig.COMBAT_TURN_SPEED * delta))
	elif wish.length() > 0.1:
		var target_yaw := atan2(-wish.x, -wish.z)
		facing_yaw = lerp_angle(facing_yaw, target_yaw, 1.0 - exp(-GameConfig.TURN_SPEED * delta))
	rotation.y = facing_yaw


func _can_dodge(on_floor: bool) -> bool:
	if is_dodging or _dodge_cooldown > 0.0 or not on_floor or combatant.exhausted:
		return false
	return combatant.state == Combatant.State.IDLE or combatant.state == Combatant.State.RECOVERY


func _start_dodge(wish: Vector3) -> void:
	combatant.cancel_recovery()
	combatant.spend_stamina(GameConfig.DODGE_STAMINA)
	is_dodging = true
	_dodge_elapsed = 0.0
	if wish.length() > 0.1:
		_dodge_dir = wish.normalized()
	else:
		_dodge_dir = -facing_vector()   # sans direction : pas en arrière


func _update_dodge(delta: float) -> void:
	_dodge_elapsed += delta
	var t := clampf(_dodge_elapsed / GameConfig.DODGE_DURATION, 0.0, 1.0)
	var speed := GameConfig.DODGE_SPEED * lerpf(1.15, 0.45, t)
	velocity.x = _dodge_dir.x * speed
	velocity.z = _dodge_dir.z * speed
	invulnerable = _dodge_elapsed >= GameConfig.DODGE_IFRAME_START and _dodge_elapsed <= GameConfig.DODGE_IFRAME_END
	# Animation simple : le corps s'incline dans le sens du pas puis se redresse
	var right := Vector3(cos(facing_yaw), 0.0, -sin(facing_yaw))
	_body_pivot.rotation.z = -_dodge_dir.dot(right) * GameConfig.DODGE_LEAN * sin(t * PI)
	if t >= 1.0:
		is_dodging = false
		invulnerable = false
		_dodge_cooldown = GameConfig.DODGE_COOLDOWN
		_body_pivot.rotation.z = 0.0
