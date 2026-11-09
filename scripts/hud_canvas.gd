class_name HudCanvas
extends Control
## Dessine : réticule, barres de vie et d'endurance.

var guarding := false
var health_ratio := 1.0
var stamina_ratio := 1.0
var exhausted := false
var weapon_kind := 0         # 0 épée, 1 arc, 2 arbalète
var reticle_radius := 20.0
var drawing := false
var aiming := false
var aim_distance := -1.0
var drop_offset := 0.0       # décalage vertical (pixels) du repère de chute
var tension := 0.0
var reload_ratio := 1.0      # arbalète : 0 = vient de tirer, 1 = prête
var enemy_visible := false
var enemy_health_ratio := 1.0
var enemy_stamina_ratio := 1.0
var enemy_exhausted := false
var enemy_title := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # ne jamais bloquer la souris
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func dir_vector(d: int) -> Vector2:
	match d:
		Combatant.Dir.UP: return Vector2(0, -1)
		Combatant.Dir.RIGHT: return Vector2(1, 0)
		Combatant.Dir.DOWN: return Vector2(0, 1)
	return Vector2(-1, 0)


func _draw() -> void:
	var center := size * 0.5
	if weapon_kind != 0:
		_draw_reticle(center)

	if enemy_visible:
		var w := 380.0
		var ex := size.x - w - 24.0   # en haut à droite
		_bar(Vector2(ex, 30.0), Vector2(w, 14), enemy_health_ratio, Color(0.75, 0.2, 0.2))
		_bar(Vector2(ex, 50.0), Vector2(w, 7), enemy_stamina_ratio, Color(1.0, 0.55, 0.1) if enemy_exhausted else Color(0.85, 0.8, 0.3))
		draw_string(ThemeDB.fallback_font, Vector2(ex, 22.0), enemy_title, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(1, 1, 1, 0.9))

	# Barres : vie (rouge) et endurance (verte, orange quand épuisé)
	var x := 24.0
	var y := size.y - 70.0
	_bar(Vector2(x, y), Vector2(320, 18), health_ratio, Color(0.8, 0.15, 0.15))
	_bar(Vector2(x, y + 26.0), Vector2(320, 12), stamina_ratio, Color(1.0, 0.55, 0.1) if exhausted else Color(0.3, 0.8, 0.3))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(x + 4.0, y - 4.0), tr("HUD_LIFE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(x + 4.0, y + 56.0), tr("HUD_STAMINA") + (tr("HUD_EXHAUSTED") if exhausted else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))


func _draw_reticle(center: Vector2) -> void:
	var col := Color(1, 1, 1, 0.9)
	draw_arc(center, reticle_radius, 0.0, TAU, 48, col, 2.0)
	draw_circle(center, 2.0, col)
	for d in 4:
		var v := dir_vector(d)
		draw_line(center + v * (reticle_radius + 2.0), center + v * (reticle_radius + 10.0), col, 2.0)
	var w := 120.0
	var p := center + Vector2(-w * 0.5, reticle_radius + 26.0)
	var font := ThemeDB.fallback_font
	if aiming:
		if drop_offset > 0.0:
			var m := center + Vector2(0.0, reticle_radius + drop_offset)
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -5), m + Vector2(5, 0), m + Vector2(0, 5), m + Vector2(-5, 0)]), Color(1.0, 0.55, 0.1, 0.95))
		if aim_distance > 0.0:
			draw_string(font, center + Vector2(reticle_radius + 16.0, 5.0), tr("HUD_METERS") % int(round(aim_distance)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))
	if weapon_kind == 1 and drawing:
		_bar(p, Vector2(w, 8), tension, Color(1.0, 0.85, 0.2) if tension >= 1.0 else Color(0.9, 0.9, 0.9))
	elif weapon_kind == 2:
		if reload_ratio < 1.0:
			_bar(p, Vector2(w, 8), reload_ratio, Color(0.9, 0.5, 0.2))
			draw_string(font, p + Vector2(0, 26), tr("HUD_RELOADING"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85))
		else:
			draw_string(font, p + Vector2(0, 12), tr("HUD_READY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 1.0, 0.6, 0.9))


func _bar(pos: Vector2, bar_size: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos - Vector2(2, 2), bar_size + Vector2(4, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos, Vector2(bar_size.x * clampf(ratio, 0.0, 1.0), bar_size.y)), color)


func _triangle(pos: Vector2, v: Vector2, s: float, color: Color) -> void:
	var p := Vector2(-v.y, v.x)
	draw_colored_polygon(PackedVector2Array([pos + v * s, pos - v * s * 0.6 + p * s, pos - v * s * 0.6 - p * s]), color)
