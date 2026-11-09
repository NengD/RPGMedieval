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

const MODEL := "res://assets/base/base_rig.tscn"          # squelette Mixamo du corps de base (Mannequin)
const BODY := "res://assets/base/body.glb"                 # corps en régions (tête, torse, bras…)
const LIBRARY := "res://assets/anims/hero_library.res"
const ATTACK_ANIMS := [&"attack_up", &"attack_right", &"attack_estoc", &"attack_left"]
const HIT_ANIMS := [&"hit_1", &"hit_2", &"hit_3"]
const FULL_STATES := [&"dodge_l", &"dodge_r", &"dodge_b", &"jump", &"death", &"attack_up", &"attack_right", &"attack_estoc", &"attack_left"]
const UPPER_STATES := [&"attack_up", &"attack_right", &"attack_estoc", &"attack_left", &"guard", &"hit_1", &"hit_2", &"hit_3", &"bow_draw", &"bow_release", &"xbow_aim", &"hit_left", &"hit_right", &"hit_gut", &"hit_front_light", &"hit_head"]

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
var ik_l: TwoBoneIK3D            # bras gauche : arc, arbalète, écu en parade
var ik_target_l: Node3D
var ik_pole_l: Node3D
var _ikl_amount := 0.0
var _grip_mode := 0              # 0 rien, 1 arc en main, 2 arbalète
var aim_point := Vector3.ZERO     # point visé par le réticule (monde), fourni par le Player
var aim_point_valid := false
var _aim_dir := Vector3.FORWARD   # direction de l'arme : de la prise vers le point visé
var _grip_r := Vector3.ZERO      # où doivent être les mains (monde)
var _grip_l := Vector3.ZERO
var _ik_pos := Vector3.ZERO      # position lissée de la main (repère du personnage)
var _ik_blade := Vector3.ZERO    # direction lissée de la lame
var _attack_full_body := false
var _weapon_amount := 0.0        # 0 = épée en main, 1 = arc en main (fondu de la locomotion)
var _bow_release_time := 0.0
var bow_holder: BoneAttachment3D
var _melee_node: Node3D          # nœud « Sword » : reçoit le modèle de l'arme de mêlée
var _shield_node: Node3D
var _bow_model_holder: Node3D
var _xbow_model_holder: Node3D
var _bow_top := Vector3(0.0, 0.52, 0.13)       # bouts de l'arc (repères Nock_Top / Nock_Bottom du modèle)
var _bow_bottom := Vector3(0.0, -0.52, 0.13)
var _ammo_length := 0.72
var _armor_holder: Node3D
var foot_ik: FootIK
var ragdoll_sim: PhysicalBoneSimulator3D
var _ragdoll_on := false
var _refs: Dictionary = {}          # jeu d'animations -> [vitesse de marche, vitesse de course] d'origine (m/s)
var _blend_pos := Vector2.ZERO      # position lissée dans les espaces de mélange de locomotion
var _look_head: LookAtModifier3D
var _look_spine: LookAtModifier3D
var _look_target: Node3D
var _look_amount := 0.0
var _look_timer := 0.0
var _look_point := Vector3.ZERO
var _look_has := false
var _main_weapon: WeaponData
var _grip_l_marker: Node3D          # repère Grip_L de l'arme de mêlée à deux mains
var _body_nodes: Dictionary = {}   # région -> MeshInstance3D du corps
var _tint_color := Color(1, 1, 1)
var _xbow_grip := 0.3             # écart entre les deux mains sur l'arbalète (repères Grip_R / Grip_L)
var _bow_in_hand := false
var _aim_corr := 0.0              # rotation du corps (rad) pour que l'arme pointe là où le héros vise
var _bow_hold := 0.0              # reste en main un instant après le tir
var xbow_holder: BoneAttachment3D
var _xbow_node: Node3D
var _xbow_amount := 0.0
var _xbow_bolt: Node3D
var bow_prop: Node3D
var _bow_strings: Array = []
var _bow_arrow: Node3D
var _bow_nock := Vector3(0.0, 0.0, 0.15)


func _ready() -> void:
	var scene: PackedScene = load(MODEL)
	model_root = scene.instantiate() as Node3D
	add_child(model_root)
	model_root.rotation.y = PI   # le modèle regarde vers +Z ; le jeu vers -Z
	for n in model_root.find_children("*", "AnimationPlayer", true, false):
		n.get_parent().remove_child(n)
		n.free()
	skeleton = model_root.find_children("*", "Skeleton3D", true, false)[0]
	# corps de base (régions) et support des pièces d'armure, rattachés au squelette par nom d'os
	_armor_holder = Node3D.new()
	_armor_holder.name = "Armor"
	skeleton.add_child(_armor_holder)
	for n in RigMesh.attach(skeleton, load(BODY), skeleton):
		_body_nodes[String(n.name).trim_prefix("corps_")] = n
	_library = load(LIBRARY)
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	model_root.add_child(anim_player)
	anim_player.add_animation_library("", _library)
	_compute_refs()   # vitesses d'origine des clips : elles placent les points de marche et de course dans les espaces de mélange
	_build_tree()
	_build_attachments()
	_build_ik()
	_build_bow_prop()
	_build_xbow_prop()
	_build_polish()


