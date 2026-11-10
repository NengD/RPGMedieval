class_name FingerGripModifier
extends SkeletonModifier3D
## Ferme les doigts d'une main sur une poignée (arme, arc…). Appliqué après les animations : les clips laissent la main ouverte.
## `curl` : 0 = doigts ouverts (animation), 1 = main fermée. Chaque phalange pivote autour de l'axe local `FLEX_AXIS`.

@export var side := "Right"
var curl := 0.0

## Axe de flexion des phalanges dans le repère local de l'os (mesuré sur le Mannequin : tools/finger_probe via tests/hand_look.gd).
static var FLEX_AXIS := Vector3(0, 0, 1)
static var FINGER_ANGLES := {"Index": [70.0, 85.0, 60.0], "Middle": [75.0, 90.0, 65.0], "Ring": [80.0, 90.0, 65.0], "Pinky": [85.0, 90.0, 65.0]}
static var THUMB_ANGLES := [30.0, 45.0, 40.0]
static var THUMB_AXIS := Vector3(0, 0, 1)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or curl <= 0.001:
		return
	for finger in FINGER_ANGLES:
		for k in 3:
			_bend(sk, "mixamorig_%sHand%s%d" % [side, finger, k + 1], float(FINGER_ANGLES[finger][k]) * curl)
	for k in 3:
		_bend(sk, "mixamorig_%sHandThumb%d" % [side, k + 1], float(THUMB_ANGLES[k]) * curl, true)


func _bend(sk: Skeleton3D, bone: String, degrees: float, thumb := false) -> void:
	var idx := sk.find_bone(bone)
	if idx < 0:
		return
	var axis := FLEX_AXIS
	if thumb:
		axis = THUMB_AXIS
	var sign_side := 1.0 if side == "Right" else -1.0
	var q := Quaternion(axis, deg_to_rad(degrees) * sign_side)
	sk.set_bone_pose_rotation(idx, sk.get_bone_pose_rotation(idx) * q)
