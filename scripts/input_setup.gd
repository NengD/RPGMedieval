extends Node
## Déclare les actions de jeu (clavier/souris + manette).
## Les touches sont "physiques" : ZQSD sur un clavier AZERTY est au même endroit que WASD.


func _enter_tree() -> void:
	register_actions()


static func register_actions() -> void:
	# Déplacement
	_add(&"move_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add(&"move_back", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add(&"move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(&"move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(&"jump", [_key(KEY_SPACE), _btn(JOY_BUTTON_A)])
	_add(&"sprint", [_key(KEY_SHIFT), _btn(JOY_BUTTON_LEFT_STICK)])
	_add(&"dodge", [_key(KEY_C), _btn(JOY_BUTTON_B)])
	# Caméra (stick droit ; la souris est gérée directement par la caméra)
	_add(&"look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add(&"look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add(&"look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add(&"look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add(&"toggle_view", [_key(KEY_V), _btn(JOY_BUTTON_RIGHT_STICK)])
	# Divers
	_add(&"debug_hit", [_key(KEY_F), _btn(JOY_BUTTON_X)])
	_add(&"reset_combat", [_key(KEY_R), _btn(JOY_BUTTON_START)])


static func _add(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)
	for e in events:
		InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _btn(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
