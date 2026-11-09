extends SceneTree
## Mesure les angles de coude et de genou d'un ragdoll lancé avec une poussée : 0° = tendu, valeurs négatives = hyper-extension.
## godot --headless --path . -s tools/ragdoll_probe.gd -- <rotX> <rotY> <rotZ>
func _initialize() -> void:
	_run()
func _pos(m: HeroModel, name: String) -> Vector3:
	return (m.ragdoll_sim.get_node("PB_" + name) as Node3D).global_position
var _flex_axis := {}   # os supérieur -> axe de pliage naturel dans le repère de l'os (mesuré sur la pose animée)
## Angle signé : positif = pliage dans le sens de la pose animée (coude / genou fléchis), négatif = hyper-extension.
func _angle(m: HeroModel, a: String, b: String, c: String) -> float:
	var v1 := _pos(m, b) - _pos(m, a)
	var v2 := _pos(m, c) - _pos(m, b)
	var ang := rad_to_deg(v1.angle_to(v2))
	var axis_local: Vector3 = (m.ragdoll_sim.get_node("PB_" + a) as Node3D).global_basis.inverse() * v1.cross(v2).normalized()
	if not _flex_axis.has(a):
		_flex_axis[a] = axis_local
		print("AXE de pliage naturel de ", a, " dans son repère : ", axis_local.snapped(Vector3(0.01, 0.01, 0.01)))
	return ang * signf(axis_local.dot(_flex_axis[a]))

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 4:   # elbow_min elbow_max knee_min knee_max (joint rot fixed above)
		var e := float(args[0]); var e2 := float(args[1]); var k := float(args[2]); var k2 := float(args[3])
		Ragdoll.test_override = {
			"mixamorig_LeftForeArm": ["hinge", e, e2, Vector3(0, 0, 0)], "mixamorig_RightForeArm": ["hinge", -e2, -e, Vector3(0, 0, 0)],
			"mixamorig_LeftLeg": ["hinge", k, k2, Vector3(0, 90, 0)], "mixamorig_RightLeg": ["hinge", k, k2, Vector3(0, 90, 0)]}
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameConfig.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var m := HeroModel.new()
	root.add_child(m)
	for i in 3: await physics_frame
	m.tree.active = false
	m.anim_player.play(&"idle")
	m.anim_player.seek(0.3, true)
	m.anim_player.stop(true)
	for i in 3: await physics_frame
	_angle(m, "LeftArm", "LeftForeArm", "LeftHand")
	_angle(m, "RightArm", "RightForeArm", "RightHand")
	_angle(m, "LeftUpLeg", "LeftLeg", "LeftFoot")
	_angle(m, "RightUpLeg", "RightLeg", "RightFoot")
	Ragdoll.start(m.ragdoll_sim, Vector3(0, 0, -4))
	var mins := {"coude G": 999.0, "coude D": 999.0, "genou G": 999.0, "genou D": 999.0}
	var maxs := {"coude G": -999.0, "coude D": -999.0, "genou G": -999.0, "genou D": -999.0}
	for i in 360:
		await physics_frame
		var vals := {
			"coude G": _angle(m, "LeftArm", "LeftForeArm", "LeftHand"),
			"coude D": _angle(m, "RightArm", "RightForeArm", "RightHand"),
			"genou G": _angle(m, "LeftUpLeg", "LeftLeg", "LeftFoot"),
			"genou D": _angle(m, "RightUpLeg", "RightLeg", "RightFoot"),
		}
		for k in vals:
			mins[k] = minf(mins[k], vals[k])
			maxs[k] = maxf(maxs[k], vals[k])
	var hips := _pos(m, "Hips")
	print("RAGDOLL rot="," hanches y=", snappedf(hips.y, 0.01), " | ", mins.keys().map(func(k): return "%s %.0f..%.0f" % [k, mins[k], maxs[k]]))
	quit()
