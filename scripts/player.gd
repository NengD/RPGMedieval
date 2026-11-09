class_name Player
extends CharacterBody3D
## Héros (capsule) : déplacement, pas de côté, combat à l'épée, à l'arc et à l'arbalète.

enum Weapon { SWORD, BOW, CROSSBOW }

signal weapon_changed(kind: int)
signal notice(text: String)

var spawn_yaw := 0.0
var rig: CameraRig
var combatant: Combatant
var weapon: WeaponVisual
var model: HeroModel
var ranged_visual: RangedVisual
var facing_yaw := 0.0
var invulnerable := false
var is_dodging := false
## Pour les tests automatiques : accepte les événements souris même sans capture (la vraie souris n'est alors pas utilisée).
var accept_input_without_capture := false

var weapon_kind: int = Weapon.SWORD
var drawing := false              # arc : corde en cours de tension
var bow_tension := 0.0            # 0..1
var crossbow_reload := 0.0        # secondes avant que l'arbalète soit rechargée (0 = prête)
var is_aiming := false            # clic droit maintenu avec arc / arbalète
var aim_blend := 0.0              # 0..1 : avancement de la visée (zoom, caméra rapprochée)
var aim_distance := -1.0          # distance au point visé (m), -1 si rien

var _body_pivot: Node3D
var _ranged_pivot: Node3D
var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_elapsed := 0.0
var _dodge_cooldown := 0.0
var _dodge_dir := Vector3.ZERO
var _assist_yaw := NAN
var _release_cooldown := 0.0


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

	# Personnage animé (la capsule reste invisible : elle ne sert plus que de collision)
	_body_pivot.visible = false
	model = HeroModel.new()
	add_child(model)

	# Combat
	combatant = Combatant.new()
	combatant.body = self
	combatant.team = 0
	combatant.radius = GameConfig.PLAYER_RADIUS
	add_child(combatant)
	add_to_group(&"saveable")
	weapon = WeaponVisual.new()
	add_child(weapon)
	weapon.bind(combatant)
	model.bind(combatant)
	combatant.damaged.connect(func(_a: float, _by: Combatant): model.flash())
	_ranged_pivot = Node3D.new()
	_ranged_pivot.position = Vector3(0, 1.4, 0)   # à hauteur d'épaule : l'arme suit l'inclinaison de la visée
	add_child(_ranged_pivot)
	ranged_visual = RangedVisual.new()
	_ranged_pivot.add_child(ranged_visual)
	for wid in [&"arme.epee_longue", &"arme.arc_long", &"arme.arbalete"]:
		var wd := Registry.get_data(wid) as WeaponData
		if wd != null:
			combatant.equipment.equip_weapon(wd)
	combatant.equipment.changed.connect(_refresh_weapon_visuals)
	_refresh_weapon_visuals()

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
	drawing = false
	bow_tension = 0.0
	crossbow_reload = 0.0
	aim_blend = 0.0
	is_aiming = false
	model.reset()
	_body_pivot.rotation = Vector3.ZERO
	combatant.reset()
	rig.snap_to_target()


# ---------------------------------------------------------------- entrées

func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or accept_input_without_capture
	if event.is_action_pressed(&"toggle_view"):
		toggle_view()
	elif event.is_action_pressed(&"weapon_next"):
		cycle_weapon(1)
	elif event.is_action_pressed(&"weapon_prev"):
		cycle_weapon(-1)
	elif event.is_action_pressed(&"attack") and captured:
		primary_action()


func _process(_delta: float) -> void:
	# 3e personne : le chevalier animé ; 1re personne : on ne voit que l'arme (poses par code)
	var third_person := rig.blend > 0.25
	model.visible = third_person
	model.show_sword(weapon_kind == Weapon.SWORD)
	weapon.visible = weapon_kind == Weapon.SWORD and not third_person
	model.show_bow(third_person and weapon_kind == Weapon.BOW)
	model.show_crossbow(third_person and weapon_kind == Weapon.CROSSBOW, crossbow_reload <= 0.0)
	ranged_visual.visible = not (third_person and weapon_kind != Weapon.SWORD)   # en 3e personne l'arc est celui du chevalier
	model.drive(_delta, velocity, global_basis, is_on_floor(), is_dodging, _dodge_dir, weapon_kind, bow_tension, drawing, is_aiming)
	_ranged_pivot.rotation.x = rig.pitch
	ranged_visual.refresh(weapon_kind, bow_tension if drawing else 0.0, drawing, crossbow_reload, rig.first_person)


