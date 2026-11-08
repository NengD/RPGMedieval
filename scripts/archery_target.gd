class_name ArcheryTarget
extends StaticBody3D
## Cible de tir : disque à 3 zones (10 / 5 / 2 points). Peut glisser latéralement.

signal scored(points: int)

var total := 0
var shots := 0
var move_range := 0.0       # amplitude du va-et-vient (m), 0 = immobile
var move_speed := 1.0

var _origin := Vector3.ZERO
var _lateral := Vector3.RIGHT
var _t := 0.0


func _ready() -> void:
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var r := GameConfig.TARGET_RADIUS
	_disc(r, 0.00, Color(0.95, 0.95, 0.9))
	_disc(GameConfig.TARGET_INNER, 0.01, Color(0.85, 0.15, 0.15))
	_disc(GameConfig.TARGET_BULLSEYE, 0.02, Color(1.0, 0.85, 0.1))
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = 0.14
	var col := CollisionShape3D.new()
	col.shape = shape
	col.rotation.x = PI * 0.5
	add_child(col)


## Place la cible (et son pied) à `pos`, face à `look_at_pos`. À appeler après add_child.
func place(pos: Vector3, look_at_pos: Vector3) -> void:
	look_at_from_position(pos, look_at_pos, Vector3.UP)
	_origin = position
	_lateral = global_transform.basis.x
	var post := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, pos.y, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.28, 0.15)
	bm.material = mat
	post.mesh = bm
	post.position = Vector3(0, -pos.y * 0.5, 0.1)
	add_child(post)


func _disc(radius: float, z: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	cm.material = mat
	mi.mesh = cm
	mi.rotation.x = PI * 0.5
	mi.position.z = z
	add_child(mi)


func _physics_process(delta: float) -> void:
	if move_range > 0.0:
		_t += delta * move_speed
		position = _origin + _lateral * sin(_t) * move_range


## Points marqués selon l'endroit touché (coordonnées du monde).
func score_at(world_pos: Vector3) -> int:
	var local := to_local(world_pos)
	var r := Vector2(local.x, local.y).length()
	if r <= GameConfig.TARGET_BULLSEYE:
		return 10
	if r <= GameConfig.TARGET_INNER:
		return 5
	return 2


func on_arrow_hit(_arrow: Arrow, pos: Vector3) -> void:
	var points := score_at(pos)
	total += points
	shots += 1
	scored.emit(points)
	FloatingText.spawn(self, "+%d" % points, Color(1.0, 0.9, 0.3) if points >= 10 else Color(0.9, 0.9, 0.9), 0.9)