## Vitesses de déplacement d'origine des animations (mesurées au bake) : sert à caler la cadence sur la vitesse réelle.
func _compute_refs() -> void:
	var sets := {
		&"loco": [[&"walk_f", &"walk_b", &"strafe_r", &"strafe_l"], [&"run_f", &"run_b", &"strafe_r_run", &"strafe_l_run"]],
		&"bow": [[&"bow_walk_f", &"bow_walk_b", &"bow_walk_r", &"bow_walk_l"], [&"bow_run_f", &"bow_run_b", &"bow_run_r", &"bow_run_l"]],
		&"xbow": [[&"xbow_walk_f", &"xbow_walk_b", &"xbow_walk_r", &"xbow_walk_l"], [&"xbow_run_f", &"xbow_run_b", &"xbow_run_r", &"xbow_run_l"]],
	}
	for key in sets:
		var pair: Array = []
		for group in sets[key]:
			var total := 0.0
			var n := 0
			for anim_name in group:
				var a := _library.get_animation(anim_name)
				var s := float(a.get_meta(&"root_speed", 0.0)) if a != null else 0.0
				if s > 0.1:
					total += s
					n += 1
			pair.append(total / maxf(n, 1))
		_refs[key] = pair


## Cadence d'animation pour la vitesse réelle `h` (m/s) : la vitesse de déplacement d'origine du clip est celle du pas.
func stride_scale(set_key: StringName, h: float) -> float:
	if not GameConfig.ANIM_STRIDE_MATCH or not _refs.has(set_key):
		return clampf(h / 2.0, 1.0, 1.9)
	var pair: Array = _refs[set_key]
	var w := float(pair[0])
	var r := float(pair[1])
	var ref := lerpf(w, r, clampf((h - w) / maxf(r - w, 0.01), 0.0, 1.0))   # entre la vitesse de marche et de course des clips : cadence naturelle
	var scale := clampf(h / maxf(ref, 0.1), 0.6, GameConfig.ANIM_STRIDE_MAX)
	if GameConfig.ANIM_WEIGHT_AFFECTS_SPEED and combatant != null:
		var load_ratio := clampf(combatant.stats.carried_weight / maxf(combatant.stats.get_derived(&"charge_max"), 1.0), 0.0, 1.5)
		scale *= 1.0 - GameConfig.ANIM_WEIGHT_EFFECT * load_ratio
	return scale


## Pieds sur le terrain, tête qui suit la cible, ragdoll.
func _build_polish() -> void:
	foot_ik = FootIK.new()
	foot_ik.name = "FootIK"
	add_child(foot_ik)
	foot_ik.setup(self, skeleton)
	_look_target = Node3D.new()
	_look_target.name = "LookTarget"
	add_child(_look_target)
	_look_head = _make_look("mixamorig_Head", 70.0, 40.0)
	_look_spine = _make_look("mixamorig_Spine2", 35.0, 20.0)
	ragdoll_sim = Ragdoll.build(skeleton)


func _make_look(bone: String, yaw_limit: float, pitch_limit: float) -> LookAtModifier3D:
	var look := LookAtModifier3D.new()
	look.name = "Look_" + bone.trim_prefix("mixamorig_")
	skeleton.add_child(look)
	look.bone_name = bone
	look.target_node = look.get_path_to(_look_target)
	look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	look.primary_rotation_axis = Vector3.AXIS_Y
	look.use_secondary_rotation = true
	look.use_angle_limitation = true
	look.symmetry_limitation = true
	look.primary_limit_angle = deg_to_rad(yaw_limit)
	look.secondary_limit_angle = deg_to_rad(pitch_limit)
	look.duration = 0.2
	look.influence = 0.0
	return look


## Tête et buste suivent l'adversaire le plus proche devant nous, sinon le point visé (arc / arbalète).
func _update_look(delta: float) -> void:
	if not GameConfig.LOOK_AT_ENABLED or combatant == null:
		return
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = 0.1
		_look_has = false
		if not _dead and combatant.body != null:
			var best := GameConfig.LOOK_RANGE
			var fwd := -global_transform.basis.z
			for node in get_tree().get_nodes_in_group(&"combatants"):
				var other := node as Combatant
				if other == null or other == combatant or other.team == combatant.team or other.dead or other.body == null:
					continue
				var to := other.body.global_position - global_position
				var d := to.length()
				if d < best and absf(fwd.signed_angle_to(Vector3(to.x, 0.0, to.z), Vector3.UP)) < deg_to_rad(110.0):
					best = d
					_look_point = other.body.global_position + Vector3(0, 1.5, 0)
					_look_has = true
			if not _look_has and aim_point_valid:
				_look_point = aim_point
				_look_has = true
	var goal := 1.0 if (_look_has and not _dead and not _ragdoll_on) else 0.0
	_look_amount = move_toward(_look_amount, goal, delta * 3.0)
	_look_target.global_position = _look_point
	_look_head.influence = _look_amount * GameConfig.LOOK_HEAD_INFLUENCE
	_look_spine.influence = _look_amount * GameConfig.LOOK_SPINE_INFLUENCE


func bind(c: Combatant) -> void:
	combatant = c
	c.attack_started.connect(_on_attack_started)
	c.staggered.connect(_on_staggered)
	c.died.connect(_on_died)


