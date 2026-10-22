extends Control
## Tela de teclas (abre em Opções → TECLAS). Enter/Z escolhe uma ação e a próxima tecla
## apertada vira o novo atalho. Esc cancela. O controle (joystick) não muda.

signal closed

const COL_DIM := Color("8f86b8")
const COL_SELECTED := Color("ffb98a")
const COL_WAIT := Color("9fe8ff")

var _actions: Array = []
var _labels: Array[Label] = []
var _selected := 0
var _waiting := false
var _time := 0.0
var _msg: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2.ZERO
	size = Vector2(320, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.08, 0.96)
	shade.size = Vector2(320, 180)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_label("TECLAS", 10, 14, Color("e9dcff"))
	_actions = Settings.KEY_ACTIONS.keys()
	_actions.append("@reset")
	_actions.append("@back")
	for i in _actions.size():
		_labels.append(_label("", 8, 32 + i * 12, COL_DIM))
	_msg = _label("", 6, 160, Color(0.62, 0.6, 0.8, 0.85))
	_refresh()


func _label(text: String, size: int, y: float, color: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.position = Vector2(0, y)
	lab.size = Vector2(320, 14)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_constant_override("outline_size", 3)
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.95))
	lab.add_theme_color_override("font_color", color)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lab)
	return lab


func _refresh() -> void:
	for i in _actions.size():
		var a: String = _actions[i]
		var t := ""
		if a == "@reset":
			t = "RESTAURAR PADRÃO"
		elif a == "@back":
			t = "VOLTAR"
		else:
			var val := "< aperte uma tecla >" if (_waiting and i == _selected) else Settings.key_name(a)
			t = "%s   %s" % [Settings.KEY_ACTIONS[a], val]
		_labels[i].text = ("> " if i == _selected else "  ") + t
		var col := COL_DIM
		if i == _selected:
			var pulse := 0.85 + 0.15 * sin(_time * 5.0)
			col = COL_WAIT if _waiting else Color(COL_SELECTED.r * pulse, COL_SELECTED.g * pulse, COL_SELECTED.b * pulse)
		_labels[i].add_theme_color_override("font_color", col)
	_msg.text = "Aperte uma tecla (Esc cancela)" if _waiting else "Enter/Z: trocar    Esc: voltar"


func _process(delta: float) -> void:
	_time += delta
	_refresh()


func _input(event: InputEvent) -> void:
	# captura de tecla: precisa ver o evento antes do resto do jogo
	if not _waiting or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var k := (event as InputEventKey).physical_keycode
	_waiting = false
	if k == KEY_ESCAPE:
		return
	var action: String = _actions[_selected]
	# se outra ação já usa essa tecla, as duas trocam de tecla
	for other in Settings.KEY_ACTIONS:
		if other != action and Settings.key_for(other) == int(k):
			Settings.key_map[other] = Settings.key_for(action)
	Settings.key_map[action] = int(k)
	Settings.apply_keys()
	Settings.save_settings()
	Sfx.play("confirm")


func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if _waiting:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
	elif event.is_action_pressed("ui_down"):
		_selected = (_selected + 1) % _actions.size()
		Sfx.play("select")
	elif event.is_action_pressed("ui_up"):
		_selected = (_selected - 1 + _actions.size()) % _actions.size()
		Sfx.play("select")
	elif event.is_action_pressed("ui_accept"):
		var a: String = _actions[_selected]
		if a == "@back":
			_close()
		elif a == "@reset":
			Settings.reset_keys()
			Settings.save_settings()
			Sfx.play("confirm")
		else:
			_waiting = true
			Sfx.play("select")


func _close() -> void:
	Sfx.play("confirm")
	closed.emit()
	queue_free()
