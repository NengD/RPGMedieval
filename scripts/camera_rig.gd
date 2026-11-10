class_name CameraRig
extends Node3D
## Caméra du héros : 3e personne (bras à ressort qui ne traverse pas les murs)
## ou 1re personne. V bascule de l'une à l'autre avec une transition douce.

var target: Node3D
var yaw := 0.0
var pitch := -0.15
var first_person := false
## 0 = vue 1re personne, 1 = vue 3e personne (pendant la transition : entre les deux)
var blend := 1.0
var camera: Camera3D
var _shake := 0.0
var _shake_time := 0.0

var _pivot: Node3D
var _arm: SpringArm3D
var _follow_pos := Vector3.ZERO
## Décalage latéral voulu en visée (m, négatif = gauche) ; NAN = comportement normal (TPS_AIM_SHOULDER_FACTOR).
var aim_side := NAN
var _shoulder := 0.0
var _shoulder_goal := 0.0


func _ready() -> void:
	top_level = true
	_pivot = Node3D.new()
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.collision_mask = GameConfig.LAYER_WORLD
	_arm.margin = GameConfig.CAMERA_WALL_MARGIN
	var s := SphereShape3D.new()
	s.radius = 0.25
	_arm.shape = s
	_pivot.add_child(_arm)
	camera = Camera3D.new()
	camera.near = 0.05
	_arm.add_child(camera)
	camera.current = true
	add_to_group(&"camera_rig")
	snap_to_target()


func snap_to_target() -> void:
	_follow_pos = target.global_position
	global_position = _follow_pos


## 0..1 : le héros est-il en train de viser ?
func _aim() -> float:
	return smoothstep(0.0, 1.0, (target as Player).aim_blend) if target is Player else 0.0


func _sens() -> float:
	return lerpf(1.0, GameConfig.AIM_SENSITIVITY_FACTOR, _aim())


func toggle_view() -> void:
	first_person = not first_person


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = event.screen_relative
		yaw -= rel.x * GameConfig.MOUSE_SENSITIVITY * _sens()
		var dy := rel.y * GameConfig.MOUSE_SENSITIVITY * _sens()
		pitch += dy if GameConfig.INVERT_Y else -dy


## Décalage d'épaule : réduit s'il y a un mur à côté du héros (la caméra ne doit jamais finir dans un mur).
func _physics_process(_delta: float) -> void:
	var eye := target.global_position + Vector3(0.0, GameConfig.EYE_HEIGHT, 0.0)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var side_goal := GameConfig.TPS_SHOULDER * lerpf(1.0, GameConfig.TPS_AIM_SHOULDER_FACTOR, _aim())   # en visée, la caméra se recentre derrière le héros
	if not is_nan(aim_side):
		side_goal = lerpf(GameConfig.TPS_SHOULDER, aim_side, _aim())   # ou passe du côté de l'arme
	var sgn := -1.0 if side_goal < 0.0 else 1.0
	var want := absf(side_goal)
	var query := PhysicsRayQueryParameters3D.create(eye, eye + right * sgn * (want + GameConfig.CAMERA_WALL_MARGIN + 0.1), GameConfig.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		want = maxf(0.0, eye.distance_to(hit.position) - GameConfig.CAMERA_WALL_MARGIN - 0.1)
	_shoulder_goal = sgn * want


## Ajoute du tremblement (0..~1,5). Il s'éteint tout seul ; seul le décalage de la caméra bouge (la visée n'est pas touchée).
func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.6)


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - GameConfig.SHAKE_DECAY * delta * _shake - 0.15 * delta)
	_shake_time += delta * 60.0
	if camera != null:
		var off := Vector2(sin(_shake_time * 1.7), cos(_shake_time * 2.3)) * _shake * GameConfig.SHAKE_MAX_OFFSET if _shake > 0.001 else Vector2.ZERO
		camera.h_offset = off.x   # décalage du cadre seulement : la position réelle de la caméra (bras de ressort, murs) n'est pas touchée
		camera.v_offset = off.y
	# Stick droit (avec courbe pour viser finement près du centre)
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	look *= look.length()
	yaw -= look.x * GameConfig.STICK_SENSITIVITY * _sens() * delta
	var dy := look.y * GameConfig.STICK_SENSITIVITY * _sens() * delta
	pitch += dy if GameConfig.INVERT_Y else -dy
	yaw = wrapf(yaw, -PI, PI)

	if first_person:
		pitch = clampf(pitch, -deg_to_rad(GameConfig.FPS_PITCH_LIMIT_DEG), deg_to_rad(GameConfig.FPS_PITCH_LIMIT_DEG))
	else:
		pitch = clampf(pitch, deg_to_rad(GameConfig.TPS_PITCH_MIN_DEG), deg_to_rad(GameConfig.TPS_PITCH_MAX_DEG))

	blend = move_toward(blend, 0.0 if first_person else 1.0, delta / GameConfig.CAMERA_SWITCH_TIME)
	var k := smoothstep(0.0, 1.0, blend)

	# Suivi lissé (indépendant du nombre d'images par seconde)
	if first_person and blend < 0.05:
		_follow_pos = target.global_position
	else:
		_follow_pos = _follow_pos.lerp(target.global_position, 1.0 - exp(-GameConfig.CAMERA_FOLLOW_RATE * delta))
	global_position = _follow_pos
	rotation.y = yaw
	_shoulder = lerpf(_shoulder, _shoulder_goal * k, 1.0 - exp(-14.0 * delta))
	_pivot.position = Vector3(_shoulder, GameConfig.EYE_HEIGHT + (GameConfig.AIM_CAMERA_RAISE * _aim() if not is_nan(aim_side) else 0.0), 0.0)
	_pivot.rotation.x = pitch
	var aim := _aim()
	_arm.spring_length = lerpf(GameConfig.TPS_DISTANCE, GameConfig.TPS_AIM_DISTANCE, aim) * k
	var zoom := 1.0
	if target is Player:
		zoom = lerpf(1.0, (target as Player).aim_fov_factor(), aim)
	camera.fov = lerpf(GameConfig.FOV_FPS, GameConfig.FOV_TPS, k) * zoom
