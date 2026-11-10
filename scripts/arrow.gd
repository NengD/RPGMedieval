class_name Arrow
extends Node3D
## Flèche ou carreau : vraie trajectoire (gravité), détection par rayon entre deux images
## (pas de traversée de mur), reste planté dans ce qu'il touche.

static var _stuck: Array = []

var velocity := Vector3.ZERO
var gravity := GameConfig.ARROW_GRAVITY
var damage := 10.0
var team := 0
var attacker: Combatant
var flying := true
var age := 0.0
var is_bolt := false
var _hits_combatants := true


static func spawn(parent: Node, pos: Vector3, vel: Vector3, grav: float, dmg: float, shooter: Combatant, bolt := false) -> Arrow:
	var a := Arrow.new()
	a.velocity = vel
	a.gravity = grav
	a.damage = dmg
	a.attacker = shooter
	a.team = shooter.team if shooter else 0
	a.is_bolt = bolt
	parent.add_child(a)
	a.global_position = pos
	a._orient()
	return a


static func clear_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(&"arrows"):
		node.queue_free()
	_stuck.clear()


func _ready() -> void:
	add_to_group(&"arrows")
	# La pointe est à l'origine ; la hampe part vers l'arrière (+Z). Vol vers -Z.
	var ammo := Registry.get_data(&"munition.carreau" if is_bolt else &"munition.fleche") as AmmoData
	if ammo != null and ammo.model != null:
		add_child(ammo.model.instantiate())
		return
	var length := 0.42 if is_bolt else 0.7
	_add_box(Vector3(0.025, 0.025, length) if is_bolt else Vector3(0.018, 0.018, length), Vector3(0, 0, length * 0.5), Color(0.55, 0.38, 0.2))
	_add_box(Vector3(0.06, 0.06, 0.12), Vector3(0, 0, 0.0), Color(0.7, 0.72, 0.78))


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	add_child(mi)


func _orient() -> void:
	if velocity.length() < 0.01:
		return
	var up := Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(velocity.normalized(), up), global_position)


## Dans combien de secondes passera-t-elle à moins de `radius` de `point` ? (-1 si jamais)
func time_to_reach(point: Vector3, radius: float) -> float:
	var g := Vector3(0.0, -gravity, 0.0)
	var t := 0.0
	while t < 1.5:
		t += 0.03
		var p := global_position + velocity * t + g * (0.5 * t * t)
		if p.distance_to(point) < radius:
			return t
		if p.y < 0.0:
			break
	return -1.0


func _physics_process(delta: float) -> void:
	if not flying:
		return
	age += delta
	var from := global_position
	var to := from + velocity * delta + Vector3(0.0, -gravity, 0.0) * (0.5 * delta * delta)
	velocity.y -= gravity * delta
	var mask := GameConfig.LAYER_WORLD
	if _hits_combatants:
		mask |= GameConfig.LAYER_ENEMY if team == 0 else GameConfig.LAYER_PLAYER
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_on_hit(hit)
	else:
		global_position = to
		_orient()
	if age > GameConfig.ARROW_LIFETIME or global_position.y < -10.0:
		queue_free()


func _on_hit(hit: Dictionary) -> void:
	var collider := hit.collider as Node3D
	var pos: Vector3 = hit.position
	var dir := velocity.normalized()
	global_position = pos
	var c = collider.get_meta(&"combatant") if collider.has_meta(&"combatant") else null
	if c is Combatant and _hits_combatants and c.team != team and not c.dead:
		var head := pos.y - collider.global_position.y > GameConfig.HEAD_HEIGHT
		var dmg := damage * (GameConfig.HEADSHOT_MULTIPLIER if head else 1.0)
		var result: int = c.receive_projectile(attacker, dmg, dir, head)
		if attacker:
			attacker.projectile_result.emit(result, c, dmg, head)
		if result == Combatant.Result.BLOCKED or result == Combatant.Result.PARRIED or result == Combatant.Result.DODGED:
			# Arrêtée par la garde : la flèche rebondit et tombe
			_hits_combatants = false
			velocity = -dir * 2.5 + Vector3.UP * 1.5
			return
		_stick(pos + dir * 0.12, collider)
	elif collider.has_method(&"on_arrow_hit"):
		collider.on_arrow_hit(self, pos)
		_stick(pos + dir * 0.12, collider)
	else:
		_stick(pos + dir * 0.12, null)


func _stick(pos: Vector3, parent: Node3D) -> void:
	flying = false
	Fx.sound("fleche_plantee", pos)
	Fx.burst(get_tree().current_scene, "eclats", pos, -velocity.normalized())
	global_position = pos
	if parent:
		reparent(parent, true)
	_stuck.append(self)
	while _stuck.size() > GameConfig.MAX_STUCK_ARROWS:
		var old = _stuck.pop_front()
		if is_instance_valid(old):
			old.queue_free()
