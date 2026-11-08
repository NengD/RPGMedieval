class_name HeroModel
extends Node3D
## Personnage animé (modèle Mixamo). Utilisé par le héros ET l'ennemi.
##
## AnimationTree :
##   Loco (marche / course / pas de côté / recul, selon la vitesse locale)
##     -> [haut du corps : attaque, parade ou coup reçu, mélangés avec un filtre sur la colonne et les bras]
##     -> [corps entier : esquive, saut, mort]
## Les attaques sont "scrubbées" : l'animation avance au rythme du Combatant (préparation / coup /
## récupération), donc le coup visuel tombe exactement quand le coup réel touche.

const MODEL := "res://assets/hero/hero.fbx"
const LIBRARY := "res://assets/anims/hero_library.res"
const ATTACK_ANIMS := [&"attack_up", &"attack_right", &"attack_estoc", &"attack_left"]
const HIT_ANIMS := [&"hit_1", &"hit_2", &"hit_3"]
const FULL_STATES := [&"dodge_l", &"dodge_r", &"dodge_b", &"jump", &"death", &"attack_up", &"attack_right", &"attack_estoc", &"attack_left"]
const UPPER_STATES := [&"attack_up", &"attack_right", &"attack_estoc", &"attack_left", &"guard", &"hit_1", &"hit_2", &"hit_3"]

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var tree: AnimationTree
var combatant: Combatant
var sword_holder: BoneAttachment3D
var shield_holder: BoneAttachment3D
var model_root: Node3D

var _library: AnimationLibrary
var _upper_mode: StringName = &""
var _full_mode: StringName = &""
var _upper_amount := 0.0
var _full_amount := 0.0
var _dead := false
var _was_dodging := false
var _was_airborne := false
var _last_speed := 0.0
var ik: TwoBoneIK3D
var ik_target: Node3D
var ik_pole: Node3D
var hand_aim: HandAimModifier
var _ik_amount := 0.0
var _attack_full_body := false


func _ready() -> void:
	var scene: PackedScene = load(MODEL)
	model_root = scene.instantiate() as Node3D
	add_child(model_root)
	model_root.rotation.y = PI   # le modèle regarde vers +Z ; le jeu vers -Z
	for n in model_root.find_children("*", "AnimationPlayer", true, false):
		n.get_parent().remove_child(n)
		n.free()
	skeleton = model_root.find_children("*", "Skeleton3D", true, false)[0]
	_library = load(LIBRARY)
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	model_root.add_child(anim_player)
	anim_player.add_animation_library("", _library)
	_build_tree()
	_build_attachments()
	_build_ik()


func bind(c: Combatant) -> void:
	combatant = c
	c.attack_started.connect(_on_attack_started)
	c.staggered.connect(_on_staggered)
	c.died.connect(_on_died)


## Remet le personnage debout, au repos.
func reset() -> void:
	_dead = false
	_upper_mode = &""
	_full_mode = &""
	_upper_amount = 0.0
	_full_amount = 0.0
	if tree:
		tree.set("parameters/UpperBlend/blend_amount", 0.0)
		tree.set("parameters/FullBlend/blend_amount", 0.0)
		tree.set("parameters/UpperTS/scale", 1.0)


## Donne une teinte au modèle (ennemi rouge sombre).
func tint(color: Color) -> void:
	for mi in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		for s in mesh.mesh.get_surface_count():
			var base := mesh.get_active_material(s)
			var mat: StandardMaterial3D
			if base is StandardMaterial3D:
				mat = base.duplicate()
			else:
				mat = StandardMaterial3D.new()
			mat.albedo_color = mat.albedo_color * color
			mesh.set_surface_override_material(s, mat)


## Éclair blanc très court quand le personnage est touché.
func flash(duration := 0.09) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in model_root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(model_root):
			for mi in model_root.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = null)


func show_sword(on: bool) -> void:
	sword_holder.visible = on


# ---------------------------------------------------------------- construction

func _anim_node(anim: StringName, loop := false) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = anim
	return n


