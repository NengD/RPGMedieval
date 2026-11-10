class_name WeaponTrail
extends MeshInstance3D
## Traînée discrète de la lame pendant les coups : un ruban qui s'efface en TRAIL_LIFETIME secondes.
## Les points sont en repère MONDE (le nœud reste à l'origine du monde).

var _pts: Array = []    # [{base: Vector3, tip: Vector3, t: float}]
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _mesh
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat


## À appeler chaque image. `active` : on ajoute un point (pendant le coup) ; sinon la traînée finit de s'effacer.
func update(delta: float, active: bool, base: Vector3, tip: Vector3) -> void:
	if not GameConfig.TRAIL_ENABLED:
		_pts.clear()
		_mesh.clear_surfaces()
		return
	if active:
		_pts.append({"base": base, "tip": tip, "t": 0.0})
	for p in _pts:
		p["t"] += delta
	while not _pts.is_empty() and float(_pts[0]["t"]) > GameConfig.TRAIL_LIFETIME:
		_pts.pop_front()
	_mesh.clear_surfaces()
	if _pts.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _pts:
		var a := 0.45 * (1.0 - float(p["t"]) / GameConfig.TRAIL_LIFETIME)
		_mesh.surface_set_color(Color(0.92, 0.96, 1.0, a * 0.1))
		_mesh.surface_add_vertex(p["base"])
		_mesh.surface_set_color(Color(0.92, 0.96, 1.0, a))
		_mesh.surface_add_vertex(p["tip"])
	_mesh.surface_end()
