extends SceneTree
## Tests automatiques. Lancer :
## godot --headless --path . --fixed-fps 120 -s tests/run_tests.gd

var failures := 0
var main: Node3D
var player: Player


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  ÉCHEC ") + label)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _teleport(pos: Vector3, yaw: float) -> void:
	player.position = pos
	player.velocity = Vector3.ZERO
	player.rig.yaw = yaw
	player.facing_yaw = yaw
	player.rig.snap_to_target()


func _hold(actions: Array) -> void:
	for a in actions:
		Input.action_press(a)


func _release_all() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"dodge", &"sprint"]:
		Input.action_release(a)


func _run() -> void:
	if not InputMap.has_action(&"jump"):
		load("res://scripts/input_setup.gd").register_actions()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	player = main.player
	# L'ennemi est mis de côté pendant les premiers tests (il revient dans la section [Ennemi])
	main.enemy.process_mode = Node.PROCESS_MODE_DISABLED
	main.enemy.position = Vector3(40, 0, 40)
	await _frames(120)

	print("[Sol et gravité]")
	_check(player.is_on_floor(), "le héros est posé au sol")
	_check(absf(player.global_position.y) < 0.05, "hauteur ~ 0 (y=%.3f)" % player.global_position.y)

	print("[Marche et course]")
	var z0 := player.global_position.z
	_hold([&"move_forward"])
	await _frames(120)
	var walk_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check(absf(walk_speed - GameConfig.WALK_SPEED) < 0.3, "vitesse de marche %.2f" % walk_speed)
	_check(player.global_position.z < z0 - 2.0, "il avance vers l'avant")
	_hold([&"sprint"])
	await _frames(60)
	var run_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check(absf(run_speed - GameConfig.RUN_SPEED) < 0.3, "vitesse de course %.2f" % run_speed)
	_release_all()

	print("[Saut]")
	_teleport(Vector3(-10, 0.05, 9), 0.0)
	await _frames(30)
	var max_y := 0.0
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	for i in 120:
		await physics_frame
		max_y = maxf(max_y, player.global_position.y)
	var expected := GameConfig.JUMP_VELOCITY * GameConfig.JUMP_VELOCITY / (2.0 * GameConfig.GRAVITY)
	_check(absf(max_y - expected) < 0.15, "hauteur de saut %.2f m (attendu %.2f)" % [max_y, expected])
	_check(player.is_on_floor(), "il retombe au sol")

	print("[Pas de côté]")
	_teleport(Vector3(-10, 0.05, 9), 0.0)
	await _frames(30)
	_hold([&"move_right"])
	Input.action_press(&"dodge")
	await _frames(3)
	Input.action_release(&"dodge")
	_check(player.is_dodging, "le pas de côté démarre")
	var max_speed := 0.0
	var saw_iframes := false
	for i in 20:
		await physics_frame
		max_speed = maxf(max_speed, Vector2(player.velocity.x, player.velocity.z).length())
		saw_iframes = saw_iframes or player.invulnerable
	_check(max_speed > GameConfig.DODGE_SPEED * 0.8, "vitesse du pas de côté %.2f" % max_speed)
	_check(saw_iframes, "invulnérable pendant le pas de côté")
	_release_all()
	await _frames(int(GameConfig.DODGE_DURATION * 120) + 30)
	_check(not player.is_dodging, "le pas de côté se termine")

	print("[Murs]")
	_teleport(Vector3(0, 0.05, 12), 0.0)
	await _frames(30)
	_hold([&"move_back"])
	await _frames(240)
	_release_all()
	_check(player.global_position.z < GameConfig.ARENA_HALF_SIZE, "le mur arrête le héros (z=%.2f)" % player.global_position.z)

	print("[Caméra et murs]")
	_teleport(Vector3(0, 0.05, -13.5), PI)  # regarde vers le mur nord, caméra derrière = hors de l'arène
	player.rig.pitch = 0.0
	await _frames(60)
	var cam_z := player.rig.camera.global_position.z
	_check(cam_z > -GameConfig.ARENA_HALF_SIZE, "la caméra ne traverse pas le mur (z=%.2f)" % cam_z)
	_teleport(Vector3(0, 0.05, 9), 0.0)

	print("[Vue 1re / 3e personne]")
	await _frames(60)
	var tps_dist := player.rig.camera.global_position.distance_to(player.global_position + Vector3(0, GameConfig.EYE_HEIGHT, 0))
	player.toggle_view()
	await _frames(60)
	var fps_dist := player.rig.camera.global_position.distance_to(player.global_position + Vector3(0, GameConfig.EYE_HEIGHT, 0))
	_check(player.rig.first_person and fps_dist < 0.3, "1re personne : caméra aux yeux (%.2f m)" % fps_dist)
	_check(tps_dist > 2.5, "3e personne : caméra en retrait (%.2f m)" % tps_dist)
	_check(not player._body_pivot.visible, "le corps est caché en 1re personne")
	player.toggle_view()
	await _frames(60)
	_check(player._body_pivot.visible, "le corps est visible en 3e personne")

	print("[Regard à la souris]")
	var can_capture := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not can_capture:
		print("  (ignoré : la souris ne peut pas être capturée en mode headless ; vérifié à la main via tests/shot.gd)")
	for fp in ([true, false] if can_capture else []):
		if player.rig.first_person != fp:
			player.toggle_view()
		await _frames(40)
		var yaw0 := player.rig.yaw
		var pitch0 := player.rig.pitch
		var ev := InputEventMouseMotion.new()
		ev.relative = Vector2(100, -40)
		ev.screen_relative = Vector2(100, -40)
		Input.parse_input_event(ev)
		await _frames(5)
		_check(not is_equal_approx(player.rig.yaw, yaw0) and not is_equal_approx(player.rig.pitch, pitch0), "la souris tourne la caméra (%s)" % ("1re personne" if fp else "3e personne"))
	if player.rig.first_person:
		player.toggle_view()

	print("[Rampe]")
	_teleport(Vector3(9, 0.05, -4), 0.0)
	await _frames(30)
	_hold([&"move_forward"])
	await _frames(360)
	_release_all()
	_check(player.global_position.y > GameConfig.PLATFORM_HEIGHT - 0.2, "il monte sur la plateforme (y=%.2f)" % player.global_position.y)

	print("[Combat contre le mannequin]")
	var dummy: TrainingDummy = main.dummy
	dummy.reset_stats()
	_teleport(main.DUMMY_POS + Vector3(0, 0.05, 2.5), 0.0)
	await _frames(30)
	_check(player.try_attack(), "le héros lance une attaque")
	await _frames(240)
	_check(dummy.total_damage > 0.0, "l'attaque touche le mannequin (%d dégâts)" % int(dummy.total_damage))
	var before := dummy.total_damage
	player.try_attack()
	await _frames(20)
	_check(player.combatant.request_feint(), "feinte pendant l'élan")
	await _frames(240)
	_check(is_equal_approx(dummy.total_damage, before), "une attaque feintée ne touche pas")

	print("[Mannequin agressif]")
	_teleport(main.DUMMY_POS + Vector3(0, 0.05, 2.5), 0.0)
	player.combatant.reset()
	dummy.set_practice(true)
	await _frames(120 * 6)
	_check(player.combatant.health < player.combatant.max_health, "le mannequin agressif blesse un héros qui ne pare pas (vie %.0f)" % player.combatant.health)
	dummy.set_practice(false)

	print("[Ennemi]")
	var enemy: Enemy = main.enemy
	seed(12345)
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	player.combatant.invincible = true   # on observe l'IA sans que le héros meure
	enemy.aggressive = false
	enemy.set_difficulty(1)
	_teleport(Vector3(0, 0.05, 9), 0.0)
	player.combatant.reset()
	enemy.reset_to(Vector3(0, 0, -6))
	var d_start := enemy.global_position.distance_to(player.global_position)
	await _frames(120 * 4)
	var d_now := enemy.global_position.distance_to(player.global_position)
	_check(d_now < d_start - 3.0 and d_now < 4.6, "il s'approche du héros (%.1f m -> %.1f m)" % [d_start, d_now])
	# tourne autour : on cumule l'angle parcouru autour du héros
	var travel := 0.0
	var last_angle := 0.0
	var saw_circle := false
	for i in 120 * 8:
		await physics_frame
		var rel := enemy.global_position - player.global_position
		var ang := atan2(rel.x, rel.z)
		if i > 0:
			travel += absf(angle_difference(last_angle, ang))
		last_angle = ang
		saw_circle = saw_circle or enemy.mode == Enemy.Mode.CIRCLE
	_check(saw_circle and rad_to_deg(travel) > 40.0, "il tourne autour du héros (%.0f° parcourus en 8 s)" % rad_to_deg(travel))

	# attaque dans des directions variées
	enemy.aggressive = true
	enemy.set_difficulty(2)
	enemy.reset_to(Vector3(0, 0, 3))
	var dirs := {}
	var attacks := [0]
	enemy.combatant.attack_started.connect(func(d: int): dirs[d] = true; attacks[0] += 1)
	for i in 120 * 40:
		await physics_frame
		player.combatant.stamina = GameConfig.STAMINA_MAX   # héros inépuisable : il reste dans le combat
		if player.combatant.state == Combatant.State.STAGGER and i % 60 == 0:
			_teleport(Vector3(0, 0.05, 9), 0.0)
	_check(attacks[0] >= 8, "il attaque régulièrement (%d attaques en 40 s)" % attacks[0])
	_check(dirs.size() >= 3, "il varie les directions (%d différentes)" % dirs.size())

	# fatigue : il recule
	enemy.set_difficulty(1)
	enemy.reset_to(Vector3(0, 0, 3))
	_teleport(Vector3(0, 0.05, 5), PI)
	await _frames(30)
	enemy.combatant.stamina = 0.0
	enemy.combatant.exhausted = true
	var d_before := enemy.global_position.distance_to(player.global_position)
	await _frames(120 * 2)
	var d_after := enemy.global_position.distance_to(player.global_position)
	_check(enemy.mode == Enemy.Mode.RETREAT, "épuisé, il passe en mode recul")
	_check(d_after > d_before + 1.5, "il s'éloigne du héros (%.1f m -> %.1f m)" % [d_before, d_after])

	# parades imparfaites : certaines parées, d'autres non
	enemy.aggressive = false
	enemy.combatant.invincible = true
	enemy.reset_to(Vector3(0, 0, 0))
	var results := {}
	enemy.combatant.hit_resolved.connect(func(r: int, _d: int, _a: float, _by: Combatant): results[r] = results.get(r, 0) + 1)
	for n in 16:
		var p := enemy.global_position + Vector3(0.0, 0.05, 2.0)
		_teleport(p, 0.0)
		player.combatant.reset()
		enemy.combatant.stamina = GameConfig.STAMINA_MAX
		enemy.combatant.exhausted = false
		player.aim_dir = n % 4
		await _frames(30)
		player.try_attack()
		await _frames(120 * 2)
	var guarded: int = results.get(Combatant.Result.BLOCKED, 0) + results.get(Combatant.Result.PARRIED, 0) + results.get(Combatant.Result.GUARD_BROKEN, 0)
	var passed: int = results.get(Combatant.Result.HIT, 0)
	_check(guarded >= 2, "il pare une partie des coups (%d parés)" % guarded)
	_check(passed >= 2, "mais pas tous : la parade est imparfaite (%d coups passent)" % passed)

	# difficulté et réinitialisation
	enemy.set_difficulty(0)
	_check(enemy.combatant.max_health == GameConfig.AI_MAX_HEALTH[0] and is_equal_approx(enemy.combatant.speed_scale, GameConfig.AI_SPEED_SCALE[0]), "la difficulté Facile applique ses réglages")
	enemy.set_difficulty(2)
	_check(enemy.combatant.max_health == GameConfig.AI_MAX_HEALTH[2], "la difficulté Difficile applique ses réglages")
	enemy.combatant.invincible = false
	enemy.combatant.take_damage(9999.0)
	_check(enemy.combatant.dead, "l'ennemi peut être vaincu")
	main.reset_combat()
	await _frames(10)
	_check(not enemy.combatant.dead and is_equal_approx(enemy.combatant.health, enemy.combatant.max_health), "R remet l'ennemi à neuf")
	_check(player.combatant.health == player.combatant.max_health, "R remet le héros à neuf")

	print("")
	print("RÉSULTAT : %s (%d échec(s))" % ["SUCCÈS" if failures == 0 else "ÉCHEC", failures])
	quit(1 if failures > 0 else 0)
