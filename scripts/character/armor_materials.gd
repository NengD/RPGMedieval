class_name ArmorMaterials
extends RefCounted
## Matériaux réalistes des pièces d'armure et d'habit, choisis d'après le NOM du matériau dans le .glb (voir tools/blender/make_armor.py).
##  - acier_plaques : vrai acier poli (métal, reflets du ciel HDRI, rayures fines générées, bords plus brillants par effet de bordure)
##  - mailles      : anneaux fins (bruit cellulaire en relief) qui scintillent
##  - cuir         : texture Poly Haven « brown_leather »
##  - teinte_lin / teinte_gambison / teinte_tabard : tissus, texture Poly Haven « rough_linen » / « poly_wool_herringbone », teinte réglable
## Projection triplanaire en repère de l'OBJET : la texture suit le corps quand il s'anime.

const TEX := "res://assets/textures/"
static var _cache: Dictionary = {}
static var _noise_tex: Dictionary = {}


static func is_known(mat_name: String) -> bool:
	return mat_name in ["acier_plaques", "mailles", "cuir", "teinte_lin", "teinte_gambison", "teinte_tabard"]


static func is_tinted(mat_name: String) -> bool:
	return mat_name.begins_with("teinte_")


## Matériau de base (partagé). Pour une teinte, dupliquer puis changer albedo_color.
static func get_material(mat_name: String) -> StandardMaterial3D:
	if _cache.has(mat_name):
		return _cache[mat_name]
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match mat_name:
		"acier_plaques":
			m.albedo_color = Color(0.46, 0.46, 0.46)
			m.metallic = 0.95
			m.metallic_specular = 0.7
			m.roughness = 0.48
			m.roughness_texture = _noise("scratch", 0.045, 6.0, true, false)   # rugosité variable : usure légère
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.normal_enabled = true
			m.normal_texture = _noise("scratch", 0.045, 6.0, true, true)
			m.normal_scale = 0.6
			m.uv1_scale = Vector3.ONE * 1.3
			m.rim_enabled = true                  # bords plus brillants
			m.rim = 0.25
			m.rim_tint = 0.6
		"mailles":
			m.albedo_color = Color(0.55, 0.57, 0.61)
			m.metallic = 1.0
			m.roughness = 0.42
			m.roughness_texture = _noise("rings", 0.5, 1.0, false, false)
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.normal_enabled = true
			m.normal_texture = _noise("rings", 0.5, 1.0, false, true)
			m.normal_scale = 1.6
			m.uv1_scale = Vector3.ONE * 9.0       # anneaux d'environ 1 cm
			m.rim_enabled = true
			m.rim = 0.5                           # scintillement sur les bords des plis
			m.rim_tint = 0.3
		"cuir":
			_set_pbr(m, "cuir", Vector3.ONE * 2.2)
			m.albedo_color = Color(0.85, 0.8, 0.75)
		"teinte_lin":
			_set_pbr(m, "lin", Vector3.ONE * 3.0)
		"teinte_gambison":
			_set_pbr(m, "lin", Vector3.ONE * 5.0)
			m.normal_scale = 1.8                  # grain plus marqué : étoffe matelassée
		"teinte_tabard":
			_set_pbr(m, "laine", Vector3.ONE * 2.0)
	_cache[mat_name] = m
	return m


static func _set_pbr(m: StandardMaterial3D, folder: String, uv_scale: Vector3) -> void:
	m.albedo_texture = load(TEX + folder + "/diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load(TEX + folder + "/nor_gl.jpg")
	var arm: Texture2D = load(TEX + folder + "/arm.jpg")
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.uv1_scale = uv_scale


## Textures générées une fois : rayures fines (acier) ou anneaux (mailles). `as_normal` : carte de normales au lieu de niveaux de gris.
static func _noise(kind: String, freq: float, stretch: float, brushed: bool, as_normal: bool) -> Texture2D:
	var key := "%s_%s" % [kind, as_normal]
	if _noise_tex.has(key):
		return _noise_tex[key]
	var n := FastNoiseLite.new()
	n.seed = 7 if kind == "scratch" else 11
	if kind == "scratch":
		n.noise_type = FastNoiseLite.TYPE_PERLIN
		n.frequency = freq
		n.fractal_octaves = 3
	else:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		n.frequency = freq * 0.1
	var img: Image
	if brushed:
		img = n.get_seamless_image(512, 16, false, true, 0.1, false)   # très étiré en hauteur : stries horizontales (brossé)
		img.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	else:
		img = n.get_seamless_image(256, 256, false, true, 0.1, false)
	if as_normal:
		img.bump_map_to_normal_map(2.0 if kind == "scratch" else 6.0)
	else:
		img.convert(Image.FORMAT_L8)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_noise_tex[key] = tex
	return tex