## Action principale (clic gauche) selon l'arme.
func primary_action() -> bool:
	match weapon_kind:
		Weapon.SWORD:
			return try_attack()
		Weapon.BOW:
			return start_draw()
		Weapon.CROSSBOW:
			return fire_crossbow()
	return false


# ---------------------------------------------------------------- armes

func cycle_weapon(step: int) -> bool:
	return switch_weapon(posmod(weapon_kind + step, 3))


func switch_weapon(kind: int) -> bool:
	if kind == weapon_kind or combatant.dead or is_dodging or combatant.state != Combatant.State.IDLE:
		return false
	cancel_draw()
	weapon_kind = kind
	weapon_changed.emit(kind)
	return true


# --- Épée

## Attaque à l'épée : chaque clic enchaîne le coup suivant du combo.
func try_attack() -> bool:
	if combatant.dead or is_dodging:
		return false
	_assist_yaw = _find_assist_yaw()
	return combatant.request_attack()


# --- Arc

func start_draw() -> bool:
	if combatant.dead or is_dodging or drawing or combatant.exhausted or combatant.state != Combatant.State.IDLE:
		return false
	if _release_cooldown > 0.0:
		return false
	drawing = true
	bow_tension = 0.0
	return true


func cancel_draw() -> void:
	drawing = false
	bow_tension = 0.0


## Relâche la corde : tire si assez tendue. Retourne la flèche (ou null).
func release_draw() -> Arrow:
	if not drawing:
		return null
	var t := bow_tension
	cancel_draw()
	if t < GameConfig.BOW_MIN_TENSION:
		notice.emit(&"NOTICE_BOW_LOOSE")
		return null
	return fire_bow(t)


## Tire une flèche avec une tension donnée (0..1).
func fire_bow(tension: float) -> Arrow:
	model.play_bow_release()
	_release_cooldown = GameConfig.BOW_RELEASE_COOLDOWN
	combatant.spend_stamina(GameConfig.BOW_STAMINA_COST * tension)
	var speed := lerpf(GameConfig.BOW_SPEED_MIN, GameConfig.BOW_SPEED_MAX, tension)
	var dmg := lerpf(GameConfig.BOW_DAMAGE_MIN, GameConfig.BOW_DAMAGE_MAX, tension)
	var spread := lerpf(GameConfig.BOW_SPREAD_DEG_MAX, GameConfig.BOW_SPREAD_DEG_MIN, tension)
	return _shoot(speed, GameConfig.ARROW_GRAVITY, dmg, spread, false)


# --- Arbalète

func fire_crossbow() -> bool:
	if combatant.dead or is_dodging or combatant.exhausted or combatant.state != Combatant.State.IDLE:
		return false
	if crossbow_reload > 0.0:
		notice.emit(&"NOTICE_XBOW_RELOAD")
		return false
	combatant.spend_stamina(GameConfig.CROSSBOW_STAMINA_COST)
	_shoot(GameConfig.CROSSBOW_SPEED, GameConfig.CROSSBOW_GRAVITY, GameConfig.CROSSBOW_DAMAGE, GameConfig.CROSSBOW_SPREAD_DEG, true)
	crossbow_reload = GameConfig.CROSSBOW_RELOAD_TIME
	return true


## Direction de visée : du point d'où part le tir vers ce que vise le centre de l'écran.
func _shoot(speed: float, gravity: float, dmg: float, spread_deg: float, bolt: bool) -> Arrow:
	var cam := rig.camera
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + fwd * 150.0, GameConfig.LAYER_WORLD | GameConfig.LAYER_ENEMY)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var aim_point: Vector3 = hit.position if hit else from + fwd * 150.0
	var muzzle := _muzzle_position()
	var dir := (aim_point - muzzle).normalized()
	if aim_point.distance_to(muzzle) < 2.0:
		dir = fwd
	dir = _with_spread(dir, spread_deg * spread_factor())
	return Arrow.spawn(get_parent(), muzzle, dir * speed, gravity, dmg, combatant, bolt)


