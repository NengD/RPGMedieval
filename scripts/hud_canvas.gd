class_name HudCanvas
extends Control
## Dessine : indicateur de direction autour du centre, barres de vie et d'endurance.

var selected_dir := 0
var guarding := false
var threat_dir := -1         # côté d'où arrive un coup ennemi (= côté à garder), -1 si aucun
var health_ratio := 1.0
var stamina_ratio := 1.0
var exhausted := false
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
	for d in 4:
		var v := dir_vector(d)
		var chosen := d == selected_dir
		var color := Color(1, 1, 1, 0.22)
		if chosen:
			color = Color(0.45, 0.8, 1.0, 0.95) if guarding else Color(1.0, 0.9, 0.4, 0.95)
		_triangle(center + v * 46.0, v, 9.0 if chosen else 6.0, color)
		if d == threat_dir:
			_triangle(center + v * 66.0, -v, 13.0, Color(1.0, 0.15, 0.1, 0.95))

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
	draw_string(font, Vector2(x + 4.0, y - 4.0), "Vie", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(x + 4.0, y + 56.0), "Endurance" + ("  (ÉPUISÉ)" if exhausted else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))


func _bar(pos: Vector2, bar_size: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos - Vector2(2, 2), bar_size + Vector2(4, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos, Vector2(bar_size.x * clampf(ratio, 0.0, 1.0), bar_size.y)), color)


func _triangle(pos: Vector2, v: Vector2, s: float, color: Color) -> void:
	var p := Vector2(-v.y, v.x)
	draw_colored_polygon(PackedVector2Array([pos + v * s, pos - v * s * 0.6 + p * s, pos - v * s * 0.6 - p * s]), color)