func _transition(states: Array, xfade: float) -> AnimationNodeTransition:
	var t := AnimationNodeTransition.new()
	t.input_count = states.size()
	for i in states.size():
		t.set("input_%d/name" % i, str(states[i]))
		t.set("input_%d/reset" % i, true)   # l'animation repart du début à chaque fois
	t.xfade_time = xfade
	t.allow_transition_to_self = true
	return t


func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	var walk := GameConfig.WALK_SPEED
	var run_k := GameConfig.RUN_SPEED / walk

	# Locomotion : x = vers la droite, y = vers l'avant (en multiples de la vitesse de marche)
	var loco := AnimationNodeBlendSpace2D.new()
	loco.min_space = Vector2(-2.5, -2.5)
	loco.max_space = Vector2(2.5, 2.5)
	loco.add_blend_point(_anim_node(&"idle"), Vector2(0, 0), -1, &"idle")
	loco.add_blend_point(_anim_node(&"walk_f"), Vector2(0, 1), -1, &"walk_f")
	loco.add_blend_point(_anim_node(&"run_f"), Vector2(0, run_k), -1, &"run_f")
	loco.add_blend_point(_anim_node(&"walk_b"), Vector2(0, -1), -1, &"walk_b")
	loco.add_blend_point(_anim_node(&"run_b"), Vector2(0, -run_k), -1, &"run_b")
	loco.add_blend_point(_anim_node(&"strafe_r"), Vector2(1, 0), -1, &"strafe_r")
	loco.add_blend_point(_anim_node(&"strafe_r_run"), Vector2(run_k, 0), -1, &"strafe_r_run")
	loco.add_blend_point(_anim_node(&"strafe_l"), Vector2(-1, 0), -1, &"strafe_l")
	loco.add_blend_point(_anim_node(&"strafe_l_run"), Vector2(-run_k, 0), -1, &"strafe_l_run")
	bt.add_node(&"Loco", loco, Vector2(0, 0))
	var loco_ts := AnimationNodeTimeScale.new()
	bt.add_node(&"LocoTS", loco_ts, Vector2(200, 0))
	bt.connect_node(&"LocoTS", 0, &"Loco")

	# Haut du corps : choix de l'animation, vitesse (0 = on la pilote à la main), saut dans le temps
	var upper := _transition(UPPER_STATES, 0.0)
	bt.add_node(&"Upper", upper, Vector2(0, 300))
	for i in UPPER_STATES.size():
		var node_name := StringName("A_" + str(UPPER_STATES[i]))
		bt.add_node(node_name, _anim_node(UPPER_STATES[i]), Vector2(-200, 200 + i * 60))
		bt.connect_node(&"Upper", i, node_name)
	bt.add_node(&"UpperTS", AnimationNodeTimeScale.new(), Vector2(200, 300))
	bt.connect_node(&"UpperTS", 0, &"Upper")
	bt.add_node(&"UpperSeek", AnimationNodeTimeSeek.new(), Vector2(400, 300))
	bt.connect_node(&"UpperSeek", 0, &"UpperTS")

	var upper_blend := AnimationNodeBlend2.new()
	upper_blend.filter_enabled = true
	for bone_path in _upper_body_paths():
		upper_blend.set_filter_path(bone_path, true)
	bt.add_node(&"UpperBlend", upper_blend, Vector2(600, 100))
	bt.connect_node(&"UpperBlend", 0, &"LocoTS")
	bt.connect_node(&"UpperBlend", 1, &"UpperSeek")

	# Corps entier : esquive, saut, mort
	var full := _transition(FULL_STATES, 0.0)   # pas de fondu : la vitesse est à 0 pendant les attaques pilotées à la main, un fondu resterait bloqué
	bt.add_node(&"Full", full, Vector2(0, 700))
	for i in FULL_STATES.size():
		var node_name := StringName("F_" + str(FULL_STATES[i]))
		bt.add_node(node_name, _anim_node(FULL_STATES[i]), Vector2(-200, 650 + i * 60))
		bt.connect_node(&"Full", i, node_name)
	bt.add_node(&"FullTS", AnimationNodeTimeScale.new(), Vector2(200, 700))
	bt.connect_node(&"FullTS", 0, &"Full")
	bt.add_node(&"FullSeek", AnimationNodeTimeSeek.new(), Vector2(400, 700))
	bt.connect_node(&"FullSeek", 0, &"FullTS")
	var full_blend := AnimationNodeBlend2.new()
	bt.add_node(&"FullBlend", full_blend, Vector2(800, 100))
	bt.connect_node(&"FullBlend", 0, &"UpperBlend")
	bt.connect_node(&"FullBlend", 1, &"FullSeek")
	bt.connect_node(&"output", 0, &"FullBlend")

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	model_root.add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	tree.tree_root = bt
	tree.active = true
	tree.set("parameters/UpperTS/scale", 1.0)
	tree.set("parameters/FullTS/scale", 1.0)