## Remet le personnage debout, au repos.
func reset() -> void:
	_stop_ragdoll()
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
## Teinte les tissus (matériaux « teinte_* ») : l'ennemi est vêtu de rouge sombre.
func tint(color: Color) -> void:
	_tint_color = color
	_retint()


func _retint() -> void:
	for mi in _armor_holder.find_children("*", "MeshInstance3D", true, false):
		_tint_mesh(mi as MeshInstance3D, _variant_of(mi))


func _variant_of(mi: Node) -> Color:
	return mi.get_meta(&"couleur") if mi.has_meta(&"couleur") else Color(1, 1, 1)


func _tint_mesh(mi: MeshInstance3D, variant: Color) -> void:
	mi.set_meta(&"couleur", variant)
	for s in mi.mesh.get_surface_count():
		var base := mi.mesh.surface_get_material(s)
		var mat_name := String(base.resource_name) if base != null else ""
		if not ArmorMaterials.is_known(mat_name):
			continue
		var mat := ArmorMaterials.get_material(mat_name)
		if ArmorMaterials.is_tinted(mat_name):
			mat = mat.duplicate()
			mat.albedo_color = variant * _tint_color
		mi.set_surface_override_material(s, mat)


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


func show_bow(on: bool) -> void:
	bow_holder.visible = on


func show_crossbow(on: bool, loaded: bool) -> void:
	xbow_holder.visible = on
	_xbow_bolt.visible = loaded


## Le tir part : l'archer relâche la corde (animation de recul).
func play_bow_release() -> void:
	_bow_release_time = _library.get_animation(&"bow_release").length
	_set_upper(&"bow_release")


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

	# Les points de marche et de course sont placés à la VRAIE vitesse des clips (en multiples de WALK_SPEED) : le mélange suit la cadence naturelle
	var wk_l := float(_refs[&"loco"][0]) / walk
	var rk_l := float(_refs[&"loco"][1]) / walk
	var wk_b := float(_refs[&"bow"][0]) / walk
	var rk_b := float(_refs[&"bow"][1]) / walk
	var wk_x := float(_refs[&"xbow"][0]) / walk
	var rk_x := float(_refs[&"xbow"][1]) / walk
	# Locomotion : x = vers la droite, y = vers l'avant (en multiples de la vitesse de marche)
	var loco := AnimationNodeBlendSpace2D.new()
	loco.min_space = Vector2(-2.5, -2.5)
	loco.max_space = Vector2(2.5, 2.5)
	loco.add_blend_point(_anim_node(&"idle"), Vector2(0, 0), -1, &"idle")
	loco.add_blend_point(_anim_node(&"walk_f"), Vector2(0, wk_l), -1, &"walk_f")
	loco.add_blend_point(_anim_node(&"run_f"), Vector2(0, rk_l), -1, &"run_f")
	loco.add_blend_point(_anim_node(&"walk_b"), Vector2(0, -wk_l), -1, &"walk_b")
	loco.add_blend_point(_anim_node(&"run_b"), Vector2(0, -rk_l), -1, &"run_b")
	loco.add_blend_point(_anim_node(&"strafe_r"), Vector2(wk_l, 0), -1, &"strafe_r")
	loco.add_blend_point(_anim_node(&"strafe_r_run"), Vector2(rk_l, 0), -1, &"strafe_r_run")
	loco.add_blend_point(_anim_node(&"strafe_l"), Vector2(-wk_l, 0), -1, &"strafe_l")
	loco.add_blend_point(_anim_node(&"strafe_l_run"), Vector2(-rk_l, 0), -1, &"strafe_l_run")
	bt.add_node(&"Loco", loco, Vector2(0, 0))
	var loco_ts := AnimationNodeTimeScale.new()
	bt.add_node(&"LocoTS", loco_ts, Vector2(200, 0))
	bt.connect_node(&"LocoTS", 0, &"Loco")

	# Locomotion avec l'arc en main (même repère que ci-dessus)
	var loco_bow := AnimationNodeBlendSpace2D.new()
	loco_bow.min_space = Vector2(-2.5, -2.5)
	loco_bow.max_space = Vector2(2.5, 2.5)
	loco_bow.add_blend_point(_anim_node(&"bow_idle"), Vector2(0, 0), -1, &"bow_idle")
	loco_bow.add_blend_point(_anim_node(&"bow_walk_f"), Vector2(0, wk_b), -1, &"bow_walk_f")
	loco_bow.add_blend_point(_anim_node(&"bow_run_f"), Vector2(0, rk_b), -1, &"bow_run_f")
	loco_bow.add_blend_point(_anim_node(&"bow_walk_b"), Vector2(0, -wk_b), -1, &"bow_walk_b")
	loco_bow.add_blend_point(_anim_node(&"bow_run_b"), Vector2(0, -rk_b), -1, &"bow_run_b")
	loco_bow.add_blend_point(_anim_node(&"bow_walk_r"), Vector2(wk_b, 0), -1, &"bow_walk_r")
	loco_bow.add_blend_point(_anim_node(&"bow_run_r"), Vector2(rk_b, 0), -1, &"bow_run_r")
	loco_bow.add_blend_point(_anim_node(&"bow_walk_l"), Vector2(-wk_b, 0), -1, &"bow_walk_l")
	loco_bow.add_blend_point(_anim_node(&"bow_run_l"), Vector2(-rk_b, 0), -1, &"bow_run_l")
	bt.add_node(&"LocoBow", loco_bow, Vector2(0, -200))
	bt.add_node(&"LocoBowTS", AnimationNodeTimeScale.new(), Vector2(200, -200))
	bt.connect_node(&"LocoBowTS", 0, &"LocoBow")
	bt.add_node(&"WeaponBlend", AnimationNodeBlend2.new(), Vector2(400, -100))
	bt.connect_node(&"WeaponBlend", 0, &"LocoTS")
	bt.connect_node(&"WeaponBlend", 1, &"LocoBowTS")

	# Locomotion arbalète (pack fusil)
	var loco_x := AnimationNodeBlendSpace2D.new()
	loco_x.min_space = Vector2(-2.5, -2.5)
	loco_x.max_space = Vector2(2.5, 2.5)
	loco_x.add_blend_point(_anim_node(&"xbow_idle"), Vector2(0, 0), -1, &"xbow_idle")
	loco_x.add_blend_point(_anim_node(&"xbow_walk_f"), Vector2(0, wk_x), -1, &"xbow_walk_f")
	loco_x.add_blend_point(_anim_node(&"xbow_run_f"), Vector2(0, rk_x), -1, &"xbow_run_f")
	loco_x.add_blend_point(_anim_node(&"xbow_walk_b"), Vector2(0, -wk_x), -1, &"xbow_walk_b")
	loco_x.add_blend_point(_anim_node(&"xbow_run_b"), Vector2(0, -rk_x), -1, &"xbow_run_b")
	loco_x.add_blend_point(_anim_node(&"xbow_walk_r"), Vector2(wk_x, 0), -1, &"xbow_walk_r")
	loco_x.add_blend_point(_anim_node(&"xbow_run_r"), Vector2(rk_x, 0), -1, &"xbow_run_r")
	loco_x.add_blend_point(_anim_node(&"xbow_walk_l"), Vector2(-wk_x, 0), -1, &"xbow_walk_l")
	loco_x.add_blend_point(_anim_node(&"xbow_run_l"), Vector2(-rk_x, 0), -1, &"xbow_run_l")
	bt.add_node(&"LocoX", loco_x, Vector2(0, -400))
	bt.add_node(&"LocoXTS", AnimationNodeTimeScale.new(), Vector2(200, -400))
	bt.connect_node(&"LocoXTS", 0, &"LocoX")
	bt.add_node(&"WeaponBlend2", AnimationNodeBlend2.new(), Vector2(500, -200))
	bt.connect_node(&"WeaponBlend2", 0, &"WeaponBlend")
	bt.connect_node(&"WeaponBlend2", 1, &"LocoXTS")

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
	bt.connect_node(&"UpperBlend", 0, &"WeaponBlend2")
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
	ik_target_l = Node3D.new()
	ik_target_l.name = "IKTargetL"
	add_child(ik_target_l)
	ik_pole_l = Node3D.new()
	ik_pole_l.name = "IKPoleL"
	add_child(ik_pole_l)
	ik_l = TwoBoneIK3D.new()
	ik_l.name = "ArmIKLeft"
	skeleton.add_child(ik_l)
	ik_l.setting_count = 1
	ik_l.set_root_bone_name(0, "mixamorig_LeftArm")
	ik_l.set_middle_bone_name(0, "mixamorig_LeftForeArm")
	ik_l.set_end_bone_name(0, "mixamorig_LeftHand")
	ik_l.set_target_node(0, ik_l.get_path_to(ik_target_l))
	ik_l.set_pole_node(0, ik_l.get_path_to(ik_pole_l))
	ik_l.influence = 0.0
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


