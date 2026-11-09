class_name Ragdoll
extends RefCounted
## Mort en ragdoll : un PhysicalBoneSimulator3D avec une capsule par gros os. Les pièces d'armure (maillages skinnés sur le même
## squelette) et les armes (BoneAttachment3D) suivent automatiquement. Les capsules ne touchent que le monde (arène).

# os -> [os enfant qui donne la longueur, rayon, masse]
const BONES := {
	"mixamorig_Hips": ["mixamorig_Spine", 0.13, 8.0],
	"mixamorig_Spine1": ["mixamorig_Spine2", 0.14, 6.0],
	"mixamorig_Spine2": ["mixamorig_Neck", 0.15, 8.0],
	"mixamorig_Head": ["mixamorig_HeadTop_End", 0.10, 4.0],
	"mixamorig_LeftArm": ["mixamorig_LeftForeArm", 0.055, 2.0],
	"mixamorig_LeftForeArm": ["mixamorig_LeftHand", 0.045, 1.5],
	"mixamorig_LeftHand": ["mixamorig_LeftHandMiddle1", 0.04, 0.6],
	"mixamorig_RightArm": ["mixamorig_RightForeArm", 0.055, 2.0],
	"mixamorig_RightForeArm": ["mixamorig_RightHand", 0.045, 1.5],
	"mixamorig_RightHand": ["mixamorig_RightHandMiddle1", 0.04, 0.6],
	"mixamorig_LeftUpLeg": ["mixamorig_LeftLeg", 0.085, 5.0],
	"mixamorig_LeftLeg": ["mixamorig_LeftFoot", 0.065, 3.0],
	"mixamorig_LeftFoot": ["mixamorig_LeftToeBase", 0.05, 1.0],
	"mixamorig_RightUpLeg": ["mixamorig_RightLeg", 0.085, 5.0],
	"mixamorig_RightLeg": ["mixamorig_RightFoot", 0.065, 3.0],
	"mixamorig_RightFoot": ["mixamorig_RightToeBase", 0.05, 1.0],
}


## Crée le simulateur (désactivé tant qu'on n'appelle pas start). Retourne null si le squelette est incomplet.
## Articulations : os -> [type, paramètres]. « hinge » (coude, genou) : un seul sens de pliage, de 0° (jambe tendue) à `max` ; « cone » : rotation limitée à `swing` degrés.
## Les os absents utilisent un cône de 70°.
## Charnière : [« hinge », min°, max°, rotation du repère de la charnière en degrés]. Valeurs mesurées avec tools/ragdoll_probe.gd :
## les coudes fléchissent autour de l'axe Z de l'os du bras, les genoux autour de l'axe X de l'os de la cuisse ; le sens est inversé à droite / à gauche.
const JOINTS := {
	"mixamorig_LeftForeArm": ["hinge", 0.0, 145.0, Vector3(0, 0, 0)],
	"mixamorig_RightForeArm": ["hinge", -145.0, 0.0, Vector3(0, 0, 0)],
	"mixamorig_LeftLeg": ["hinge", -140.0, 0.0, Vector3(0, 90, 0)],
	"mixamorig_RightLeg": ["hinge", -140.0, 0.0, Vector3(0, 90, 0)],
	"mixamorig_Head": ["cone", 40.0],
	"mixamorig_LeftHand": ["cone", 45.0], "mixamorig_RightHand": ["cone", 45.0],
	"mixamorig_LeftFoot": ["cone", 35.0], "mixamorig_RightFoot": ["cone", 35.0],
	"mixamorig_Spine1": ["cone", 30.0], "mixamorig_Spine2": ["cone", 30.0],
}
static var test_override := {}


static func build(skeleton: Skeleton3D) -> PhysicalBoneSimulator3D:
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skeleton.add_child(sim)
	for bone_name in BONES:
		var idx := skeleton.find_bone(bone_name)
		var child_idx := skeleton.find_bone(BONES[bone_name][0])
		if idx < 0 or child_idx < 0:
			continue
		var length: float = skeleton.get_bone_rest(child_idx).origin.length()
		length = maxf(length, 0.1)
		var radius: float = BONES[bone_name][1]
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name.trim_prefix("mixamorig_")
		pb.bone_name = bone_name
		pb.mass = BONES[bone_name][2]
		pb.collision_layer = 0
		pb.collision_mask = GameConfig.LAYER_WORLD
		var joint: Array = JOINTS.get(bone_name, ["cone", 70.0])
		if joint[0] == "hinge":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			var spec: Array = test_override.get(bone_name, joint)
			var rot: Vector3 = spec[3]
			pb.joint_rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
			pb.set("joint_constraints/angular_limit_enabled", true)
			pb.set("joint_constraints/angular_limit_lower", deg_to_rad(float(spec[1])))
			pb.set("joint_constraints/angular_limit_upper", deg_to_rad(float(spec[2])))
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", float(joint[1]))
			pb.set("joint_constraints/twist_span", 25.0)
		pb.linear_damp = 0.6
		pb.angular_damp = 2.5
		sim.add_child(pb)
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = maxf(length, radius * 2.0 + 0.01)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		pb.add_child(cs)
		cs.position = Vector3(0, length * 0.5, 0)   # la capsule suit l'os (l'axe Y de l'os Mixamo va vers l'enfant)
	return sim


static func start(sim: PhysicalBoneSimulator3D, push: Vector3) -> void:
	sim.physical_bones_start_simulation()
	if push.length() > 0.01:
		for c in sim.get_children():
			if c is PhysicalBone3D:
				var pb := c as PhysicalBone3D
				if pb.name.begins_with("PB_Hips") or pb.name.begins_with("PB_Spine"):
					pb.apply_central_impulse(push * pb.mass)


static func stop(sim: PhysicalBoneSimulator3D) -> void:
	sim.physical_bones_stop_simulation()
