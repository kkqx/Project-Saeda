extends Node
## Autoload que cria as ações de input por código.
## Assim o projeto funciona sem configurar o Mapa de Entrada à mão.
## Quer mudar as teclas? Edite as listas abaixo.


func _ready() -> void:
	_add_action("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("move_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("jump", [KEY_Z, KEY_SPACE, KEY_K], [JOY_BUTTON_A])
	_add_action("dash", [KEY_X, KEY_SHIFT, KEY_J], [JOY_BUTTON_X, JOY_BUTTON_B])


func _add_action(action: String, keys: Array, buttons: Array = [], axis: int = -1, axis_value: float = 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.5)
	for k in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = k
		InputMap.action_add_event(action, key_event)
	for b in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = b
		InputMap.action_add_event(action, button_event)
	if axis >= 0:
		var motion_event := InputEventJoypadMotion.new()
		motion_event.axis = axis as JoyAxis
		motion_event.axis_value = axis_value
		InputMap.action_add_event(action, motion_event)