func spread_factor() -> float:
	return lerpf(GameConfig.HIPFIRE_SPREAD_FACTOR, GameConfig.AIM_SPREAD_FACTOR, aim_blend)


func aim_fov_factor() -> float:
	return GameConfig.AIM_FOV_FACTOR_CROSSBOW if weapon_kind == Weapon.CROSSBOW else GameConfig.AIM_FOV_FACTOR_BOW


## Angle (radians) dont le tir passe sous le point visé à cause de la gravité, à la distance visée.
func impact_drop_angle() -> float:
	if aim_distance <= 0.0 or weapon_kind == Weapon.SWORD:
		return 0.0
	var speed := GameConfig.CROSSBOW_SPEED
	var gravity := GameConfig.CROSSBOW_GRAVITY
	if weapon_kind == Weapon.BOW:
		speed = lerpf(GameConfig.BOW_SPEED_MIN, GameConfig.BOW_SPEED_MAX, bow_tension if drawing else 1.0)
		gravity = GameConfig.ARROW_GRAVITY
	var flight_time := aim_distance / speed
	return atan2(0.5 * gravity * flight_time * flight_time, aim_distance)


func _update_aim_state(delta: float) -> void:
	is_aiming = weapon_kind != Weapon.SWORD and not combatant.dead and not is_dodging and Input.is_action_pressed(&"guard")
	aim_blend = move_toward(aim_blend, 1.0 if is_aiming else 0.0, delta / GameConfig.AIM_BLEND_TIME)
	aim_distance = -1.0
	if weapon_kind != Weapon.SWORD:
		var cam := rig.camera
		var from := cam.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * 150.0, GameConfig.LAYER_WORLD | GameConfig.LAYER_ENEMY)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			aim_distance = _muzzle_position().distance_to(hit.position)


func _muzzle_position() -> Vector3:
	var cam := rig.camera
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	if rig.first_person:
		return cam.global_position + fwd * 0.5 + right * 0.12 - Vector3.UP * 0.1
	var f := facing_vector()
	return global_position + Vector3(0.0, 1.4, 0.0) + f * 0.5


func _with_spread(dir: Vector3, spread_deg: float) -> Vector3:
	var axis := dir.cross(Vector3.UP)
	if axis.length() < 0.01:
		axis = Vector3.RIGHT
	axis = axis.normalized().rotated(dir, randf() * TAU)
	return dir.rotated(axis, deg_to_rad(randf() * spread_deg)).normalized()


func _update_ranged(delta: float) -> void:
	_release_cooldown = maxf(0.0, _release_cooldown - delta)
	crossbow_reload = maxf(0.0, crossbow_reload - delta)
	if not drawing:
		return
	if combatant.dead or combatant.state == Combatant.State.STAGGER or is_dodging or Input.is_action_just_pressed(&"cancel_draw"):
		cancel_draw()   # touché, esquive ou touche X : on relâche sans tirer
		return
	bow_tension = minf(1.0, bow_tension + delta / GameConfig.BOW_DRAW_TIME)
	if bow_tension >= 1.0:
		combatant.spend_stamina(GameConfig.BOW_HOLD_DRAIN * delta)   # tenir la corde fatigue
	if not Input.is_action_pressed(&"attack") or combatant.exhausted:
		release_draw()


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


func _move_factor() -> float:
	match combatant.state:
		Combatant.State.STAGGER:
			return 0.2
		Combatant.State.WINDUP, Combatant.State.STRIKE, Combatant.State.RECOVERY:
			return GameConfig.ATTACK_MOVE_FACTOR
	var factor := 1.0
	if drawing:
		factor = minf(factor, GameConfig.BOW_MOVE_FACTOR)
	if weapon_kind == Weapon.CROSSBOW:
		factor = minf(factor, GameConfig.CROSSBOW_MOVE_FACTOR)
	if is_aiming:
		factor = minf(factor, GameConfig.AIM_MOVE_FACTOR)
	if combatant.guard_held:
		factor = minf(factor, GameConfig.GUARD_MOVE_FACTOR)
	return factor


