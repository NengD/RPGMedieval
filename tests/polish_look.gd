extends SceneTree
## Animations plus naturelles : captures user://polish_*.png (marche sur rampe, regard, ragdoll, deux mains, coup reçu)
func _initialize() -> void:
	_run()
var cam: Camera3D
var p: Player
func _snap(name: String, offset: Vector3, look: Vector3) -> void:
	cam.global_position = p.global_position + offset
	cam.look_at(p.global_position + look, Vector3.UP)
	cam.current = true
	await process_frame
	await process_frame
	root.get_texture().get_image().get_region(Rect2i(240, 40, 480, 460)).save_png("user://polish_%s.png" % name)
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	p = main.player
	main.enemy.ai_enabled = false
	cam = Camera3D.new()
	main.add_child(cam)
	# 1. regard : l'ennemi est devant, la tête le suit
	await _snap("regard", Vector3(2.4, 1.6, 1.2), Vector3(0, 1.4, -0.5))
	# 2. deux mains : lance
	p.combatant.equipment.equip_weapon(Registry.get_data(&"arme.lance"))
	for i in 40: await physics_frame
	await _snap("lance", Vector3(2.6, 1.4, 0.4), Vector3(0, 1.1, -0.3))
	p.combatant.equipment.equip_weapon(Registry.get_data(&"arme.epee_deux_mains"))
	for i in 40: await physics_frame
	await _snap("deux_mains", Vector3(2.4, 1.4, 0.6), Vector3(0, 1.1, -0.3))
	p.combatant.equipment.equip_weapon(Registry.get_data(&"arme.epee_longue"))
	# 3. rampe : le héros monte
	p.global_position = Vector3(9.0, 0.05, -4.0)
	p.facing_yaw = 0.0
	for i in 5: await physics_frame
	Input.action_press(&"move_forward")
	for i in 150: await physics_frame
	await _snap("rampe", Vector3(3.0, 1.2, 1.0), Vector3(0, 1.0, -0.5))
	Input.action_release(&"move_forward")
	# 4. coup reçu de la gauche
	p.reset_to(Vector3(0, 0.05, 9), 0.0)
	for i in 30: await physics_frame
	p.combatant.invincible = false
	var fake: Combatant = main.enemy.combatant
	main.enemy.global_position = p.global_position + Vector3(-1.6, 0, 0.2)
	p.combatant.receive_hit(fake, 1, 30.0)
	for i in 10: await physics_frame
	await _snap("coup_gauche", Vector3(2.6, 1.4, 0.6), Vector3(0, 1.1, 0))
	# 5. ragdoll
	p.combatant.take_damage(9999.0)
	for i in 25: await physics_frame
	await _snap("ragdoll_a", Vector3(2.6, 1.6, 2.0), Vector3(0, 0.6, 0))
	for i in 120: await physics_frame
	await _snap("ragdoll_b", Vector3(2.6, 1.8, 2.0), Vector3(0, 0.3, 0))
	quit()