## Petit pas en avant visuel pendant l'attaque (le corps réel ne bouge pas : la portée du coup est inchangée).
func _update_lunge(attacking: bool) -> void:
	var lunge := 0.0
	if attacking and GameConfig.ATTACK_LUNGE > 0.0:
		var c := combatant
		var p := clampf(c.state_time / maxf(c.state_duration, 0.001), 0.0, 1.0)
		match c.state:
			Combatant.State.WINDUP: lunge = 0.75 * ease(p, 2.0)
			Combatant.State.STRIKE: lunge = lerpf(0.75, 1.0, p)
			Combatant.State.RECOVERY: lunge = 1.0 - ease(p, 0.6)
	if not _ragdoll_on:
		var pelvis_y := foot_ik.pelvis if foot_ik != null else 0.0
		var lift_y := foot_ik.lift if foot_ik != null else 0.0
		model_root.position = Vector3(0.0, pelvis_y + lift_y, -GameConfig.ATTACK_LUNGE * lunge)


func _update_ik(delta: float, attacking: bool) -> void:
	var has_shield := _shield_node.get_child_count() > 0
	var directed: bool = attacking and (combatant.attack_dir == Combatant.Dir.UP or combatant.attack_dir == Combatant.Dir.DOWN)
	var guarding_now: bool = not attacking and not _dead and combatant.is_guarding()
	var guarding: bool = guarding_now and not has_shield          # sans écu : l'épée fait la parade
	var shield_guard: bool = guarding_now and has_shield          # avec écu : c'est l'écu qui pare, l'épée reste basse
	var xbow_on := _grip_mode == 2
	var bow_on := _grip_mode == 1
	var active := directed or guarding
	_ik_amount = move_toward(_ik_amount, 1.0 if (active or xbow_on) else 0.0, delta * (12.0 if (directed or xbow_on) else GameConfig.IK_GUARD_BLEND))
	ik.influence = _ik_amount
	hand_aim.influence = 0.0 if xbow_on else _ik_amount
	if _ik_pos == Vector3.ZERO:
		_ik_pos = GameConfig.IK_REST
		_ik_blade = GameConfig.IK_REST_BLADE.normalized()
	if xbow_on:
		ik_target.global_position = _grip_r
		ik_pole.global_position = _grip_r + global_transform.basis.x * 0.6 + Vector3.DOWN * 0.5
	else:
		if directed:
			_ik_pos = _ik_hand_position(combatant)
			_ik_blade = _ik_blade_direction(combatant).normalized()
		else:
			# Parade : pose selon la direction de garde ; sinon retour au repos (en douceur)
			var goal_pos: Vector3 = GameConfig.IK_REST
			var goal_blade: Vector3 = GameConfig.IK_REST_BLADE
			if guarding:
				goal_pos = GameConfig.IK_GUARD_HAND[combatant.guard_dir]
				goal_blade = GameConfig.IK_GUARD_BLADE[combatant.guard_dir]
			var k := 1.0 - exp(-GameConfig.IK_GUARD_SPEED * delta)
			_ik_pos = _ik_pos.lerp(goal_pos, k)
			_ik_blade = _ik_blade.lerp(goal_blade.normalized(), k).normalized()
		if _ik_amount > 0.0 or active:
			ik_target.global_position = global_transform * _ik_pos
			ik_pole.global_position = global_transform * GameConfig.IK_POLE
			hand_aim.target_direction_world = global_transform.basis * _ik_blade
	# bras gauche
	var two_hand: bool = _grip_l_marker != null and not bow_on and not xbow_on and not _dead   # arme à deux mains : la main gauche tient le repère Grip_L
	var free_guard: bool = guarding and not two_hand           # parade sans écu : le bras libre reste bas
	var left_on := bow_on or xbow_on or shield_guard or free_guard or two_hand
	_ikl_amount = move_toward(_ikl_amount, 1.0 if left_on else 0.0, delta * 10.0)
	ik_l.influence = _ikl_amount
	if left_on:
		if two_hand:
			ik_target_l.global_position = _grip_l_marker.global_position
			ik_pole_l.global_position = _grip_l_marker.global_position - global_transform.basis.x * 0.6 + Vector3.DOWN * 0.4
		elif free_guard:
			ik_target_l.global_position = global_transform * GameConfig.FREE_GUARD_HAND
			ik_pole_l.global_position = global_transform * Vector3(-0.9, 0.9, 0.3)
		elif shield_guard:
			ik_target_l.global_position = global_transform * GameConfig.SHIELD_GUARD_HAND
			ik_pole_l.global_position = global_transform * Vector3(-0.9, 1.0, 0.3)
		else:
			ik_target_l.global_position = _grip_l
			ik_pole_l.global_position = _grip_l - global_transform.basis.x * 0.6 + Vector3.DOWN * 0.4


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
	sword.position = GameConfig.MELEE_GRIP_OFFSET
	_melee_node = sword
	# Bouclier au bras gauche
	shield_holder = BoneAttachment3D.new()
	shield_holder.name = "ShieldHolder"
	shield_holder.bone_name = "mixamorig_LeftForeArm"
	skeleton.add_child(shield_holder)
	_shield_node = Node3D.new()
	_shield_node.name = "Shield"
	shield_holder.add_child(_shield_node)
	_shield_node.top_level = true   # posé à chaque image devant l'avant-bras gauche (voir _place_props)


