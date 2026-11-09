class_name TrainingDummy
extends StaticBody3D
## Mannequin d'entraînement. Immobile, il affiche les dégâts reçus.
## En "mode agressif" (touche T) il frappe le héros à intervalles réguliers pour s'entraîner à parer.

var combatant: Combatant
var weapon: WeaponVisual
var target_node: Node3D           # le héros (le mannequin se tourne vers lui)
var practice := false
var total_damage := 0.0
var hit_count := 0

var _pivot: Node3D
var _mat: StandardMaterial3D
var _total_label: Label3D
var _practice_timer := 1.0
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

	combatant = Combatant.new()
	combatant.body = self
	combatant.team = 1
	combatant.radius = GameConfig.DUMMY_RADIUS
	combatant.invincible = true
	combatant.speed_scale = GameConfig.PRACTICE_SPEED_SCALE
	combatant.damage_scale = GameConfig.PRACTICE_DAMAGE_SCALE
	add_child(combatant)
	add_to_group(&"saveable")
	weapon = WeaponVisual.new()
	_pivot.add_child(weapon)
	weapon.bind(combatant)
	combatant.damaged.connect(_on_damaged)
	combatant.hit_resolved.connect(_on_hit_resolved)

	_total_label = _make_label(24, Color(1, 1, 1))
	_total_label.position = Vector3(0, GameConfig.DUMMY_HEIGHT + 0.5, 0)
	add_child(_total_label)
	_refresh_total()


func _physics_process(delta: float) -> void:
	# Le mannequin garde le regard sur le héros, et ne se fatigue jamais.
	if target_node and combatant.state != Combatant.State.STAGGER:
		var to := target_node.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
	combatant.stamina = combatant.stats.get_derived(&"endurance_max")
	combatant.exhausted = false

	if practice and combatant.state == Combatant.State.IDLE:
		_practice_timer -= delta
		if _practice_timer <= 0.0:
			var dir: int = GameConfig.PRACTICE_DIRECTION
			if dir < 0:
				dir = randi() % 4
			combatant.request_attack(dir)
			_practice_timer = GameConfig.PRACTICE_INTERVAL


func _process(_delta: float) -> void:
	# Couleur selon l'état : rouge pendant l'attaque, bleu quand il est déséquilibré
	var c := _BASE_COLOR
	match combatant.state:
		Combatant.State.WINDUP, Combatant.State.STRIKE:
			c = Color(0.9, 0.2, 0.15)
		Combatant.State.STAGGER:
			c = Color(0.35, 0.55, 1.0)
	_mat.albedo_color = _mat.albedo_color.lerp(c, 0.35)


func set_practice(on: bool) -> void:
	practice = on
	_practice_timer = 1.0


## Compatibilité : infliger des dégâts directs (tests).
func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO) -> void:
	combatant.take_damage(amount)


func reset_stats() -> void:
	total_damage = 0.0
	hit_count = 0
	combatant.reset()
	_refresh_total()


func _on_damaged(amount: float, _attacker: Combatant) -> void:
	total_damage += amount
	hit_count += 1
	_refresh_total()
	_spawn_floating_number("-%d" % int(round(amount)), DamageType.color_of(combatant.last_damage_type))
	_mat.albedo_color = Color(1, 1, 1)   # éclair blanc
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation:x", -0.25, 0.05)
	tw.tween_property(_pivot, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_hit_resolved(result: int, _dir: int, _amount: float, _attacker: Combatant) -> void:
	if result == Combatant.Result.DODGED:
		_spawn_floating_number(tr("FLOAT_DODGED"), Color(0.7, 0.7, 0.7))


func _refresh_total() -> void:
	_total_label.text = tr("HUD_DUMMY_TOTAL") % [int(total_damage), hit_count]


func _spawn_floating_number(text: String, color: Color) -> void:
	var label := _make_label(64, color)
	label.text = text
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


# ---------------------------------------------------------------- sauvegarde

var instance_id := ""


func save_id() -> String:
	return instance_id


func capture_state() -> Dictionary:
	return CharacterSave.capture(self, combatant)


func restore_state(d: Dictionary) -> void:
	CharacterSave.restore(self, combatant, d)
