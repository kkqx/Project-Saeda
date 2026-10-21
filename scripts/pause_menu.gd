extends Control
## Menu de pausa da fase (Esc): continuar, reiniciar ou voltar ao mapa.
## Fica ativo mesmo com o jogo pausado (process_mode = ALWAYS).

signal resumed
signal restart_requested
signal map_requested

const ITEMS: Array[String] = ["CONTINUAR", "REINICIAR FASE", "OPÇÕES", "VOLTAR AO MAPA"]
const COL_DIM := Color("8f86b8")
const COL_SELECTED := Color("ffb98a")

var _selected := 0
var _labels: Array[Label] = []
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.08, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_add_label("PAUSADO", 10, Vector2(0, 52), Color("e9dcff"))
	for i in ITEMS.size():
		_labels.append(_add_label(ITEMS[i], 9, Vector2(0, 80 + i * 16), COL_DIM))
	_add_label("Esc: continuar", 6, Vector2(0, 160), Color(0.62, 0.6, 0.8, 0.8))


func _add_label(text: String, size: int, pos: Vector2, color: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.position = pos
	lab.size = Vector2(320, 14)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_constant_override("outline_size", 3)
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.95))
	lab.add_theme_color_override("font_color", color)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lab)
	return lab


func open() -> void:
	_selected = 0
	visible = true
	get_tree().paused = true
	Sfx.set_music_volume(-20.0)
	Sfx.play("select")
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	Sfx.set_music_volume(-10.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_refresh()


func _open_options() -> void:
	var opt := preload("res://scripts/options_menu.gd").new()
	add_child(opt)


func _refresh() -> void:
	for i in _labels.size():
		var lab := _labels[i]
		if i == _selected:
			var pulse := 0.85 + 0.15 * sin(_time * 5.0)
			lab.text = "> " + ITEMS[i]
			lab.add_theme_color_override("font_color", Color(COL_SELECTED.r * pulse, COL_SELECTED.g * pulse, COL_SELECTED.b * pulse))
		else:
			lab.text = ITEMS[i]
			lab.add_theme_color_override("font_color", COL_DIM)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		close()
		resumed.emit()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_selected = (_selected + 1) % ITEMS.size()
		Sfx.play("select")
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_selected = (_selected - 1 + ITEMS.size()) % ITEMS.size()
		Sfx.play("select")
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		Sfx.play("confirm")
		match _selected:
			0:
				close()
				resumed.emit()
			1:
				close()
				restart_requested.emit()
			2:
				_open_options()
			3:
				close()
				map_requested.emit()
