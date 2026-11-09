class_name WeaponVisual
extends Node3D
## Épée simple (formes de base) animée par code selon l'état du Combatant.
## Les vraies animations arrivent à l'étape 5. Repère : -Z = devant, +X = droite, origine = pieds.

var combatant: Combatant

var _displayed := Transform3D.IDENTITY
var _from := Transform3D.IDENTITY


static func _pose(pos: Vector3, euler_deg: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z))), pos)


static func rest_pose() -> Transform3D:
	return _pose(Vector3(0.42, 1.0, -0.35), Vector3(-35, 0, -8))


static func windup_pose(dir: int) -> Transform3D:
	match dir:
		Combatant.Dir.UP: return _pose(Vector3(0.30, 1.95, 0.05), Vector3(40, 0, -5))
		Combatant.Dir.RIGHT: return _pose(Vector3(0.65, 1.30, -0.10), Vector3(-90, -75, 0))
		Combatant.Dir.DOWN: return _pose(Vector3(0.30, 1.15, 0.40), Vector3(-90, 8, 0))
	return _pose(Vector3(-0.45, 1.30, -0.10), Vector3(-90, 75, 0))


static func strike_pose(dir: int) -> Transform3D:
	match dir:
		Combatant.Dir.UP: return _pose(Vector3(0.15, 1.05, -0.95), Vector3(-105, 0, 0))
		Combatant.Dir.RIGHT: return _pose(Vector3(-0.25, 1.30, -0.55), Vector3(-90, 75, 0))
		Combatant.Dir.DOWN: return _pose(Vector3(0.15, 1.15, -0.75), Vector3(-90, 0, 0))
	return _pose(Vector3(0.55, 1.30, -0.55), Vector3(-90, -75, 0))


static func guard_pose(dir: int) -> Transform3D:
	match dir:
		Combatant.Dir.UP: return _pose(Vector3(-0.35, 1.85, -0.50), Vector3(0, 0, -90))
		Combatant.Dir.RIGHT: return _pose(Vector3(0.55, 0.90, -0.50), Vector3(0, 0, 0))
		Combatant.Dir.DOWN: return _pose(Vector3(-0.35, 0.60, -0.50), Vector3(0, 0, -90))
	return _pose(Vector3(-0.55, 0.90, -0.50), Vector3(0, 0, 0))


static func stagger_pose() -> Transform3D:
	return _pose(Vector3(0.45, 0.75, 0.0), Vector3(20, 0, -25))


func _ready() -> void:
	set_weapon_model(null)
	_displayed = rest_pose()
	transform = _displayed
	if combatant:
		bind(combatant)


var _model: Node3D


## Affiche le modèle de l'arme (null = épée longue d'origine). Agrandi un peu pour rester lisible à l'écran.
func set_weapon_model(data: WeaponData) -> void:
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	var scene: PackedScene = data.model if data != null and data.model != null else load("res://assets/weapons/arme_epee_longue.glb")
	_model = scene.instantiate() as Node3D
	_model.scale = Vector3.ONE * GameConfig.FIRST_PERSON_WEAPON_SCALE
	add_child(_model)


func bind(c: Combatant) -> void:
	combatant = c
	c.attack_started.connect(func(_d: int): _from = _displayed)


func _add_part(size: Vector3, pos: Vector3, color: Color, metallic: float, roughness: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	add_child(mi)


func _process(delta: float) -> void:
	if combatant == null:
		return
	var c := combatant
	var t := clampf(c.state_time / maxf(c.state_duration, 0.001), 0.0, 1.0)
	match c.state:
		Combatant.State.WINDUP:
			_displayed = _from.interpolate_with(windup_pose(c.attack_dir), ease(t, 0.35))
		Combatant.State.STRIKE:
			_displayed = windup_pose(c.attack_dir).interpolate_with(strike_pose(c.attack_dir), ease(t, 2.0))
		Combatant.State.RECOVERY:
			_displayed = strike_pose(c.attack_dir).interpolate_with(rest_pose(), ease(t, 0.5))
		Combatant.State.STAGGER:
			_displayed = _displayed.interpolate_with(stagger_pose(), 1.0 - exp(-14.0 * delta))
		_:
			var target := guard_pose(c.guard_dir) if c.is_guarding() else rest_pose()
			_displayed = _displayed.interpolate_with(target, 1.0 - exp(-22.0 * delta))
	transform = _displayed