## Les os du haut du corps : colonne vertébrale et tout ce qui en descend (épaules, bras, tête).
func _upper_body_paths() -> Array:
	var paths: Array = []
	var spine := skeleton.find_bone("mixamorig_Spine")
	for i in skeleton.get_bone_count():
		var b := i
		var inside := false
		while b != -1:
			if b == spine:
				inside = true
				break
			b = skeleton.get_bone_parent(b)
		if inside:
			paths.append(NodePath("Skeleton3D:" + skeleton.get_bone_name(i)))
	return paths


## Cinématique inverse du bras d'épée : sert à diriger la main pour le coup d'en haut et l'estoc.
func _build_ik() -> void:
	ik_target = Node3D.new()
	ik_target.name = "IKTarget"
	add_child(ik_target)
	ik_pole = Node3D.new()
	ik_pole.name = "IKPole"
	add_child(ik_pole)
	ik = TwoBoneIK3D.new()
	ik.name = "ArmIK"
	skeleton.add_child(ik)
	ik.setting_count = 1
	ik.set_root_bone_name(0, "mixamorig_RightArm")
	ik.set_middle_bone_name(0, "mixamorig_RightForeArm")
	ik.set_end_bone_name(0, "mixamorig_RightHand")
	ik.set_target_node(0, ik.get_path_to(ik_target))
	ik.set_pole_node(0, ik.get_path_to(ik_pole))
	ik.influence = 0.0
	hand_aim = HandAimModifier.new()   # APRÈS le TwoBoneIK3D : il oriente la lame une fois la main placée
	hand_aim.name = "HandAim"
	skeleton.add_child(hand_aim)
	hand_aim.influence = 0.0


## Où doit être la main (repère du personnage) pendant le coup d'en haut / l'estoc.
func _ik_hand_position(c: Combatant) -> Vector3:
	var p := clampf(c.state_time / maxf(c.state_duration, 0.001), 0.0, 1.0)
	var raised := GameConfig.IK_UP_RAISED
	var contact := GameConfig.IK_UP_CONTACT
	var follow := GameConfig.IK_UP_FOLLOW
	if c.attack_dir == Combatant.Dir.DOWN:
		raised = GameConfig.IK_STAB_COCKED
		contact = GameConfig.IK_STAB_CONTACT
		follow = GameConfig.IK_STAB_FOLLOW
	match c.state:
		Combatant.State.WINDUP:
			var stab := c.attack_dir == Combatant.Dir.DOWN
			var share := GameConfig.IK_RAISE_SHARE if stab else GameConfig.IK_UP_RAISE_SHARE
			if p < share:
				return GameConfig.IK_REST.lerp(raised, ease(p / share, 0.4 if stab else 0.85))   # lever / armer (le coup d'en haut monte de façon continue)
			return raised.lerp(contact, ease((p - share) / (1.0 - share), 1.8))   # le geste rapide, juste avant le coup
		Combatant.State.STRIKE:
			return contact.lerp(follow, p)
		_:
			return follow.lerp(GameConfig.IK_REST, ease(p, 0.6))


