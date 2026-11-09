class_name Arena
extends Node3D
## Arène de test construite en code : sol, murs, piliers, plateforme + rampe, accessoires (caisses, tonneaux, râtelier,
## poteaux d'entraînement), ciel HDRI et lumière. Textures PBR Poly Haven (assets/textures), accessoires modélisés dans
## Blender (assets/props). Les collisions et les noms des objets sont ceux de l'ancienne arène (la jouabilité ne change pas).

const TEX := "res://assets/textures/"
const PROPS := "res://assets/props/"
const SKY_HDR := "res://assets/sky/ciel_nuageux_1k.hdr"

## Obstacles derrière lesquels on peut se cacher : [{pos: Vector3, radius: float}]
var cover_objects: Array = []
var sun: DirectionalLight3D
var environment: Environment
var world_env: WorldEnvironment

var _materials: Dictionary = {}


func _ready() -> void:
	_build_lighting()
	_build_geometry()
	_build_props()
	QualitySettings.apply(QualitySettings.load_saved(), environment, sun, get_viewport())


# ---------------------------------------------------------------- matériaux

## Matériau PBR en projection triplanaire (la texture se répète au mètre, quelle que soit la forme).
func _pbr(folder: String, tile_m: float, tint := Color(1, 1, 1)) -> StandardMaterial3D:
	var key := "%s_%s" % [folder, tile_m]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = folder
	m.albedo_texture = load(TEX + folder + "/diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX + folder + "/nor_gl.jpg")
	var arm: Texture2D = load(TEX + folder + "/arm.jpg")   # R = occlusion, G = rugosité, B = métal
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = arm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = m
	return m


func _iron() -> StandardMaterial3D:
	if not _materials.has("fer"):
		var m := StandardMaterial3D.new()
		m.resource_name = "fer"
		m.albedo_color = Color(0.2, 0.2, 0.22)
		m.metallic = 0.85
		m.roughness = 0.5
		_materials["fer"] = m
	return _materials["fer"]


func _straw() -> StandardMaterial3D:
	if not _materials.has("paille"):
		var m := StandardMaterial3D.new()
		m.resource_name = "paille"
		m.albedo_color = Color(0.72, 0.6, 0.3)
		m.roughness = 0.95
		_materials["paille"] = m
	return _materials["paille"]


# ---------------------------------------------------------------- géométrie

func _build_geometry() -> void:
	var h := GameConfig.ARENA_HALF_SIZE
	var wh := GameConfig.WALL_HEIGHT
	var floor_mat := _pbr("pave", 2.6)
	var wall_mat := _pbr("pierre", 3.0, Color(0.9, 0.88, 0.85))
	var obj_mat := _pbr("pierre", 2.2, Color(0.8, 0.76, 0.72))

	# Sol
	_add_box("Sol", Vector3(h * 2.0, 1.0, h * 2.0), Vector3(0, -0.5, 0), floor_mat)
	# Murs (épaisseur 1 m, face intérieure à ±h)
	_add_box("MurNord", Vector3(h * 2.0 + 2.0, wh, 1.0), Vector3(0, wh * 0.5, -h - 0.5), wall_mat)
	_add_box("MurSud", Vector3(h * 2.0 + 2.0, wh, 1.0), Vector3(0, wh * 0.5, h + 0.5), wall_mat)
	_add_box("MurEst", Vector3(1.0, wh, h * 2.0), Vector3(h + 0.5, wh * 0.5, 0), wall_mat)
	_add_box("MurOuest", Vector3(1.0, wh, h * 2.0), Vector3(-h - 0.5, wh * 0.5, 0), wall_mat)

	# Piliers
	for p in [Vector2(-7, -3), Vector2(7, -3), Vector2(-7, 5), Vector2(7, 5)]:
		_add_pillar(Vector3(p.x, 0, p.y), 0.7, 5.0, obj_mat)
		cover_objects.append({"pos": Vector3(p.x, 0, p.y), "radius": 0.7})

	# Plateforme + rampe (dans le coin nord-est)
	var ph := GameConfig.PLATFORM_HEIGHT
	var plat_size := Vector3(6.0, ph, 6.0)
	var plat_center := Vector3(9.0, ph * 0.5, -11.5)
	_add_box("Plateforme", plat_size, plat_center, obj_mat)
	var run := ph / tan(deg_to_rad(GameConfig.RAMP_ANGLE_DEG))
	_add_ramp(Vector3(9.0, 0.0, -8.5 + run), ph, 4.0, obj_mat)   # le haut touche le bord de la plateforme


## Rampe qui monte vers -Z. `bottom` = point au sol où elle commence.
func _add_ramp(bottom: Vector3, height: float, width: float, mat: Material) -> void:
	var angle := deg_to_rad(GameConfig.RAMP_ANGLE_DEG)
	var run := height / tan(angle)
	var length := height / sin(angle)
	var thickness := 0.4
	var d := Vector3(0, height, -run).normalized()          # direction de montée
	var zb := -d                                             # axe local Z (pointe vers le bas de la pente)
	var xb := Vector3.RIGHT
	var yb := zb.cross(xb)                                   # normale vers le haut
	var mid := bottom + Vector3(0, height * 0.5, -run * 0.5)
	var center := mid - yb * (thickness * 0.5)
	_add_box("Rampe", Vector3(width, thickness, length), center, mat, Basis(xb, yb, zb))


func _add_box(box_name: String, size: Vector3, pos: Vector3, mat: Material, basis: Basis = Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.transform = Transform3D(basis, pos)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body


func _add_pillar(pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "Pilier"
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos + Vector3(0, height * 0.5, 0)
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.material = mat
	mesh.mesh = cm
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	add_child(body)


# ---------------------------------------------------------------- accessoires

## Un accessoire : modèle Blender + collision simple. shape = "box" (taille collision) ou "cyl" (rayon, hauteur).
func _add_prop(prop_name: String, model: String, pos: Vector3, yaw_deg: float, shape_size: Vector3, cyl := false, cover_radius := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = prop_name
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees.y = yaw_deg
	var inst := (load(PROPS + model + ".glb") as PackedScene).instantiate()
	body.add_child(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var node := mi as MeshInstance3D
		for s in node.mesh.get_surface_count():
			var src := node.mesh.surface_get_material(s)
			match String(src.resource_name) if src != null else "":
				"bois": node.set_surface_override_material(s, _pbr("bois", 1.4))
				"fer": node.set_surface_override_material(s, _iron())
				"paille": node.set_surface_override_material(s, _straw())
	var col := CollisionShape3D.new()
	if cyl:
		var c := CylinderShape3D.new()
		c.radius = shape_size.x
		c.height = shape_size.y
		col.shape = c
	else:
		var b := BoxShape3D.new()
		b.size = shape_size
		col.shape = b
	col.position.y = shape_size.y * 0.5 if cyl else shape_size.y * 0.5
	body.add_child(col)
	add_child(body)
	if cover_radius > 0.0:
		cover_objects.append({"pos": Vector3(pos.x, 0, pos.z), "radius": cover_radius})
	return body


func _build_props() -> void:
	# Caisses d'origine (mêmes positions et mêmes collisions qu'avant)
	_add_prop("Caisse1", "caisse", Vector3(-4.5, 0.0, 2.0), 0.0, Vector3(1.2, 1.2, 1.2), false, 0.9)
	_add_prop("Caisse2", "caisse", Vector3(-5.8, 0.0, 2.4), 15.0, Vector3(1.2, 1.2, 1.2), false, 0.9)
	# Pile de caisses dans un coin
	_add_prop("Caisse3", "caisse", Vector3(11.5, 0.0, 9.5), 8.0, Vector3(1.2, 1.2, 1.2), false, 0.9)
	_add_prop("Caisse4", "caisse_petite", Vector3(11.4, 1.2, 9.5), -12.0, Vector3(0.8, 0.8, 0.8))
	_add_prop("Caisse5", "caisse_petite", Vector3(10.3, 0.0, 10.4), 30.0, Vector3(0.8, 0.8, 0.8))
	# Tonneaux (trop bas pour cacher quelqu'un : pas d'abri) ; poteaux trop fins aussi
	_add_prop("Tonneau1", "tonneau", Vector3(-11.5, 0.0, 10.0), 0.0, Vector3(0.47, 1.0, 0.47), true)
	_add_prop("Tonneau2", "tonneau", Vector3(-12.6, 0.0, 9.2), 0.0, Vector3(0.47, 1.0, 0.47), true)
	_add_prop("Tonneau3", "tonneau", Vector3(12.6, 0.0, -1.5), 0.0, Vector3(0.47, 1.0, 0.47), true)
	# Râtelier d'armes le long du mur ouest (face vers l'intérieur)
	_add_prop("Ratelier", "ratelier", Vector3(-14.3, 0.0, -1.0), 90.0, Vector3(0.5, 1.7, 2.0))
	# Poteaux d'entraînement
	_add_prop("Poteau1", "poteau_entrainement", Vector3(4.0, 0.0, -10.0), 0.0, Vector3(0.25, 1.9, 0.25), true)
	_add_prop("Poteau2", "poteau_entrainement", Vector3(-3.0, 0.0, -12.0), 20.0, Vector3(0.25, 1.9, 0.25), true)


# ---------------------------------------------------------------- lumière et ciel

func _build_lighting() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_blur = 1.2
	sun.directional_shadow_blend_splits = true
	add_child(sun)

	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load(SKY_HDR)
	var sky := Sky.new()
	sky.sky_material = pano
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 6.0
	environment.fog_light_color = Color(0.72, 0.78, 0.86)
	environment.fog_density = 0.0045
	environment.fog_sky_affect = 0.25
	environment.fog_aerial_perspective = 0.2
	environment.glow_intensity = 0.25
	environment.glow_bloom = 0.0
	world_env = WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
