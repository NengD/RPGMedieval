class_name Player
extends CharacterBody3D
## Héros (capsule) : marche, course, saut, roulade. Caméra gérée par CameraRig.

var spawn_yaw := 0.0
var rig: CameraRig
var facing_yaw := 0.0
var invulnerable := false
var is_dodging := false

var _body_pivot: Node3D
var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_elapsed := 0.0
var _dodge_cooldown := 0.0
var _dodge_dir := Vector3.ZERO
var _dodge_backward := false


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_view"):
		toggle_view()


func _process(_delta: float) -> void:
	_body_pivot.visible = rig.blend > 0.25   # le corps disparaît en 1re personne


func _physics_process(delta: float) -> void:
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish := Basis(Vector3.UP, rig.yaw) * Vector3(input.x, 0.0, input.y)
	var on_floor := is_on_floor()

	_coyote = GameConfig.COYOTE_TIME if on_floor else _coyote - delta
	_jump_buffer = GameConfig.JUMP_BUFFER if Input.is_action_just_pressed(&"jump") else _jump_buffer - delta

	if not on_floor:
		velocity.y -= GameConfig.GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed(&"dodge") and not is_dodging and _dodge_cooldown <= 0.0 and on_floor:
		_start_dodge(wish)

	if is_dodging:
		_update_dodge(delta)
	else:
		var speed := GameConfig.RUN_SPEED if Input.is_action_pressed(&"sprint") else GameConfig.WALK_SPEED
		var target := wish * speed
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var rate := GameConfig.ACCELERATION if target.length() > 0.01 else GameConfig.DECELERATION
		if not on_floor:
			rate *= GameConfig.AIR_CONTROL
		horizontal = horizontal.move_toward(target, rate * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = GameConfig.JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0

	move_and_slide()
	_update_facing(wish, delta)

	if Input.is_action_just_pressed(&"debug_hit"):
		_debug_hit()


func _update_facing(wish: Vector3, delta: float) -> void:
	if rig.first_person:
		facing_yaw = rig.yaw
	elif is_dodging:
		pass   # orientation fixée au début de la roulade
	elif wish.length() > 0.1:
		var target_yaw := atan2(-wish.x, -wish.z)
		facing_yaw = lerp_angle(facing_yaw, target_yaw, 1.0 - exp(-GameConfig.TURN_SPEED * delta))
	rotation.y = facing_yaw


func _start_dodge(wish: Vector3) -> void:
	is_dodging = true
	_dodge_elapsed = 0.0
	if wish.length() > 0.1:
		_dodge_dir = wish.normalized()
		_dodge_backward = false
		if not rig.first_person:
			facing_yaw = atan2(-_dodge_dir.x, -_dodge_dir.z)
	else:
		_dodge_dir = -facing_vector()   # sans direction : roulade en arrière
		_dodge_backward = true


func _update_dodge(delta: float) -> void:
	_dodge_elapsed += delta
	var t := clampf(_dodge_elapsed / GameConfig.DODGE_DURATION, 0.0, 1.0)
	var speed := GameConfig.DODGE_SPEED * lerpf(1.15, 0.45, t)
	velocity.x = _dodge_dir.x * speed
	velocity.z = _dodge_dir.z * speed
	invulnerable = _dodge_elapsed >= GameConfig.DODGE_IFRAME_START and _dodge_elapsed <= GameConfig.DODGE_IFRAME_END
	# Animation simple : le corps fait un tour sur lui-même, un peu écrasé
	var angle := t * TAU
	_body_pivot.rotation.x = angle if _dodge_backward else -angle
	_body_pivot.scale.y = 0.75
	if t >= 1.0:
		is_dodging = false
		invulnerable = false
		_dodge_cooldown = GameConfig.DODGE_COOLDOWN
		_body_pivot.rotation.x = 0.0
		_body_pivot.scale.y = 1.0


## Coup de test (touche F) : touche le mannequin devant le héros.
func _debug_hit() -> void:
	var from := global_position + Vector3.UP * 1.0
	var dir := facing_vector()
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 3.0, GameConfig.LAYER_ENEMY)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(10.0, dir)
