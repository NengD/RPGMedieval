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
	_add(&"attack", [_mouse(MOUSE_BUTTON_LEFT), _btn(JOY_BUTTON_RIGHT_SHOULDER)])
	_add(&"guard", [_mouse(MOUSE_BUTTON_RIGHT), _btn(JOY_BUTTON_LEFT_SHOULDER)])
	_add(&"cancel_draw", [_key(KEY_X), _btn(JOY_BUTTON_X)])
	_add(&"toggle_practice", [_key(KEY_T), _btn(JOY_BUTTON_Y)])
	_add(&"next_melee", [_key(KEY_G)])
	_add(&"toggle_shield", [_key(KEY_H)])
	_add(&"next_outfit", [_key(KEY_K)])
	_add(&"next_tabard_color", [_key(KEY_L)])
	_add(&"quick_save", [_key(KEY_F5)])
	_add(&"quick_load", [_key(KEY_F9)])
	_add(&"toggle_ai", [_key(KEY_F4), _btn(JOY_BUTTON_DPAD_DOWN)])
	_add(&"difficulty_easy", [_key(KEY_F1)])
	_add(&"difficulty_normal", [_key(KEY_F2)])
	_add(&"difficulty_hard", [_key(KEY_F3)])
	_add(&"difficulty_cycle", [_btn(JOY_BUTTON_DPAD_UP)])
	_add(&"weapon_next", [_key(KEY_TAB), _mouse(MOUSE_BUTTON_WHEEL_DOWN), _btn(JOY_BUTTON_DPAD_RIGHT)])
	_add(&"weapon_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP), _btn(JOY_BUTTON_DPAD_LEFT)])
	_add(&"clear_arrows", [_key(KEY_BACKSPACE)])
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


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
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
