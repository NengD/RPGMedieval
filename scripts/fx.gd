class_name Fx
extends RefCounted
## Sensations de jeu : arrêt sur image, tremblement de caméra, étincelles / éclats / poussière, ralenti, sons d'impact.
## Tous les réglages sont dans game_config.gd (section « Sensations de jeu ») et dans le menu d'options (F8).

static var shake_enabled := true
static var hit_stop_enabled := true
static var _hit_stop_gen := 0


static func sfx() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Sfx")


static func sound(sound_name: String, pos: Variant = null, db := 0.0) -> void:
	var s := sfx()
	if s != null:
		s.play(sound_name, pos, db)


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://reglages.cfg") == OK:
		shake_enabled = bool(cfg.get_value("sensations", "tremblement", true))
		hit_stop_enabled = bool(cfg.get_value("sensations", "arret_sur_image", true))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://reglages.cfg")
	cfg.set_value("sensations", "tremblement", shake_enabled)
	cfg.set_value("sensations", "arret_sur_image", hit_stop_enabled)
	cfg.save("user://reglages.cfg")


## Arrêt sur image très court (le temps réel continue, pas le jeu).
static func hit_stop(duration: float) -> void:
	if not hit_stop_enabled or duration <= 0.0 or Engine.time_scale < 0.9:
		return
	_scale_for(duration, GameConfig.HIT_STOP_SCALE)


## Ralenti bref (parade parfaite).
static func slow_motion(duration: float, scale: float) -> void:
	if not hit_stop_enabled:
		return
	_scale_for(duration, scale)


static func _scale_for(duration: float, scale: float) -> void:
	if DisplayServer.get_name() == "headless":
		return   # les tests automatiques ne doivent pas être ralentis
	var tree := Engine.get_main_loop() as SceneTree
	_hit_stop_gen += 1
	var gen := _hit_stop_gen
	Engine.time_scale = scale
	tree.create_timer(duration, true, false, true).timeout.connect(func():
		if gen == _hit_stop_gen:
			Engine.time_scale = 1.0)


## Tremblement de la caméra du joueur.
static func shake(amount: float) -> void:
	if not shake_enabled:
		return
	for node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(&"camera_rig"):
		node.add_shake(amount * GameConfig.SHAKE_STRENGTH)


# ---------------------------------------------------------------- particules
## Petite rafale de particules à `pos` : kind = "etincelles" | "eclats" | "poussiere".
static func burst(parent: Node, kind: String, pos: Vector3, direction := Vector3.UP) -> void:
	if not GameConfig.PARTICLES_ENABLED or parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.local_coords = false
	var mesh := SphereMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match kind:
		"etincelles":
			p.amount = 14
			p.lifetime = 0.35
			p.initial_velocity_min = 2.5
			p.initial_velocity_max = 5.5
			p.spread = 65.0
			p.gravity = Vector3(0, -9, 0)
			mesh.radius = 0.012
			mesh.height = 0.024
			mat.albedo_color = Color(1.0, 0.8, 0.35)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.65, 0.2)
			mat.emission_energy_multiplier = 3.0
		"eclats":
			p.amount = 9
			p.lifetime = 0.5
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.5
			p.spread = 70.0
			p.gravity = Vector3(0, -8, 0)
			mesh.radius = 0.02
			mesh.height = 0.04
			mat.albedo_color = Color(0.55, 0.38, 0.2)
		_:
			p.amount = 10
			p.lifetime = 0.8
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 1.2
			p.spread = 80.0
			p.gravity = Vector3(0, 0.3, 0)
			mesh.radius = 0.09
			mesh.height = 0.18
			mat.albedo_color = Color(0.62, 0.57, 0.5, 0.35)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	p.direction = direction
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.5).timeout.connect(func(): if is_instance_valid(p): p.queue_free())


# ---------------------------------------------------------------- impacts de combat
static func _surface_of(victim: Combatant) -> String:
	var prot: Dictionary = victim.protection
	var cut := float(prot.get(DamageType.Type.TRANCHANT, 0.0))
	if cut >= 0.6:
		return "acier"
	if cut >= 0.3:
		return "mailles"
	return "chair"


## Appelé par Combatant à chaque coup reçu (côté victime).
static func on_hit_resolved(result: int, _dir: int, _amount: float, attacker: Combatant, victim: Combatant) -> void:
	if victim.body == null or not is_instance_valid(victim.body) or not victim.body.is_inside_tree():
		return
	var pos := victim.body.global_position + Vector3(0, 1.2, 0)
	var involves_player := victim.team == 0 or (attacker != null and attacker.team == 0)
	var parent: Node = victim.body.get_parent()
	match result:
		Combatant.Result.BLOCKED:
			sound("parade", pos)
			burst(parent, "etincelles", pos + Vector3(0, 0.1, 0))
			if involves_player:
				hit_stop(GameConfig.HIT_STOP_BLOCK)
				shake(0.5)
		Combatant.Result.PARRIED:
			sound("parade_parfaite", pos)
			burst(parent, "etincelles", pos)
			if involves_player:
				slow_motion(GameConfig.SLOWMO_PERFECT_PARRY_TIME, GameConfig.SLOWMO_PERFECT_PARRY_SCALE)
				shake(0.9)
		Combatant.Result.GUARD_BROKEN:
			sound("parade", pos, 3.0)
			sound("cri", pos, -4.0)
			burst(parent, "etincelles", pos)
			if involves_player:
				hit_stop(GameConfig.HIT_STOP_HIT * 1.4)
				shake(1.2)
		Combatant.Result.HIT:
			var surface := _surface_of(victim)
			sound(surface, pos)
			if surface == "acier":
				burst(parent, "etincelles", pos)
			if victim.team == 0 or randf() < 0.5:
				sound("cri", pos, -6.0)
			if involves_player:
				hit_stop(GameConfig.HIT_STOP_HIT)
				shake(0.8 if victim.team == 0 else 0.6)