## Où doit pointer la lame (repère du personnage).
func _ik_blade_direction(c: Combatant) -> Vector3:
	if c.attack_dir == Combatant.Dir.DOWN:
		return GameConfig.IK_BLADE_STAB
	var p := clampf(c.state_time / maxf(c.state_duration, 0.001), 0.0, 1.0)
	var raised := GameConfig.IK_BLADE_UP_RAISED.normalized()
	var contact := GameConfig.IK_BLADE_UP_CONTACT.normalized()
	match c.state:
		Combatant.State.WINDUP:
			var share := GameConfig.IK_UP_RAISE_SHARE
			if p < share:
				return GameConfig.IK_REST_BLADE.normalized().slerp(raised, ease(p / share, 0.85))
			return raised.slerp(contact, ease((p - share) / (1.0 - share), 1.8))
		Combatant.State.STRIKE:
			return contact
		_:
			return contact.slerp(GameConfig.IK_REST_BLADE.normalized(), ease(p, 0.6))


func _update_ik(delta: float, attacking: bool) -> void:
	var directed: bool = attacking and (combatant.attack_dir == Combatant.Dir.UP or combatant.attack_dir == Combatant.Dir.DOWN)
	_ik_amount = move_toward(_ik_amount, 1.0 if directed else 0.0, delta * 12.0)
	ik.influence = _ik_amount
	hand_aim.influence = _ik_amount
	if _ik_amount > 0.0 or directed:
		var local := _ik_hand_position(combatant) if directed else GameConfig.IK_REST
		ik_target.global_position = global_transform * local
		ik_pole.global_position = global_transform * GameConfig.IK_POLE
		hand_aim.target_direction_world = global_transform.basis * (_ik_blade_direction(combatant) if directed else GameConfig.IK_REST_BLADE)


func _build_attachments() -> void:
	# Épée dans la main droite
	sword_holder = BoneAttachment3D.new()
	sword_holder.name = "SwordHolder"
	sword_holder.bone_name = "mixamorig_RightHand"
	skeleton.add_child(sword_holder)
	var sword := Node3D.new()
	sword.name = "Sword"
	sword_holder.add_child(sword)
	sword.rotation_degrees = Vector3(0, 0, -90)   # la lame suit l'axe X de l'os de la main (vers l'avant et le haut)
	sword.position = Vector3(0.0, 0.08, 0.0)
	_add_box(sword, Vector3(0.05, 0.85, 0.012), Vector3(0, 0.55, 0), Color(0.8, 0.82, 0.88), 0.9, 0.25)
	_add_box(sword, Vector3(0.22, 0.035, 0.05), Vector3(0, 0.12, 0), Color(0.75, 0.6, 0.2), 0.7, 0.4)
	_add_box(sword, Vector3(0.035, 0.2, 0.035), Vector3(0, -0.02, 0), Color(0.35, 0.2, 0.1), 0.0, 0.8)
	# Bouclier au bras gauche
	shield_holder = BoneAttachment3D.new()
	shield_holder.name = "ShieldHolder"
	shield_holder.bone_name = "mixamorig_LeftForeArm"
	skeleton.add_child(shield_holder)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metallic: float, roughness: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)


# ---------------------------------------------------------------- réactions aux événements

func _on_attack_started(dir: int) -> void:
	_attack_full_body = _last_speed < GameConfig.ATTACK_FULLBODY_SPEED
	if _attack_full_body:
		_upper_mode = &""
		_set_full(ATTACK_ANIMS[dir], 0.0)   # vitesse 0 : on pilote l'animation à la main
	else:
		_set_upper(ATTACK_ANIMS[dir])


func _on_staggered(_perfect: bool) -> void:
	if _dead:
		return
	_set_upper(HIT_ANIMS[randi() % HIT_ANIMS.size()])


func _on_died() -> void:
	_dead = true
	_full_mode = &"death"
	tree.set("parameters/Full/transition_request", "death")
	tree.set("parameters/FullTS/scale", 1.0)


func _set_upper(mode: StringName) -> void:
	_upper_mode = mode
	tree.set("parameters/Upper/transition_request", str(mode))
	var scrubbed := str(mode).begins_with("attack")
	tree.set("parameters/UpperTS/scale", 0.0 if scrubbed else 1.0)


func _set_full(mode: StringName, time_scale: float) -> void:
	_full_mode = mode
	tree.set("parameters/Full/transition_request", str(mode))
	tree.set("parameters/FullTS/scale", time_scale)