# ---------------------------------------------------------------- physique

func _physics_process(delta: float) -> void:
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_update_aim_state(delta)
	_update_ranged(delta)

	# Garde (clic droit maintenu, épée seulement)
	var alive := not combatant.dead
	combatant.set_guard(alive and weapon_kind == Weapon.SWORD and Input.is_action_pressed(&"guard"))
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


func _update_facing(_wish: Vector3, delta: float) -> void:
	# Le héros regarde toujours là où regarde la caméra : en reculant il recule, sur les côtés il marche de côté.
	if rig.first_person:
		facing_yaw = rig.yaw
	elif is_dodging or combatant.state == Combatant.State.STAGGER:
		pass   # orientation figée
	else:
		var in_combat := combatant.state in [Combatant.State.WINDUP, Combatant.State.STRIKE, Combatant.State.RECOVERY] 			or combatant.guard_held or weapon_kind != Weapon.SWORD
		var target_yaw := rig.yaw if is_nan(_assist_yaw) else _assist_yaw
		var rate := GameConfig.COMBAT_TURN_SPEED if in_combat else GameConfig.TURN_SPEED
		facing_yaw = lerp_angle(facing_yaw, target_yaw, 1.0 - exp(-rate * delta))
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


# ---------------------------------------------------------------- sauvegarde

var instance_id := ""


func save_id() -> String:
	return instance_id


func capture_state() -> Dictionary:
	return CharacterSave.capture(self, combatant)


func restore_state(d: Dictionary) -> void:
	CharacterSave.restore(self, combatant, d)
	var yaw := rotation.y
	rig.yaw = yaw
	facing_yaw = yaw
	is_dodging = false
	invulnerable = false
	drawing = false
	bow_tension = 0.0
	is_aiming = false
	model.reset()


# ---------------------------------------------------------------- armes tenues

func _refresh_weapon_visuals() -> void:
	var eq := combatant.equipment
	model.apply_weapons(eq)
	weapon.set_weapon_model(eq.get_weapon(&"main_hand"))
	ranged_visual.set_weapons(eq.get_weapon(&"bow"), eq.get_weapon(&"crossbow"))


## Liste des armes de mêlée disponibles (données), triées.
static func melee_weapon_ids() -> Array:
	var ids: Array = []
	for id in Registry.all_ids():
		var w := Registry.get_data(id) as WeaponData
		if w != null and w.kind() == WeaponCategory.Kind.MELEE:
			ids.append(id)
	ids.sort()
	return ids


## Passe à l'arme de mêlée suivante (touche G). Retourne la nouvelle arme (ou null si impossible).
func cycle_melee() -> WeaponData:
	if combatant.dead or combatant.state != Combatant.State.IDLE or is_dodging:
		return null
	var ids := melee_weapon_ids()
	if ids.is_empty():
		return null
	var cur := combatant.equipment.get_weapon(&"main_hand")
	var i := ids.find(cur.id) if cur != null else -1
	var next := Registry.get_data(ids[(i + 1) % ids.size()]) as WeaponData
	combatant.equipment.equip_weapon(next)
	return next


## Équipe / retire l'écu (touche H). Retourne 1 = équipé, 0 = retiré, -1 = impossible (arme à deux mains).
func toggle_shield() -> int:
	var eq := combatant.equipment
	if eq.get_weapon(&"off_hand") != null:
		eq.unequip_weapon(&"off_hand")
		return 0
	var shield := Registry.get_data(&"arme.ecu") as WeaponData
	if shield == null or not eq.equip_weapon(shield):
		return -1
	return 1


## Clé de traduction du nom de l'arme tenue en ce moment.
func current_weapon_name_key() -> StringName:
	var slot := &"main_hand"
	if weapon_kind == Weapon.BOW:
		slot = &"bow"
	elif weapon_kind == Weapon.CROSSBOW:
		slot = &"crossbow"
	var w := combatant.equipment.get_weapon(slot)
	return w.display_name if w != null else StringName(GameConfig.WEAPON_NAMES[weapon_kind])