# ---------------------------------------------------------------- modèles d'armes

static func _free_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func _instance(scene: PackedScene) -> Node3D:
	return scene.instantiate() as Node3D if scene != null else null


## Met à jour armes ET armures d'après l'équipement (appelé à chaque changement).
func apply_equipment(eq: EquipmentComponent) -> void:
	apply_armor(eq)
	apply_weapons(eq)


## Pièces d'armure : on recrée leurs maillages (rattachés au squelette) et on cache les parties du corps recouvertes.
func apply_armor(eq: EquipmentComponent) -> void:
	_free_children(_armor_holder)
	var hidden := eq.hidden_regions()
	for r in _body_nodes:
		(_body_nodes[r] as MeshInstance3D).visible = not hidden.has(StringName(r))
	for piece in eq.pieces():
		if piece.model == null:
			continue
		var color := Color(1, 1, 1)
		var v := eq.get_variant(piece)
		if v >= 0 and v < piece.color_variants.size():
			color = piece.color_variants[v]
		for mi in RigMesh.attach(skeleton, piece.model, _armor_holder):
			_tint_mesh(mi, color)


## Met à jour tous les modèles d'armes d'après ce que le personnage porte.
func apply_weapons(eq: EquipmentComponent) -> void:
	var main := eq.get_weapon(&"main_hand")
	_main_weapon = main
	_grip_l_marker = null
	_free_children(_melee_node)
	var melee_scene: PackedScene = main.model if main != null else load("res://assets/weapons/arme_epee_longue.glb")
	var melee := _instance(melee_scene)
	if melee != null:
		if main != null:
			melee.rotation_degrees = main.held_rotation_deg
		_melee_node.add_child(melee)
		if main != null and main.is_two_handed():
			_grip_l_marker = _marker(melee, "Grip_L")
	_free_children(_shield_node)
	var off := eq.get_weapon(&"off_hand")
	var shield := _instance(off.model) if off != null else null
	if shield != null:
		_shield_node.add_child(shield)
	_set_bow_model(eq.get_weapon(&"bow"))
	_set_xbow_model(eq.get_weapon(&"crossbow"))


