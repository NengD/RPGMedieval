class_name Hud
extends CanvasLayer
## Interface : aide des touches, état du héros, messages de combat, barres, direction.

var player: Player
var dummy: TrainingDummy
var enemy: Enemy
var target_score := 0

var _help: Label
var _status: Label
var _message: Label
var _crosshair: ColorRect
var _canvas: HudCanvas

const _STATE_NAMES := ["STATE_IDLE", "STATE_WINDUP", "STATE_STRIKE", "STATE_RECOVERY", "STATE_STAGGER"]   # clés de traduction


func _ready() -> void:
	_help = _make_label()
	_help.position = Vector2(16, 12)
	_help.text = "\n".join([tr("HELP_TITLE"), tr("HELP_MOVE"), tr("HELP_WEAPON"), tr("HELP_SWORD"), tr("HELP_RANGED"), tr("HELP_KEYS"), tr("HELP_SAVE"), tr("HELP_WEAPONS"), tr("HELP_OUTFIT"), tr("HELP_GRAPHICS")])
	add_child(_help)

	_status = _make_label()
	_status.position = Vector2(16, 175)
	add_child(_status)

	_canvas = HudCanvas.new()
	add_child(_canvas)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.8)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE   # sinon il avale les mouvements de souris !
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(2, 2)
	add_child(_crosshair)

	_message = _make_label()
	_message.add_theme_font_size_override("font_size", 30)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.anchor_left = 0.0
	_message.anchor_right = 1.0
	_message.anchor_top = 0.64
	_message.anchor_bottom = 0.72
	_message.modulate.a = 0.0
	add_child(_message)

	var c := player.combatant
	c.hit_resolved.connect(_on_player_hit_resolved)
	c.strike_result.connect(_on_player_strike_result)
	c.died.connect(func(): show_message(tr("MSG_DEAD"), Color(1, 0.3, 0.3), 2.0))
	player.notice.connect(func(text: String): show_message(tr(text), Color(0.9, 0.9, 0.9), 1.0))
	player.combatant.projectile_result.connect(_on_player_shot_result)
	enemy.combatant.died.connect(func(): show_message(tr("MSG_ENEMY_DEFEATED"), Color(0.5, 1.0, 0.5), 2.0))


func show_message(text: String, color: Color, duration := 0.9) -> void:
	_message.text = text
	_message.modulate = Color(color, 1.0)
	var tw := create_tween()
	tw.tween_interval(duration * 0.5)
	tw.tween_property(_message, "modulate:a", 0.0, duration * 0.5)


func _on_player_hit_resolved(result: int, _dir: int, amount: float, _attacker: Combatant) -> void:
	match result:
		Combatant.Result.HIT: show_message(tr("MSG_HIT") % int(round(amount)), Color(1, 0.35, 0.3))
		Combatant.Result.BLOCKED: show_message(tr("MSG_BLOCKED"), Color(0.5, 0.8, 1.0))
		Combatant.Result.PARRIED: show_message(tr("MSG_PARRY_PERFECT"), Color(0.4, 1.0, 1.0))
		Combatant.Result.GUARD_BROKEN: show_message(tr("MSG_GUARD_BROKEN") % int(round(amount)), Color(1, 0.55, 0.1))
		Combatant.Result.DODGED: show_message(tr("MSG_DODGED"), Color(0.8, 0.8, 0.8))


func _on_player_shot_result(result: int, _victim: Combatant, amount: float, head: bool) -> void:
	match result:
		Combatant.Result.HIT:
			show_message(tr("MSG_HEADSHOT" if head else "MSG_HIT") % int(round(amount)), Color(1.0, 0.85, 0.2) if head else Color(1.0, 0.7, 0.4))
		Combatant.Result.BLOCKED, Combatant.Result.PARRIED:
			show_message(tr("MSG_SHOT_BLOCKED"), Color(0.8, 0.8, 0.8))
		Combatant.Result.GUARD_BROKEN:
			show_message(tr("MSG_SHOT_GUARD_BROKEN"), Color(1, 0.55, 0.1))


func _on_player_strike_result(result: int, _victim: Combatant) -> void:
	if result == Combatant.Result.BLOCKED:
		show_message(tr("MSG_STRIKE_BLOCKED"), Color(0.8, 0.8, 0.8))
	elif result == Combatant.Result.PARRIED:
		show_message(tr("MSG_STRIKE_PARRIED"), Color(1, 0.7, 0.2))


