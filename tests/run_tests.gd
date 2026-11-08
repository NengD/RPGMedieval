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
	_check(not player.model.visible, "le corps est caché en 1re personne")
	player.toggle_view()
	await _frames(60)
	_check(player.model.visible, "le corps est visible en 3e personne")

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
	_check(guarded >= 1, "il pare quelques coups (rarement) (%d parés)" % guarded)
	_check(passed >= guarded * 2, "mais la plupart passent : la parade est imparfaite (%d coups passent)" % passed)

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

	print("[IA désactivable]")
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.set_physics_process(true)
	enemy.aggressive = true
	enemy.ai_enabled = false
	enemy.set_difficulty(2)
	_teleport(Vector3(0, 0.05, 2), PI)
	enemy.reset_to(Vector3(0, 0, -1))
	player.combatant.reset()
	await _frames(120 * 4)
	_check(enemy.global_position.distance_to(Vector3(0, 0, -1)) < 0.2, "IA coupée : l'ennemi ne bouge pas (%s)" % enemy.global_position)
	_check(player.combatant.health == player.combatant.max_health and enemy.combatant.state == Combatant.State.IDLE, "IA coupée : il n'attaque pas")
	enemy.ai_enabled = true
	await _frames(120 * 4)
	_check(enemy.global_position.distance_to(Vector3(0, 0, -1)) > 0.5 or enemy.combatant.state != Combatant.State.IDLE, "IA remise : il se remet à bouger")

	print("[Changement d'arme]")
	main.reset_combat()
	player.combatant.invincible = true
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.position = Vector3(40, 0, 40)
	_teleport(Vector3(0, 0.05, 9), 0.0)
	await _frames(30)
	_check(player.weapon_kind == Player.Weapon.SWORD, "on commence à l'épée")
	player.cycle_weapon(1)
	player.cycle_weapon(1)
	_check(player.weapon_kind == Player.Weapon.CROSSBOW, "Tab : épée, arc, arbalète")
	player.cycle_weapon(1)
	_check(player.weapon_kind == Player.Weapon.SWORD, "puis retour à l'épée")
	player.switch_weapon(Player.Weapon.BOW)
	_check(player.weapon_kind == Player.Weapon.BOW, "choix direct de l'arc")

	print("[Arc]")
	var weak := player.fire_bow(0.3)
	var strong := player.fire_bow(1.0)
	_check(strong.velocity.length() > weak.velocity.length() * 1.4 and strong.damage > weak.damage * 2.0, "plus la corde est tendue, plus la flèche est rapide et forte (%.0f -> %.0f m/s, %.0f -> %.0f dégâts)" % [weak.velocity.length(), strong.velocity.length(), weak.damage, strong.damage])
	weak.queue_free()
	strong.queue_free()
	# gravité : horizontale à 30 m/s pendant 0,5 s -> chute ~ 0,5 * g * t²
	var shot := Arrow.spawn(main, Vector3(0, 3.0, 5.0), Vector3(0, 0, -30.0), GameConfig.ARROW_GRAVITY, 10.0, player.combatant)
	await _frames(60)
	var drop := 3.0 - shot.global_position.y
	var expected_drop := 0.5 * GameConfig.ARROW_GRAVITY * 0.25
	_check(absf(drop - expected_drop) < 0.25 and shot.global_position.z < -8.0, "la flèche suit une trajectoire courbe (chute %.2f m, attendu %.2f m)" % [drop, expected_drop])
	shot.queue_free()
	# plantée dans un mur
	var stuck := Arrow.spawn(main, Vector3(10.0, 4.0, 5.0), Vector3(0, 0, -60.0), GameConfig.ARROW_GRAVITY, 10.0, player.combatant)
	await _frames(240)
	_check(is_instance_valid(stuck) and not stuck.flying and absf(stuck.global_position.z + 15.0) < 0.5, "la flèche reste plantée dans le mur (z=%.2f)" % stuck.global_position.z)
	# tir complet sur le mannequin
	dummy.reset_stats()
	_teleport(main.DUMMY_POS + Vector3(-GameConfig.TPS_SHOULDER, 0.05, 9.0), 0.0)   # la caméra est décalée d'épaule : on se place pour que le viseur soit sur le mannequin
	player.rig.pitch = 0.0
	await _frames(40)
	Input.action_press(&"attack")
	player.start_draw()
	await _frames(int(120 * (GameConfig.BOW_DRAW_TIME + 0.2)))
	_check(player.drawing and is_equal_approx(player.bow_tension, 1.0), "en maintenant, la corde se tend jusqu'au maximum")
	Input.action_release(&"attack")
	await _frames(120)
	_check(not player.drawing, "relâcher tire la flèche")
	_check(dummy.total_damage >= GameConfig.BOW_DAMAGE_MAX - 0.5, "la flèche touche le mannequin (%d dégâts)" % int(dummy.total_damage))
	var planted := false
	for child in dummy.get_children():
		planted = planted or child is Arrow
	_check(planted, "la flèche reste plantée dans le mannequin")
	# annuler avec X
	var arrows_before := get_nodes_in_group(&"arrows").size()
	Input.action_press(&"attack")
	player.start_draw()
	await _frames(40)
	Input.action_press(&"cancel_draw")
	await _frames(3)
	Input.action_release(&"cancel_draw")
	Input.action_release(&"attack")
	await _frames(10)
	_check(not player.drawing and get_nodes_in_group(&"arrows").size() == arrows_before, "X : on annule sans tirer")

	print("[Cibles]")
	var target: ArcheryTarget = main.targets[1]
	_check(target.score_at(target.global_position) == 10, "centre = 10 points")
	_check(target.score_at(target.global_position + target.global_transform.basis.x * 0.2) == 5, "anneau = 5 points")
	_check(target.score_at(target.global_position + target.global_transform.basis.x * 0.5) == 2, "bord = 2 points")
	_teleport(Vector3(6.2, 0.05, 0.0), -PI * 0.5)   # regarde vers +X, la cible est à 8 m
	player.rig.pitch = 0.0
	await _frames(40)
	player.fire_bow(1.0)
	await _frames(120)
	_check(target.shots >= 1 and main.target_score >= 2, "un tir sur la cible marque des points (score %d)" % main.target_score)

	print("[Arbalète]")
	player.switch_weapon(Player.Weapon.CROSSBOW)
	_check(player.fire_crossbow(), "l'arbalète tire")
	_check(not player.fire_crossbow() and player.crossbow_reload > GameConfig.CROSSBOW_RELOAD_TIME - 0.2, "elle doit être rechargée avant de tirer à nouveau")
	await _frames(int(120 * (GameConfig.CROSSBOW_RELOAD_TIME + 0.2)))
	_check(player.crossbow_reload == 0.0 and player.fire_crossbow(), "rechargée après %.1f s" % GameConfig.CROSSBOW_RELOAD_TIME)
	_check(GameConfig.CROSSBOW_SPEED > GameConfig.BOW_SPEED_MAX and GameConfig.CROSSBOW_DAMAGE > GameConfig.BOW_DAMAGE_MAX and GameConfig.CROSSBOW_GRAVITY < GameConfig.ARROW_GRAVITY, "plus droite et plus puissante que l'arc")
	player.switch_weapon(Player.Weapon.SWORD)

	print("[Visée]")
	player.switch_weapon(Player.Weapon.BOW)
	_teleport(Vector3(0, 0.05, 9), 0.0)
	player.rig.pitch = 0.0
	await _frames(60)
	var fov_free := player.rig.camera.fov
	var eye := player.global_position + Vector3(0, GameConfig.EYE_HEIGHT, 0)
	var dist_free := player.rig.camera.global_position.distance_to(eye)
	var spread_free := player.spread_factor()
	Input.action_press(&"guard")
	await _frames(90)
	_check(player.is_aiming and is_equal_approx(player.aim_blend, 1.0), "clic droit avec l'arc : on vise")
	_check(player.rig.camera.fov < fov_free * 0.8, "zoom : champ de vision %.0f° -> %.0f°" % [fov_free, player.rig.camera.fov])
	_check(player.rig.camera.global_position.distance_to(eye) < dist_free - 1.0, "la caméra se rapproche du héros (%.1f m -> %.1f m)" % [dist_free, player.rig.camera.global_position.distance_to(eye)])
	_check(player.spread_factor() < spread_free * 0.4, "le tir est plus précis en visant")
	_check(player.aim_distance > 10.0 and player.impact_drop_angle() > 0.0, "distance visée %.0f m, repère de chute %.2f°" % [player.aim_distance, rad_to_deg(player.impact_drop_angle())])
	var far_angle := player.impact_drop_angle()
	_hold([&"move_forward"])
	await _frames(60)
	var aim_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check(aim_speed < GameConfig.WALK_SPEED * GameConfig.AIM_MOVE_FACTOR + 0.3, "on avance lentement en visant (%.1f m/s)" % aim_speed)
	_release_all()
	player.switch_weapon(Player.Weapon.CROSSBOW)
	await _frames(30)
	_check(player.impact_drop_angle() < far_angle, "l'arbalète tombe moins que l'arc à la même distance")
	_check(player.aim_fov_factor() < GameConfig.AIM_FOV_FACTOR_BOW, "l'arbalète zoome davantage")
	Input.action_release(&"guard")
	await _frames(90)
	_check(not player.is_aiming and player.aim_blend == 0.0 and absf(player.rig.camera.fov - fov_free) < 1.0, "relâcher le clic droit : retour à la vue normale")
	player.switch_weapon(Player.Weapon.SWORD)
	Input.action_press(&"guard")
	await _frames(30)
	_check(not player.is_aiming and player.combatant.guard_held, "avec l'épée, le clic droit pare toujours (pas de visée)")
	Input.action_release(&"guard")
	# annuler la corde avec X
	player.switch_weapon(Player.Weapon.BOW)
	Input.action_press(&"attack")
	player.start_draw()
	await _frames(30)
	Input.action_press(&"cancel_draw")
	await _frames(3)
	Input.action_release(&"cancel_draw")
	Input.action_release(&"attack")
	await _frames(5)
	_check(not player.drawing, "X annule la corde sans tirer")
	player.switch_weapon(Player.Weapon.SWORD)

	print("[Déplacement en regardant la caméra]")
	player.switch_weapon(Player.Weapon.SWORD)
	player.combatant.reset()
	_teleport(Vector3(0, 0.05, 2), 0.0)
	player.rig.pitch = 0.0
	await _frames(60)
	var m2: HeroModel = player.model
	_hold([&"move_back"])
	await _frames(90)
	_check(absf(angle_difference(player.facing_yaw, player.rig.yaw)) < 0.1, "en reculant, le héros garde le regard vers l'avant (il ne se retourne pas)")
	var back_blend: Vector2 = m2.tree.get("parameters/Loco/blend_position")
	_check(back_blend.y < -0.7 and absf(back_blend.x) < 0.3, "en reculant, l'animation de marche arrière est jouée (%.1f, %.1f)" % [back_blend.x, back_blend.y])
	_release_all()
	await _frames(60)
	_teleport(Vector3(0, 0.05, 2), 0.0)
	_hold([&"move_right"])
	await _frames(90)
	_check(absf(angle_difference(player.facing_yaw, player.rig.yaw)) < 0.1, "sur le côté, le héros garde le regard vers l'avant")
	var side_blend: Vector2 = m2.tree.get("parameters/Loco/blend_position")
	_check(side_blend.x > 0.7 and absf(side_blend.y) < 0.3, "sur le côté, l'animation de pas de côté est jouée (%.1f, %.1f)" % [side_blend.x, side_blend.y])
	_release_all()
	await _frames(60)
	_teleport(Vector3(0, 0.05, 6), 0.0)
	player.rig.yaw = 2.0   # la caméra tourne : le corps suit
	await _frames(60)
	_check(absf(angle_difference(player.facing_yaw, 2.0)) < 0.15, "le corps suit la caméra quand elle tourne")
	player.rig.yaw = 0.0
	await _frames(60)

	print("[Animations]")
	player.switch_weapon(Player.Weapon.SWORD)
	player.combatant.reset()
	player.model.reset()
	_teleport(Vector3(0, 0.05, 9), 0.0)
	await _frames(60)
	var model: HeroModel = player.model
	_check(model.tree.active and model.skeleton.get_bone_count() == 67, "le chevalier est chargé (67 os) et l'AnimationTree est actif")
	_check(model.anim_player.get_animation_list().size() >= 22, "bibliothèque d'animations chargée (%d animations)" % model.anim_player.get_animation_list().size())
	# jambes qui marchent pendant que le haut du corps attaque
	var leg := model.skeleton.find_bone("mixamorig_LeftUpLeg")
	var arm := model.skeleton.find_bone("mixamorig_RightForeArm")
	_hold([&"move_forward"])
	await _frames(60)
	player.aim_dir = Combatant.Dir.RIGHT
	player.try_attack()
	var leg_angle := 0.0
	var arm_angle := 0.0
	var leg_prev: Quaternion = model.skeleton.get_bone_pose_rotation(leg)
	var arm_prev: Quaternion = model.skeleton.get_bone_pose_rotation(arm)
	var upper_max := 0.0
	var state_seen := ""
	for i in 40:
		await process_frame
		var lq: Quaternion = model.skeleton.get_bone_pose_rotation(leg)
		var aq: Quaternion = model.skeleton.get_bone_pose_rotation(arm)
		leg_angle += lq.angle_to(leg_prev)
		arm_angle += aq.angle_to(arm_prev)
		leg_prev = lq
		arm_prev = aq
		upper_max = maxf(upper_max, model.tree.get("parameters/UpperBlend/blend_amount"))
		if str(model.tree.get("parameters/Upper/current_state")) == "attack_right":
			state_seen = "attack_right"
	_release_all()
	_check(upper_max > 0.9 and state_seen == "attack_right", "haut du corps : animation d'attaque jouée (%s, mélange %.1f)" % [state_seen, upper_max])
	_check(leg_angle > 0.3, "les jambes continuent de marcher pendant l'attaque (%.2f rad)" % leg_angle)
	_check(arm_angle > 0.5, "le bras d'épée bouge pendant l'attaque (%.2f rad)" % arm_angle)
	await _frames(120)
	# calage : au début du coup, l'animation est à l'instant du contact
	var lib := model.anim_player.get_animation_library("")
	var fake := Combatant.new()
	fake.state = Combatant.State.STRIKE
	fake.state_time = 0.0
	fake.state_duration = 0.14
	for d in 4:
		fake.attack_dir = d
		var anim := lib.get_animation(HeroModel.ATTACK_ANIMS[d])
		var want: float = minf(float(anim.get_meta(&"peak_time")) + GameConfig.ANIM_CONTACT_OFFSET, float(anim.get_meta(&"end_time")))
		_check(absf(model._attack_time(fake) - want) < 0.01, "attaque %s : le contact visuel tombe au début du coup (%.2f s)" % [GameConfig.DIR_NAMES[d], want])
	fake.free()
	# esquive, mort, remise à zéro
	player.try_attack()
	player.combatant.reset()
	player.model.reset()
	_hold([&"move_right"])
	Input.action_press(&"dodge")
	await _frames(3)
	Input.action_release(&"dodge")
	await _frames(10)
	_check(player.is_dodging and model.tree.get("parameters/Full/current_state") == "dodge_r", "pas de côté à droite : animation d'esquive à droite")
	_release_all()
	await _frames(120)
	player.combatant.invincible = false
	player.combatant.take_damage(9999.0)
	await _frames(30)
	_check(player.combatant.dead and model.tree.get("parameters/FullBlend/blend_amount") > 0.9 and model.tree.get("parameters/Full/current_state") == "death", "mort : animation de mort jouée")
	player.combatant.invincible = true
	player.reset_to(Vector3(0, 0.05, 9), 0.0)
	await _frames(30)
	_check(not player.combatant.dead and model.tree.get("parameters/FullBlend/blend_amount") < 0.1, "remise à zéro : le chevalier se relève")
	var enemy_mesh: MeshInstance3D = enemy.model.model_root.find_children("*", "MeshInstance3D", true, false)[0]
	var tint_mat := enemy_mesh.get_surface_override_material(0) as StandardMaterial3D
	_check(tint_mat != null and tint_mat.albedo_color.r > tint_mat.albedo_color.g + 0.05, "l'ennemi est teinté en rouge sombre")

	print("[Ennemi face aux tirs]")
	# garde contre une flèche vue à temps (scène figée pour être déterministe)
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.aggressive = false
	enemy.combatant.invincible = false
	enemy.set_difficulty(2)
	_teleport(Vector3(0, 0.05, 9), 0.0)
	enemy.reset_to(Vector3(0, 0, -2))
	enemy.set_physics_process(false)   # figé (son corps reste là) pour un test déterministe
	await _frames(5)
	seed(777)
	var guarded_results := []
	enemy.combatant.hit_resolved.connect(func(r: int, _d: int, _a: float, _by: Combatant): guarded_results.append(r))
	var protected_hits := 0
	for n in 12:
		enemy.combatant.reset()
		enemy.set_difficulty(2)
		enemy._arrow_guard = 0.0
		enemy._handled_arrows.clear()
		var incoming := Arrow.spawn(main, Vector3(0, 1.1, 4.0), Vector3(0, 0, -30.0), 0.0, 20.0, player.combatant)
		incoming.age = 1.0   # il l'a "vue" partir depuis assez longtemps
		enemy._update_defense(0.016, 6.0)
		if enemy._arrow_guard > 0.0:
			protected_hits += 1
		await _frames(60)
		incoming.queue_free()
	var parried := 0
	var wounded := 0
	for r in guarded_results:
		if r == Combatant.Result.BLOCKED or r == Combatant.Result.PARRIED:
			parried += 1
		elif r == Combatant.Result.HIT:
			wounded += 1
	_check(protected_hits >= 8, "difficile : il lève la garde contre la plupart des tirs qu'il voit (%d/12)" % protected_hits)
	_check(parried >= 8, "et la flèche est bien parée (%d parées, %d touchent)" % [parried, wounded])
	enemy.combatant.reset()
	enemy._arrow_guard = 0.0
	enemy.combatant.set_guard(false, 0)
	var unseen := Arrow.spawn(main, Vector3(0, 1.1, 4.0), Vector3(0, 0, -30.0), 0.0, 20.0, player.combatant)
	await _frames(60)
	_check(enemy.combatant.health < enemy.combatant.max_health, "sans garde, la flèche le blesse")
	unseen.queue_free()

	# mise à couvert : le héros tient un arc, l'ennemi file derrière un pilier ou une caisse
	seed(2024)
	enemy.set_physics_process(true)
	enemy.set_difficulty(2)
	enemy.reset_to(Vector3(0, 0, -6))
	_teleport(Vector3(0, 0.05, 9), 0.0)
	player.switch_weapon(Player.Weapon.BOW)
	var found_cover := false
	var saw_zigzag := false
	var hidden := false
	for i in 120 * 16:
		await physics_frame
		saw_zigzag = saw_zigzag or enemy.mode == Enemy.Mode.EVADE
		if enemy.mode == Enemy.Mode.COVER:
			found_cover = true
			if enemy.global_position.distance_to(enemy._cover_point) < 0.7:
				var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 1.65, 0), enemy.global_position + Vector3(0, 1.1, 0), GameConfig.LAYER_WORLD)
				hidden = not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
				break
	_check(found_cover, "face à un archer, il peut se mettre à couvert")
	_check(hidden, "et il se cache vraiment : un obstacle le sépare du tireur")
	player.switch_weapon(Player.Weapon.SWORD)

	print("")
	print("RÉSULTAT : %s (%d échec(s))" % ["SUCCÈS" if failures == 0 else "ÉCHEC", failures])
	quit(1 if failures > 0 else 0)
