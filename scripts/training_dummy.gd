class_name TrainingDummy
extends StaticBody3D
## Mannequin d'entraînement immobile : affiche les dégâts reçus.

var total_damage := 0.0
var hit_count := 0

var _pivot: Node3D
var _mat: StandardMaterial3D
var _total_label: Label3D
const _BASE_COLOR := Color(0.85, 0.55, 0.2)


func _ready() -> void:
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CapsuleShape3D.new()
	shape.radius = GameConfig.DUMMY_RADIUS
	shape.height = GameConfig.DUMMY_HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = GameConfig.DUMMY_HEIGHT * 0.5
	add_child(col)

	_pivot = Node3D.new()
	add_child(_pivot)
	var capsule := CapsuleMesh.new()
	capsule.radius = GameConfig.DUMMY_RADIUS
	capsule.height = GameConfig.DUMMY_HEIGHT
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _BASE_COLOR
	capsule.material = _mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.position.y = GameConfig.DUMMY_HEIGHT * 0.5
	_pivot.add_child(mesh)

	_total_label = _make_label(24, Color(1, 1, 1))
	_total_label.position = Vector3(0, GameConfig.DUMMY_HEIGHT + 0.5, 0)
	add_child(_total_label)
	_refresh_total()


func take_damage(amount: float, direction: Vector3 = Vector3.ZERO) -> void:
	total_damage += amount
	hit_count += 1
	_refresh_total()
	_spawn_floating_number(amount)
	# Éclair blanc puis retour à la couleur normale
	_mat.albedo_color = Color(1, 1, 1)
	create_tween().tween_property(_mat, "albedo_color", _BASE_COLOR, 0.25)
	# Petit balancement dans le sens du coup
	var tilt := Vector3(direction.z, 0.0, -direction.x) * 0.3
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation", tilt, 0.05)
	tw.tween_property(_pivot, "rotation", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func reset_stats() -> void:
	total_damage = 0.0
	hit_count = 0
	_refresh_total()


func _refresh_total() -> void:
	_total_label.text = "Dégâts reçus : %d  (%d coups)" % [int(total_damage), hit_count]


func _spawn_floating_number(amount: float) -> void:
	var label := _make_label(64, Color(1.0, 0.85, 0.2))
	label.text = "-%d" % int(amount)
	label.position = Vector3(randf_range(-0.3, 0.3), GameConfig.DUMMY_HEIGHT + 0.1, 0)
	add_child(label)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.0, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)


func _make_label(size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = size
	label.pixel_size = 0.01
	label.outline_size = 12
	label.modulate = color
	return label
