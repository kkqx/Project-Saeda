extends Control
## Tela de opções (usada no título e no menu de pausa). Esquerda/direita muda o valor,
## Z/Enter alterna, Esc volta. Tudo é salvo em user://settings.cfg (veja settings.gd).

signal closed

const COL_DIM := Color("8f86b8")
const COL_SELECTED := Color("ffb98a")

var _rows: Array[Dictionary] = []
var _labels: Array[Label] = []
var _selected := 0
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2.ZERO
	size = Vector2(320, 180)      # tamanho fixo da tela do jogo (funciona em qualquer pai)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.08, 0.88)
	shade.size = Vector2(320, 180)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_label("OPÇÕES", 10, 22, Color("e9dcff"))
	_rows = [
		{"id": "music", "name": "MÚSICA"},
		{"id": "sfx", "name": "EFEITOS"},
		{"id": "fullscreen", "name": "TELA CHEIA"},
		{"id": "infinite_dash", "name": "DASH INFINITO"},
		{"id": "speed", "name": "VELOCIDADE"},
		{"id": "title_style", "name": "TELA INICIAL"},
		{"id": "keys", "name": "TECLAS"},
		{"id": "back", "name": "VOLTAR"},
	]
	for i in _rows.size():
		_labels.append(_label("", 9, 40 + i * 13, COL_DIM))
	_label("Esquerda/Direita: mudar    Esc: voltar", 6, 160, Color(0.62, 0.6, 0.8, 0.85))
	_label("Ajuda: dash infinito e jogo mais lento", 6, 150, Color(0.62, 0.6, 0.8, 0.6))
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


func _value_text(id: String) -> String:
	match id:
		"music":
			return "< %d >" % Settings.music_level
		"sfx":
			return "< %d >" % Settings.sfx_level
		"fullscreen":
			return "< %s >" % ("SIM" if Settings.fullscreen else "NÃO")
		"infinite_dash":
			return "< %s >" % ("SIM" if Settings.infinite_dash else "NÃO")
		"speed":
			return "< %d%% >" % int(round(Settings.game_speed() * 100.0))
		"title_style":
			return "< %s >" % ("NOVA" if Settings.title_style == 0 else "ATUAL")
	return ""


func _refresh() -> void:
	for i in _rows.size():
		var lab := _labels[i]
		var name: String = _rows[i]["name"]
		var val := _value_text(_rows[i]["id"])
		lab.text = ("> " if i == _selected else "  ") + name + ("   " + val if val != "" else "")
		if i == _selected:
			var pulse := 0.85 + 0.15 * sin(_time * 5.0)
			lab.add_theme_color_override("font_color", Color(COL_SELECTED.r * pulse, COL_SELECTED.g * pulse, COL_SELECTED.b * pulse))
		else:
			lab.add_theme_color_override("font_color", COL_DIM)


func _process(delta: float) -> void:
	_time += delta
	_refresh()


func _change(dir: int) -> void:
	var id: String = _rows[_selected]["id"]
	match id:
		"music":
			Settings.music_level = clampi(Settings.music_level + dir, 0, 10)
		"sfx":
			Settings.sfx_level = clampi(Settings.sfx_level + dir, 0, 10)
		"fullscreen":
			Settings.fullscreen = not Settings.fullscreen
		"infinite_dash":
			Settings.infinite_dash = not Settings.infinite_dash
		"speed":
			Settings.speed_index = clampi(Settings.speed_index + dir, 0, Settings.SPEEDS.size() - 1)
		"title_style":
			Settings.title_style = 1 - Settings.title_style
		_:
			return
	Settings.apply()
	Settings.save_settings()
	Sfx.play("select")


func close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_selected = (_selected + 1) % _rows.size()
		Sfx.play("select")
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_selected = (_selected - 1 + _rows.size()) % _rows.size()
		Sfx.play("select")
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_change(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_change(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		if _rows[_selected]["id"] == "back":
			Sfx.play("confirm")
			close()
		elif _rows[_selected]["id"] == "keys":
			Sfx.play("confirm")
			add_child(preload("res://scripts/keys_menu.gd").new())
		else:
			_change(1)
