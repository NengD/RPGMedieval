class_name FootIK
extends Node
## Pieds posés sur le sol réel (pente, rampe, marches) : chaque jambe est une chaîne TwoBoneIK3D dont la cible suit la hauteur du terrain
## sous le pied. Sur sol plat, rien ne change. Le bassin descend quand un pied est plus bas, pour garder les jambes naturelles.
##
## Les os animés par IK ne se lisent pas en mode sans fenêtre : les calculs purs (`ground_offset`, `plant_weight`) sont testés à part.

var model: Node3D
var skeleton: Skeleton3D
var _legs: Array = []          # [{ik, target, pole, foot_bone, applied, amount}]
## Remontée (m) du personnage entier : les animations viennent d'un autre squelette et enfoncent parfois les pieds dans le sol.
var lift := 0.0
var _rest_toe_y := 0.03
var pelvis := 0.0              # décalage vertical du bassin (m, négatif = plus bas)


## Décalage de hauteur voulu pour un pied : hauteur du sol sous le pied moins hauteur du sol sous le personnage (limité).
static func ground_offset(ground_y: float, base_y: float, limit: float) -> float:
	return clampf(ground_y - base_y, -limit, limit)


## Un pied posé (proche du sol dans l'animation) suit entièrement le terrain ; un pied en l'air ne le suit presque pas.
static func plant_weight(foot_height: float) -> float:
	return 1.0 - smoothstep(0.04, 0.2, foot_height)


func setup(p_model: Node3D, p_skeleton: Skeleton3D) -> void:
	model = p_model
	skeleton = p_skeleton
	var toe := skeleton.find_bone("mixamorig_LeftToeBase")
	if toe >= 0:
		_rest_toe_y = (skeleton.get_bone_global_rest(toe)).origin.y   # hauteur des orteils quand le personnage se tient droit sur le sol
	for side in ["Left", "Right"]:
		var target := Node3D.new()
		target.name = "FootTarget" + side
		model.add_child(target)
		var pole := Node3D.new()
		pole.name = "FootPole" + side
		model.add_child(pole)
		var ik := TwoBoneIK3D.new()
		ik.name = "LegIK" + side
		skeleton.add_child(ik)
		ik.setting_count = 1
		ik.set_root_bone_name(0, "mixamorig_%sUpLeg" % side)
		ik.set_middle_bone_name(0, "mixamorig_%sLeg" % side)
		ik.set_end_bone_name(0, "mixamorig_%sFoot" % side)
		ik.set_target_node(0, ik.get_path_to(target))
		ik.set_pole_node(0, ik.get_path_to(pole))
		ik.influence = 0.0
		_legs.append({"ik": ik, "target": target, "pole": pole, "foot": "mixamorig_%sFoot" % side, "applied": 0.0, "amount": 0.0})


func _foot_world(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


## À appeler chaque image. `active` : false en l'air, en esquive, mort, ragdoll…
func update(delta: float, active: bool) -> void:
	var space := model.get_world_3d().direct_space_state
	# Sol sous le personnage (son origine peut flotter de quelques cm au-dessus du sol : marge de la capsule de collision)
	var origin_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(model.global_position + Vector3.UP * 0.5, model.global_position + Vector3.DOWN * 1.0, GameConfig.LAYER_WORLD))
	var base_y: float = (origin_hit.position.y as float) if origin_hit else model.global_position.y
	var lowest := 0.0
	var lowest_toe := 1e9
	for side in ["Left", "Right"]:
		lowest_toe = minf(lowest_toe, _foot_world("mixamorig_%sToeBase" % side).y - lift)
	var need := clampf(base_y + _rest_toe_y - lowest_toe, 0.0, 0.15) if active else 0.0
	lift = lerpf(lift, need, 1.0 - exp(-12.0 * delta))
	for leg in _legs:
		var foot := _foot_world(leg["foot"])
		var desired := 0.0
		if active and GameConfig.FOOT_IK_ENABLED:
			var q := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.5, foot + Vector3.DOWN * 0.7, GameConfig.LAYER_WORLD)
			var hit := space.intersect_ray(q)
			var ground_y := (hit.position.y as float) if hit else base_y
			var off := ground_offset(ground_y, base_y, GameConfig.FOOT_IK_MAX_OFFSET)
			var anim_height := foot.y - base_y - float(leg["applied"]) - lift   # hauteur du pied dans l'animation (sans notre correction)
			desired = off * plant_weight(anim_height)
		var old_applied: float = leg["applied"]
		var applied := lerpf(old_applied, desired, 1.0 - exp(-18.0 * delta))
		leg["applied"] = applied
		var want_amount := 1.0 if absf(applied) > 0.012 else 0.0
		leg["amount"] = move_toward(leg["amount"], want_amount, delta * 10.0)
		(leg["ik"] as TwoBoneIK3D).influence = leg["amount"]
		(leg["target"] as Node3D).global_position = Vector3(foot.x, foot.y - old_applied + applied, foot.z)
		var fwd := -model.global_transform.basis.z
		(leg["pole"] as Node3D).global_position = (leg["target"] as Node3D).global_position + fwd * 0.7 + Vector3.UP * 0.4
		lowest = minf(lowest, applied)
	pelvis = lerpf(pelvis, lowest * 0.85, 1.0 - exp(-10.0 * delta))