func _marker(model: Node, marker_name: String) -> Node3D:
	return model.find_child(marker_name, true, false) as Node3D


func _set_bow_model(w: WeaponData) -> void:
	_free_children(_bow_model_holder)
	_free_children(_bow_arrow)
	if w == null:
		return
	var model := _instance(w.model)
	if model != null:
		_bow_model_holder.add_child(model)
		var top := _marker(model, "Nock_Top")
		var bottom := _marker(model, "Nock_Bottom")
		if top != null and bottom != null:
			_bow_top = top.position
			_bow_bottom = bottom.position
	if w.ammo != null:
		_ammo_length = w.ammo.length
		var arrow := _instance(w.ammo.model)
		if arrow != null:
			_bow_arrow.add_child(arrow)
	_bow_nock = Vector3(0.0, 0.0, _bow_top.z)


func _set_xbow_model(w: WeaponData) -> void:
	_free_children(_xbow_model_holder)
	_free_children(_xbow_bolt)
	if w == null:
		return
	var model := _instance(w.model)
	if model != null:
		_xbow_model_holder.add_child(model)
		var muzzle := _marker(model, "Muzzle")
		if muzzle != null:
			_xbow_bolt.position = muzzle.position
		var gl := _marker(model, "Grip_L")
		var gr := _marker(model, "Grip_R")
		if gl != null and gr != null:
			_xbow_grip = gl.position.distance_to(gr.position)
		var nl := _marker(model, "Nock_Left")
		var nr := _marker(model, "Nock_Right")
		var rest := _marker(model, "Bolt_Rest")
		if nl != null and nr != null and rest != null:
			var cord_mat := StandardMaterial3D.new()
			cord_mat.albedo_color = Color(0.85, 0.8, 0.65)
			for end in [nl.position, nr.position]:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.006, 0.006, 1.0)
				bm.material = cord_mat
				mi.mesh = bm
				_xbow_model_holder.add_child(mi)
				_set_segment(mi, end, rest.position)
	if w.ammo != null:
		var bolt := _instance(w.ammo.model)
		if bolt != null:
			_xbow_bolt.add_child(bolt)


func _build_bow_prop() -> void:
	bow_holder = BoneAttachment3D.new()
	bow_holder.name = "BowHolder"
	bow_holder.bone_name = "mixamorig_LeftHand"
	skeleton.add_child(bow_holder)
	bow_prop = Node3D.new()
	bow_prop.name = "Bow"
	bow_holder.add_child(bow_prop)
	bow_prop.top_level = true   # placé chaque image à partir des mains (voir _place_props)
	_bow_model_holder = Node3D.new()
	bow_prop.add_child(_bow_model_holder)
	for i in 2:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.008, 0.008, 1.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.85, 0.7)
		bm.material = mat
		mi.mesh = bm
		bow_prop.add_child(mi)
		_bow_strings.append(mi)
	_bow_arrow = Node3D.new()
	bow_prop.add_child(_bow_arrow)
	_bow_arrow.visible = false
	bow_holder.visible = false


func _build_xbow_prop() -> void:
	xbow_holder = BoneAttachment3D.new()
	xbow_holder.name = "CrossbowHolder"
	xbow_holder.bone_name = "mixamorig_RightHand"
	skeleton.add_child(xbow_holder)
	var x := Node3D.new()
	x.name = "Crossbow"
	xbow_holder.add_child(x)
	x.top_level = true
	_xbow_node = x
	_xbow_model_holder = Node3D.new()
	x.add_child(_xbow_model_holder)
	_xbow_bolt = Node3D.new()
	x.add_child(_xbow_bolt)
	xbow_holder.visible = false


func _add_part(parent: Node3D, size: Vector3, pos: Vector3, euler_deg: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation = Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z))
	parent.add_child(mi)


func _set_segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.9 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d.normalized(), up) * Basis.from_scale(Vector3(1, 1, length)), (a + b) * 0.5)