func _process(_delta: float) -> void:
	var c := player.combatant
	var fps_view := player.rig.first_person
	_crosshair.visible = fps_view
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var guard_text := ""
	if c.is_guarding():
		guard_text = tr("HUD_GUARD") % (tr("HUD_PERFECT") if c.guard_time <= GameConfig.PERFECT_PARRY_WINDOW else "")
	var lines := [
		tr("HUD_LINE_VIEW") % [tr("HUD_VIEW_FIRST") if fps_view else tr("HUD_VIEW_THIRD"), speed],
		tr("HUD_LINE_STATE") % [tr(_STATE_NAMES[c.state]), guard_text, tr("HUD_DODGING") if player.is_dodging else ""],
		tr("HUD_LINE_DUMMY") % (tr("HUD_YES") if dummy.practice else tr("HUD_NO")),
		tr("HUD_LINE_DIFFICULTY") % [tr(GameConfig.DIFFICULTY_NAMES[enemy.difficulty]), tr(Enemy.MODE_NAMES[enemy.mode]) if enemy.ai_enabled else tr("HUD_AI_OFF")],
		tr("HUD_LINE_WEAPON") % [tr(player.current_weapon_name_key()), target_score],
		_protection_line(c),
	]
	_status.text = "\n".join(lines)
	_status.position.y = _help.position.y + _help.get_minimum_size().y + 14.0   # toujours sous l'aide, quel que soit son nombre de lignes

	_canvas.weapon_kind = player.weapon_kind
	_canvas.drawing = player.drawing
	_canvas.tension = player.bow_tension
	_canvas.reload_ratio = 1.0 - clampf(player.crossbow_reload / GameConfig.CROSSBOW_RELOAD_TIME, 0.0, 1.0)
	var spread := 0.0
	if player.weapon_kind == Player.Weapon.BOW:
		spread = lerpf(GameConfig.BOW_SPREAD_DEG_MAX, GameConfig.BOW_SPREAD_DEG_MIN, player.bow_tension if player.drawing else 0.0)
	else:
		spread = GameConfig.CROSSBOW_SPREAD_DEG
	var focal := _canvas.size.y * 0.5 / tan(deg_to_rad(player.rig.camera.fov * 0.5))
	spread *= player.spread_factor()
	_canvas.reticle_radius = 8.0 + focal * tan(deg_to_rad(spread))
	_canvas.aiming = player.is_aiming
	_canvas.aim_distance = player.aim_distance
	_canvas.drop_offset = focal * tan(player.impact_drop_angle()) if GameConfig.AIM_SHOW_DROP_MARKER else 0.0
	_canvas.guarding = c.guard_held
	_canvas.health_ratio = c.health / c.max_health
	_canvas.stamina_ratio = c.stamina / c.stats.get_derived(&"endurance_max")
	_canvas.exhausted = c.exhausted
	_canvas.enemy_visible = not enemy.combatant.dead
	_canvas.enemy_health_ratio = enemy.combatant.health / enemy.combatant.max_health
	_canvas.enemy_stamina_ratio = enemy.combatant.stamina / enemy.combatant.stats.get_derived(&"endurance_max")
	_canvas.enemy_exhausted = enemy.combatant.exhausted
	_canvas.enemy_title = tr("HUD_ENEMY_TITLE") % tr(GameConfig.DIFFICULTY_NAMES[enemy.difficulty])
	_canvas.queue_redraw()


## Protection de la tenue (par type de dégâts), poids porté et vitesse d'attaque.
func _protection_line(c: Combatant) -> String:
	var prot := c.protection
	return tr("HUD_LINE_PROTECTION") % [
		int(round(100.0 * float(prot.get(DamageType.Type.TRANCHANT, 0.0)))),
		int(round(100.0 * float(prot.get(DamageType.Type.CONTONDANT, 0.0)))),
		int(round(100.0 * float(prot.get(DamageType.Type.PERFORANT, 0.0)))),
		c.stats.carried_weight, c.stats.get_derived(&"charge_max"),
		int(round(100.0 * c.stats.get_derived(&"vitesse_attaque"))),
	]


func _make_label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", 16)
	return l