# ---------------------------------------------------------------- chaque image

## velocity : vitesse du monde ; body_basis : orientation du corps ; dodge_dir : direction du pas de côté.
func drive(delta: float, velocity: Vector3, body_basis: Basis, on_floor: bool, is_dodging: bool, dodge_dir: Vector3) -> void:
	if combatant == null or tree == null:
		return
	var c := combatant
	var local := body_basis.inverse() * velocity
	var horizontal := Vector2(velocity.x, velocity.z).length()
	_last_speed = horizontal
	tree.set("parameters/Loco/blend_position", Vector2(local.x, -local.z) / GameConfig.WALK_SPEED)
	tree.set("parameters/LocoTS/scale", clampf(horizontal / 2.0, 1.0, 1.9))

	# --- haut du corps
	var upper_target := 0.0
	if not _dead:
		match c.state:
			Combatant.State.WINDUP, Combatant.State.STRIKE, Combatant.State.RECOVERY:
				if _attack_full_body:
					tree.set("parameters/FullSeek/seek_request", _attack_time(c))
				else:
					upper_target = 1.0
					if str(_upper_mode).begins_with("attack"):
						tree.set("parameters/UpperSeek/seek_request", _attack_time(c))
			Combatant.State.STAGGER:
				upper_target = 1.0
			_:
				if c.is_guarding():
					upper_target = 1.0
					if _upper_mode != &"guard":
						_set_upper(&"guard")
	_upper_amount = move_toward(_upper_amount, upper_target, delta * 14.0)
	tree.set("parameters/UpperBlend/blend_amount", _upper_amount)

	# --- corps entier
	var full_target := 0.0
	var attacking := c.state in [Combatant.State.WINDUP, Combatant.State.STRIKE, Combatant.State.RECOVERY]
	_update_ik(delta, attacking and not _dead)
	if _dead:
		full_target = 1.0
	elif _attack_full_body and attacking and not is_dodging:
		full_target = 1.0
	elif is_dodging:
		if not _was_dodging:
			_start_dodge(body_basis, dodge_dir)
		full_target = 1.0
	elif not on_floor:
		if not _was_airborne:
			_set_full(&"jump", 1.0)
		full_target = 1.0
	_was_dodging = is_dodging
	_was_airborne = not on_floor
	_full_amount = move_toward(_full_amount, full_target, delta * (20.0 if (is_dodging or _attack_full_body) else 10.0))
	tree.set("parameters/FullBlend/blend_amount", _full_amount)


func _start_dodge(body_basis: Basis, dodge_dir: Vector3) -> void:
	var local := body_basis.inverse() * dodge_dir
	var mode := &"dodge_b"
	if absf(local.x) >= absf(local.z):
		mode = &"dodge_r" if local.x > 0.0 else &"dodge_l"
	var length := _library.get_animation(mode).length
	_set_full(mode, length / GameConfig.DODGE_DURATION)


## Position (s) dans l'animation d'attaque selon l'avancement du coup réel.
## préparation -> jusqu'au contact ; coup -> suite du geste ; récupération -> retour au repos.
func _attack_time(c: Combatant) -> float:
	var anim := _library.get_animation(ATTACK_ANIMS[c.attack_dir])
	var length := anim.length
	var start: float = anim.get_meta(&"start_time", 0.0)
	var peak: float = anim.get_meta(&"peak_time", length * 0.5)
	var finish: float = anim.get_meta(&"end_time", length)
	var contact := minf(peak + GameConfig.ANIM_CONTACT_OFFSET, finish)
	var follow := minf(contact + GameConfig.ANIM_FOLLOW_THROUGH, finish)
	var p := clampf(c.state_time / maxf(c.state_duration, 0.001), 0.0, 1.0)
	match c.state:
		Combatant.State.WINDUP:
			return lerpf(start, contact, pow(p, GameConfig.ANIM_WINDUP_CURVE))
		Combatant.State.STRIKE:
			return lerpf(contact, follow, p)
		_:
			return lerpf(follow, finish, p)
