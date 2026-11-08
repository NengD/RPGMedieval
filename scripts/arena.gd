class_name Arena
extends Node3D
## Arène de test construite en code : sol, murs, piliers, plateforme + rampe.
## Surfaces en damier (repère de distance : 1 carreau = 1 mètre).

const _CHECKER_SHADER := """
shader_type spatial;
uniform vec4 color_a : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 color_b : source_color = vec4(0.4, 0.4, 0.4, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 p = floor(wpos + vec3(0.013, 0.017, 0.011));
	float c = mod(p.x + p.y + p.z, 2.0);
	ALBEDO = mix(color_a.rgb, color_b.rgb, c);
	ROUGHNESS = 0.9;
}
"""

var _shader: Shader
## Obstacles derrière lesquels on peut se cacher : [{pos: Vector3, radius: float}]
var cover_objects: Array = []


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = _CHECKER_SHADER
	_build_lighting()
	_build_geometry()


func _material(a: Color, b: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	return m


func _build_geometry() -> void:
	var h := GameConfig.ARENA_HALF_SIZE
	var wh := GameConfig.WALL_HEIGHT
	var floor_mat := _material(Color(0.42, 0.40, 0.36), Color(0.36, 0.34, 0.30))
	var wall_mat := _material(Color(0.55, 0.52, 0.48), Color(0.50, 0.47, 0.43))
	var obj_mat := _material(Color(0.62, 0.45, 0.35), Color(0.56, 0.40, 0.31))

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

	# Quelques caisses pour s'abriter plus tard
	_add_box("Caisse1", Vector3(1.2, 1.2, 1.2), Vector3(-4.5, 0.6, 2.0), obj_mat)
	_add_box("Caisse2", Vector3(1.2, 1.2, 1.2), Vector3(-5.8, 0.6, 2.4), obj_mat)
	cover_objects.append({"pos": Vector3(-4.5, 0, 2.0), "radius": 0.9})
	cover_objects.append({"pos": Vector3(-5.8, 0, 2.4), "radius": 0.9})


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


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.5, 0.75)
	sky_mat.sky_horizon_color = Color(0.7, 0.75, 0.8)
	sky_mat.ground_horizon_color = Color(0.6, 0.6, 0.6)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
