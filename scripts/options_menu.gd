class_name OptionsMenu
extends CanvasLayer
## Petit menu d'options (F8) : volumes Musique / Effets / Ambiance, tremblement de caméra, arrêt sur image et ralenti.
## Ouvert, il libère la souris ; fermé, il la reprend. Les réglages sont mémorisés (user://reglages.cfg).

var _panel: PanelContainer
var _was_captured := false


func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.9)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = tr("OPT_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	for spec in [["Musique", "OPT_MUSIC"], ["Effets", "OPT_FX"], ["Ambiance", "OPT_AMBIENT"]]:
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = tr(spec[1])
		lab.custom_minimum_size = Vector2(130, 0)
		row.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Fx.sfx().volumes[spec[0]]
		sl.custom_minimum_size = Vector2(220, 20)
		sl.name = "Slider_" + spec[0]
		sl.value_changed.connect(func(v: float): Fx.sfx().set_volume(spec[0], v))
		row.add_child(sl)
		box.add_child(row)
	var shake := CheckBox.new()
	shake.text = tr("OPT_SHAKE")
	shake.name = "Check_Shake"
	shake.button_pressed = Fx.shake_enabled
	shake.toggled.connect(func(on: bool): Fx.shake_enabled = on)
	box.add_child(shake)
	var stop := CheckBox.new()
	stop.text = tr("OPT_HITSTOP")
	stop.name = "Check_HitStop"
	stop.button_pressed = Fx.hit_stop_enabled
	stop.toggled.connect(func(on: bool): Fx.hit_stop_enabled = on)
	box.add_child(stop)
	var hint := Label.new()
	hint.text = tr("OPT_CLOSE")
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)
	add_child(_panel)
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	if _panel.visible:
		_panel.visible = false
		Fx.sfx().save_settings()
		Fx.save_settings()
		if _was_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_panel.visible = true
		_panel.position = (get_viewport().get_visible_rect().size - _panel.size) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_options"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _panel.visible and event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()