## La corde suit la main droite ; la flèche est encochée tant qu'on bande.
## L'arc et l'arbalète sont placés à partir de la position réelle des mains (et pas de l'orientation de l'os,
## qui varie selon l'animation) : l'arc est vertical dans la main gauche, la flèche part droit devant ;
## l'arbalète suit la ligne main droite -> main gauche.
func _hand_world(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _place_props() -> void:
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := global_transform.basis.x.normalized()
	if _shield_node.get_child_count() > 0:
		# L'écu est posé devant l'avant-bras gauche, face vers l'avant, pointe vers le bas : toujours « au niveau du bras »
		var mid := (_hand_world("mixamorig_LeftForeArm") + _hand_world("mixamorig_LeftHand")) * 0.5
		_shield_node.global_transform = Transform3D(Basis.looking_at(-fwd, Vector3.UP), mid + fwd * GameConfig.SHIELD_FORWARD - right * GameConfig.SHIELD_SIDE)
	if bow_holder.visible:
		if _bow_in_hand:
			# Arc : la main gauche (placée par cinématique inverse) tient la poignée, bras tendu vers l'avant
			bow_prop.global_transform = Transform3D(Basis.looking_at(_aim_dir, Vector3.UP), _grip_l)
		else:
			# Arc porté dans le dos (en diagonale) : il ne traverse plus le corps quand on ne vise pas
			var long_axis := (right * GameConfig.BOW_BACK_TILT + Vector3.UP).normalized()
			var z_axis := (fwd - long_axis * fwd.dot(long_axis)).normalized()   # côté corde vers le dos
			var x_axis := long_axis.cross(z_axis).normalized()
			var spine := _hand_world("mixamorig_Spine2")
			bow_prop.global_transform = Transform3D(Basis(x_axis, long_axis, z_axis), spine - fwd * GameConfig.BOW_BACK_DEPTH + right * GameConfig.BOW_BACK_SIDE)
	if xbow_holder.visible:
		# Arbalète : poignée arrière (Grip_R) dans la main droite, avant du fût (Grip_L) dans la gauche (cinématique inverse des deux bras)
		_xbow_node.global_transform = Transform3D(Basis.looking_at(_aim_dir, Vector3.UP), _grip_r)


## Points où doivent se trouver les mains, d'après les épaules et la direction visée (indépendant de l'animation).
func _compute_grips() -> void:
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := global_transform.basis.x.normalized()
	var sh_r := _hand_world("mixamorig_RightArm")
	var sh_l := _hand_world("mixamorig_LeftArm")
	_aim_dir = fwd
	if _grip_mode == 2:
		_grip_r = sh_r + fwd * GameConfig.XBOW_GRIP_R_FWD + Vector3.UP * -GameConfig.XBOW_GRIP_R_DOWN + right * GameConfig.XBOW_GRIP_R_SIDE
		_aim_dir = _dir_to_aim(_grip_r, fwd)
		_grip_l = _grip_r + _aim_dir * _xbow_grip
	elif _grip_mode == 1:
		_grip_l = sh_l + right * GameConfig.BOW_ARM_SIDE + fwd * GameConfig.BOW_ARM_REACH
		_aim_dir = _dir_to_aim(_grip_l, fwd)


## L'arme pointe vers le point visé par le réticule (sinon droit devant).
func _dir_to_aim(from: Vector3, fallback: Vector3) -> Vector3:
	if aim_point_valid and from.distance_to(aim_point) > 2.0:
		return (aim_point - from).normalized()
	return fallback


## Les postures d'arc et de fusil sont de profil : on tourne le corps du personnage (visuel seulement, le
## collisionneur ne bouge pas) de l'angle mesuré par tools/aim_yaw.gd pour que le tronc fasse face à la cible.
func _update_aim_yaw(delta: float, mode: int) -> void:
	var goal := 0.0
	if mode == 1:
		goal = GameConfig.AIM_YAW_BOW
	elif mode == 2:
		goal = GameConfig.AIM_YAW_XBOW
	_aim_corr = move_toward(_aim_corr, goal, delta * 5.0)
	model_root.rotation.y = PI + _aim_corr


func _update_bow_prop(delta: float, drawing: bool, _tension: float, aiming := false, weapon_kind_now := 0) -> void:
	# En main tant qu'on vise, bande ou vient de tirer ; sinon dans le dos
	if drawing or aiming or _bow_release_time > 0.0:
		_bow_hold = 0.5
	else:
		_bow_hold = maxf(0.0, _bow_hold - delta)
	_bow_in_hand = _bow_hold > 0.0
	_grip_mode = 2 if (weapon_kind_now == 2 and xbow_holder.visible) else (1 if (weapon_kind_now == 1 and _bow_in_hand) else 0)
	_update_aim_yaw(delta, _grip_mode)
	_compute_grips()
	_place_props()
	if not bow_holder.visible:
		return
	var rest := Vector3(0.0, 0.0, _bow_top.z)
	var goal := rest
	if drawing:
		var right_hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_RightHand")).origin
		goal = bow_prop.to_local(right_hand)
		goal.z = maxf(goal.z, _bow_top.z)
		goal.x = clampf(goal.x, -0.1, 0.1)
		goal.y = clampf(goal.y, -0.15, 0.15)
	_bow_nock = _bow_nock.lerp(goal, 1.0 - exp(-(30.0 if drawing else 40.0) * delta))
	_set_segment(_bow_strings[0], _bow_top, _bow_nock)
	_set_segment(_bow_strings[1], _bow_bottom, _bow_nock)
	_bow_arrow.visible = drawing
	_bow_arrow.position = _bow_nock + Vector3(0, 0, -_ammo_length)


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


func _on_staggered(perfect: bool) -> void:
	if _dead:
		return
	_set_upper(_pick_hit_anim(perfect))


## Réaction selon d'où vient le coup (gauche, droite, face) et sa force ; tir à la tête = secousse de la tête.
func _pick_hit_anim(perfect: bool) -> StringName:
	var c := combatant
	if perfect or c.last_attacker == null or c.last_attacker.body == null:
		return HIT_ANIMS[randi() % HIT_ANIMS.size()]
	if c.last_hit_head:
		return &"hit_head"
	var local := global_basis.inverse() * (c.last_attacker.body.global_position - global_position)
	if local.x > 0.7:
		return &"hit_right"
	if local.x < -0.7:
		return &"hit_left"
	return &"hit_gut" if c.last_hit_amount >= GameConfig.KNOCKBACK_BIG_HIT else &"hit_front_light"



func _on_died() -> void:
	_dead = true
	if GameConfig.RAGDOLL_ON_DEATH and ragdoll_sim != null:
		var push := Vector3.ZERO
		if combatant.last_attacker != null and combatant.last_attacker.body != null and combatant.body != null:
			push = (combatant.body.global_position - combatant.last_attacker.body.global_position)
			push.y = 0.0
			push = push.normalized() * GameConfig.RAGDOLL_PUSH
		_start_ragdoll(push)
		return
	_full_mode = &"death"
	tree.set("parameters/Full/transition_request", "death")
	tree.set("parameters/FullTS/scale", 1.0)


func _start_ragdoll(push: Vector3) -> void:
	_ragdoll_on = true
	tree.active = false
	Ragdoll.start(ragdoll_sim, push)


func _stop_ragdoll() -> void:
	if _ragdoll_on:
		_ragdoll_on = false
		Ragdoll.stop(ragdoll_sim)
		skeleton.reset_bone_poses()
		if tree != null:
			tree.active = true
	if model_root != null:
		model_root.position = Vector3.ZERO


func is_ragdoll() -> bool:
	return _ragdoll_on


func _set_upper(mode: StringName) -> void:
	_upper_mode = mode
	tree.set("parameters/Upper/transition_request", str(mode))
	var scrubbed := str(mode).begins_with("attack") or mode == &"bow_draw"
	tree.set("parameters/UpperTS/scale", 0.0 if scrubbed else 1.0)


func _set_full(mode: StringName, time_scale: float) -> void:
	_full_mode = mode
	tree.set("parameters/Full/transition_request", str(mode))
	tree.set("parameters/FullTS/scale", time_scale)


# ---------------------------------------------------------------- chaque image

## velocity : vitesse du monde ; body_basis : orientation du corps ; dodge_dir : direction du pas de côté.
func drive(delta: float, velocity: Vector3, body_basis: Basis, on_floor: bool, is_dodging: bool, dodge_dir: Vector3, weapon_kind := 0, bow_tension := 0.0, bow_drawing := false, ranged_aiming := false) -> void:
	if combatant == null or tree == null:
		return
	var c := combatant
	var local := body_basis.inverse() * velocity
	var horizontal := Vector2(velocity.x, velocity.z).length()
	_last_speed = horizontal
	var blend_goal := Vector2(local.x, -local.z) / GameConfig.WALK_SPEED
	_blend_pos = _blend_pos.lerp(blend_goal, 1.0 - exp(-GameConfig.ANIM_LOCO_SMOOTH * delta))   # départs, arrêts et demi-tours plus doux
	tree.set("parameters/Loco/blend_position", _blend_pos)
	tree.set("parameters/LocoTS/scale", stride_scale(&"loco", horizontal))
	tree.set("parameters/LocoBow/blend_position", _blend_pos)
	tree.set("parameters/LocoBowTS/scale", stride_scale(&"bow", horizontal))
	tree.set("parameters/LocoX/blend_position", _blend_pos)
	tree.set("parameters/LocoXTS/scale", stride_scale(&"xbow", horizontal))
	_xbow_amount = move_toward(_xbow_amount, 1.0 if weapon_kind == 2 else 0.0, delta * 8.0)
	tree.set("parameters/WeaponBlend2/blend_amount", _xbow_amount)
	_weapon_amount = move_toward(_weapon_amount, 1.0 if weapon_kind == 1 else 0.0, delta * 8.0)
	tree.set("parameters/WeaponBlend/blend_amount", _weapon_amount)
	_bow_release_time = maxf(0.0, _bow_release_time - delta)

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
				elif weapon_kind == 1 and bow_drawing:
					# Arc : l'animation de bandage suit la tension de la corde
					upper_target = 1.0
					if _upper_mode != &"bow_draw":
						_set_upper(&"bow_draw")
					var draw_len := _library.get_animation(&"bow_draw").length
					tree.set("parameters/UpperSeek/seek_request", clampf(bow_tension, 0.0, 1.0) * draw_len * 0.995)
				elif weapon_kind == 2 and ranged_aiming:
					upper_target = 1.0   # arbalète épaulée
					if _upper_mode != &"xbow_aim":
						_set_upper(&"xbow_aim")
				elif _bow_release_time > 0.0:
					upper_target = 1.0   # relâchement de la corde
	_upper_amount = move_toward(_upper_amount, upper_target, delta * 14.0)
	_update_bow_prop(delta, bow_drawing and weapon_kind == 1, bow_tension, ranged_aiming and weapon_kind == 1, weapon_kind)
	tree.set("parameters/UpperBlend/blend_amount", _upper_amount)

	# --- corps entier
	var full_target := 0.0
	var attacking := c.state in [Combatant.State.WINDUP, Combatant.State.STRIKE, Combatant.State.RECOVERY]
	_update_ik(delta, attacking and not _dead)
	if foot_ik != null:
		foot_ik.update(delta, on_floor and not is_dodging and not _dead and not _ragdoll_on)
	_update_look(delta)
	_update_lunge(attacking and not _dead)
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
