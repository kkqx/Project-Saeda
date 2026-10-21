extends Node2D
## Mapa de fases (estilo Super Mario World): o marcador da Saeda anda pelos caminhos
## entre as fases. Direcional = andar, Z/Espaço/Enter = entrar na fase, Esc = menu.
## Os nós e caminhos vêm de assets/map/map_data.json.

const MAP_TEX := preload("res://assets/map/overworld.png")
const ICONS := preload("res://assets/map/node_icons.png")
const MARKER := preload("res://assets/map/marker.png")
const DATA_PATH := "res://assets/map/map_data.json"

const ICON := 20.0
const MARKER_W := 14.0
const MARKER_H := 22.0
const MARKER_FRAMES := 5
const SPEED := 62.0

const COL_PATH := Color("ecdca4")
const COL_PATH_SHADOW := Color(0.18, 0.12, 0.08, 0.55)
const COL_TEXT := Color("e9dcff")
const COL_DIM := Color("8f86b8")
const COL_ACCENT := Color("ffb98a")

var nodes: Array = []     # {"pos": Vector2, "level": int}
var edges: Array = []     # {"a": int, "b": int, "pts": PackedVector2Array, "len": float}

var at_node := 0
var _moving := false
var _edge := -1
var _s := 0.0             # distância percorrida a partir do ponto "a" da aresta
var _dir := 1             # +1 indo de a para b, -1 de b para a
var _marker_pos := Vector2.ZERO
var _face := 1
var _walk_t := 0.0
var _time := 0.0
var _busy := false
var _shake := 0.0

# animação de desbloqueio depois de concluir uma fase
var _reveal_edge := -1
var _reveal_node := -1
var _reveal_t := 0.0

var _fade: ColorRect
var _name_label: Label
var _info_label: Label
var _hint_label: Label


func _ready() -> void:
	Sfx.play_music("dusty")
	_load_map()
	at_node = clampi(Game.map_node, 0, nodes.size() - 1)
	_marker_pos = nodes[at_node]["pos"]

	if Game.just_completed >= 0:
		at_node = _node_of_level(Game.just_completed)
		_marker_pos = nodes[at_node]["pos"]
		Game.just_completed = -1
		for i in edges.size():
			var e: Dictionary = edges[i]
			if e["a"] == at_node and _level_unlocked(nodes[e["b"]]["level"]):
				_reveal_edge = i
				_reveal_node = e["b"]
				_reveal_t = -0.7
				_busy = true
				break

	_build_ui()
	_refresh_panel()


func _process(delta: float) -> void:
	_time += delta
	_shake = move_toward(_shake, 0.0, delta * 6.0)

	if _reveal_edge >= 0:
		if _reveal_t < 0.0 and _reveal_t + delta >= 0.0:
			Sfx.play("unlock")
		_reveal_t += delta
		if _reveal_t >= 1.4:
			_reveal_edge = -1
			_reveal_node = -1
			_busy = false
			_refresh_panel()
	elif not _busy:
		if _moving:
			_step_move(delta)
		else:
			_read_direction()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _moving:
		return
	if event.is_action_pressed("ui_cancel"):
		_leave(func() -> void: Game.go_title())
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		var level: int = nodes[at_node]["level"]
		if level >= 0 and Game.is_unlocked(level):
			Sfx.play("confirm")
			_leave(func() -> void: Game.start_level(level))
		else:
			_shake = 1.0
			Sfx.play("select", -6.0, 0.7)


# ---------------------------------------------------------------- DADOS ----

func _load_map() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for n in data["nodes"]:
		nodes.append({"pos": Vector2(n["pos"][0], n["pos"][1]), "level": int(n["level"])})
	for e in data["edges"]:
		var pts := PackedVector2Array()
		for p in e["pts"]:
			pts.append(Vector2(p[0], p[1]))
		var total := 0.0
		for i in range(pts.size() - 1):
			total += pts[i].distance_to(pts[i + 1])
		edges.append({"a": int(e["a"]), "b": int(e["b"]), "pts": pts, "len": total})


func _node_of_level(level: int) -> int:
	for i in nodes.size():
		if nodes[i]["level"] == level:
			return i
	return 0


func _level_unlocked(level: int) -> bool:
	return level >= 0 and Game.is_reachable(level)


func _node_unlocked(node: int) -> bool:
	if node == _reveal_node:
		return false   # ainda está sendo revelado
	return _level_unlocked(nodes[node]["level"])


func _point_at(edge: Dictionary, s: float) -> Vector2:
	var pts: PackedVector2Array = edge["pts"]
	var left := clampf(s, 0.0, edge["len"])
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf(left / maxf(seg, 0.001), 0.0, 1.0))
		left -= seg
	return pts[pts.size() - 1]


# ------------------------------------------------------------ MOVIMENTO ----

func _read_direction() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() < 0.5:
		return
	input = input.normalized()
	var best := -1
	var best_dot := 0.35
	var best_dir := 1
	for i in edges.size():
		var e: Dictionary = edges[i]
		var pts: PackedVector2Array = e["pts"]
		var leave := Vector2.ZERO
		var dir := 0
		var dest := -1
		if e["a"] == at_node:
			leave = (pts[1] - pts[0]).normalized()
			dir = 1
			dest = e["b"]
		elif e["b"] == at_node:
			leave = (pts[pts.size() - 2] - pts[pts.size() - 1]).normalized()
			dir = -1
			dest = e["a"]
		if dest < 0 or not _node_unlocked(dest):
			continue
		var d := input.dot(leave)
		if d > best_dot:
			best_dot = d
			best = i
			best_dir = dir
	if best < 0:
		return
	_edge = best
	_dir = best_dir
	_s = 0.0 if best_dir == 1 else edges[best]["len"]
	_moving = true


func _step_move(delta: float) -> void:
	var e: Dictionary = edges[_edge]
	var before := _marker_pos
	_s += _dir * SPEED * delta

	# dá para voltar no meio do caminho, como no Super Mario World
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 0.5:
		var ahead := (_point_at(e, _s + _dir * 4.0) - _point_at(e, _s)).normalized()
		if input.normalized().dot(ahead) < -0.6:
			_dir = -_dir

	_marker_pos = _point_at(e, _s)
	var step := _marker_pos - before
	if absf(step.x) > 0.01:
		_face = 1 if step.x > 0.0 else -1
	var prev_walk := _walk_t
	_walk_t += delta
	if int(prev_walk * 4.0) != int(_walk_t * 4.0):
		Sfx.play("step", -12.0, randf_range(0.9, 1.1))

	if _dir == 1 and _s >= e["len"]:
		_arrive(e["b"])
	elif _dir == -1 and _s <= 0.0:
		_arrive(e["a"])


func _arrive(node: int) -> void:
	at_node = node
	_moving = false
	_marker_pos = nodes[node]["pos"]
	Game.map_node = node
	_refresh_panel()


# ------------------------------------------------------------------ UI ----

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.03, 0.1, 0.8)
	panel.position = Vector2(0, 148)
	panel.size = Vector2(320, 32)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var line := ColorRect.new()
	line.color = Color(1.0, 0.72, 0.54, 0.5)
	line.position = Vector2(0, 148)
	line.size = Vector2(320, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(line)

	_name_label = Label.new()
	_name_label.position = Vector2(10, 150)
	_style_label(_name_label, 10, COL_ACCENT)
	layer.add_child(_name_label)

	_info_label = Label.new()
	_info_label.position = Vector2(10, 164)
	_style_label(_info_label, 7, COL_TEXT)
	layer.add_child(_info_label)

	_hint_label = Label.new()
	_hint_label.text = "Z: entrar    ESC: menu"
	_hint_label.position = Vector2(206, 164)
	_style_label(_hint_label, 7, COL_DIM)
	layer.add_child(_hint_label)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.5)


func _style_label(lab: Label, size: int, color: Color) -> void:
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_constant_override("outline_size", 3)
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.95))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_panel() -> void:
	var level: int = nodes[at_node]["level"]
	if level < 0:
		_name_label.text = "???"
		_info_label.text = "Em breve..."
		return
	var info: Dictionary = Game.LEVELS[level]
	_name_label.text = "%d · %s" % [level + 1, info["name"]]
	if Game.is_reachable(level) and not Game.is_unlocked(level):
		var m := Game.memory_status()
		_info_label.text = "A porta só abre com todas as memórias (%d/%d)" % [m.x, m.y]
	elif not Game.is_unlocked(level):
		_info_label.text = "Termine a fase anterior para liberar"
	elif Game.is_done(level):
		var d: Dictionary = Game.level_info(level)
		_info_label.text = "Memórias %d/%d    Melhor tempo %s" % [
			d.get("berries", 0), d.get("berries_total", 0), _format_time(d.get("best_time", 0.0))]
	else:
		_info_label.text = info["subtitle"]


func _format_time(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _leave(action: Callable) -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(action)


# --------------------------------------------------------------- DESENHO ----

func _draw() -> void:
	draw_texture(MAP_TEX, Vector2.ZERO)
	_draw_paths()
	for i in nodes.size():
		_draw_node(i)
	_draw_marker()


func _draw_paths() -> void:
	for i in edges.size():
		var e: Dictionary = edges[i]
		var dest_open := _node_unlocked(e["b"]) or (i == _reveal_edge)
		var shown := e["len"] as float
		var alpha := 1.0
		if i == _reveal_edge:
			shown = e["len"] * clampf(_reveal_t / 1.1, 0.0, 1.0)
		elif not dest_open:
			alpha = 0.22
		var s := 0.0
		while s <= shown:
			var p := _point_at(e, s)
			var q := p.floor()
			draw_rect(Rect2(q + Vector2(1, 1), Vector2(2, 2)), Color(COL_PATH_SHADOW, COL_PATH_SHADOW.a * alpha))
			draw_rect(Rect2(q, Vector2(2, 2)), Color(COL_PATH, alpha))
			s += 4.0


## A porta final, no meio das montanhas: pedra escura com luz azul quando abre.
func _draw_final_door(pos: Vector2, level: int) -> void:
	var reach := Game.is_reachable(level)
	var open := Game.is_unlocked(level)
	var a := 1.0 if reach else 0.55
	var pulse := 0.5 + 0.5 * sin(_time * 2.5)
	var b := pos + Vector2(0, 5)
	# moldura de pedra
	draw_rect(Rect2(b + Vector2(-8, -17), Vector2(16, 22)), Color(0.20, 0.18, 0.26, a))
	draw_rect(Rect2(b + Vector2(-7, -18), Vector2(14, 1)), Color(0.20, 0.18, 0.26, a))
	draw_rect(Rect2(b + Vector2(-6, -19), Vector2(12, 1)), Color(0.20, 0.18, 0.26, a))
	draw_rect(Rect2(b + Vector2(-8, -17), Vector2(1, 22)), Color(0.34, 0.31, 0.42, a))
	# vão da porta
	var inner := Color(0.04, 0.03, 0.08, a)
	if open:
		inner = Color(0.30 + 0.2 * pulse, 0.55 + 0.2 * pulse, 1.0, 1.0)
	draw_rect(Rect2(b + Vector2(-5, -15), Vector2(10, 20)), inner)
	draw_rect(Rect2(b + Vector2(-4, -17), Vector2(8, 2)), inner)
	if open:
		draw_circle(b + Vector2(0, -6), 14.0 + pulse * 3.0, Color(0.3, 0.6, 1.0, 0.10 + 0.08 * pulse))
		draw_circle(b + Vector2(0, -6), 8.0, Color(0.5, 0.8, 1.0, 0.18))
		for k in 3:
			var wy := fposmod(-_time * 8.0 + k * 9.0, 26.0)
			draw_rect(Rect2(b + Vector2(-3 + k * 3, -wy), Vector2(1, 1)), Color(0.9, 0.97, 1.0, 0.9 - wy / 30.0))
	elif reach:
		# trancada: luz azul fraca por baixo e cadeado
		draw_circle(b + Vector2(0, -6), 9.0, Color(0.3, 0.5, 1.0, 0.05 + 0.04 * pulse))
		var tl := (b + Vector2(-ICON * 0.5, -ICON * 0.5 - 10.0)).floor()
		draw_texture_rect_region(ICONS, Rect2(tl, Vector2(ICON, ICON)), Rect2(0, 4 * ICON, ICON, ICON))
	else:
		var tl2 := (b + Vector2(-ICON * 0.5, -ICON * 0.5 - 10.0)).floor()
		draw_texture_rect_region(ICONS, Rect2(tl2, Vector2(ICON, ICON)), Rect2(0, 4 * ICON, ICON, ICON))


func _draw_node(i: int) -> void:
	var n: Dictionary = nodes[i]
	var level: int = n["level"]
	var pos: Vector2 = n["pos"]
	if level >= 0 and Game.LEVELS[level].get("final", false):
		_draw_final_door(pos, level)
		return
	var state := 0   # 0 bloqueado, 1 aberto, 2 concluído
	if _node_unlocked(i):
		state = 2 if Game.is_done(level) else 1
	var row := level if level >= 0 else 4
	var bounce := 0.0
	if state == 1:
		bounce = sin(_time * 4.0) * 0.8
		var glow := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(pos + Vector2(0, 1), 11.0 + glow * 2.0, Color(1.0, 0.7, 0.35, 0.10 + 0.07 * glow))
	var top_left := (pos - Vector2(ICON * 0.5, ICON * 0.5 + 1.0 + bounce)).floor()
	draw_texture_rect_region(ICONS, Rect2(top_left, Vector2(ICON, ICON)),
		Rect2(state * ICON, row * ICON, ICON, ICON))


func _draw_marker() -> void:
	var pos := _marker_pos
	# sombra
	draw_circle(pos + Vector2(0, 3), 4.0, Color(0.05, 0.03, 0.1, 0.35))
	var frame := 0
	var bob := 0.0
	if _moving:
		frame = 1 + (int(_walk_t / 0.11) % 4)
		bob = absf(sin(_walk_t * 12.0)) * 1.2
	else:
		bob = sin(_time * 2.5) * 0.4
	var feet := Vector2(pos.x, pos.y + 4.0 - bob).floor()
	draw_set_transform(feet, 0.0, Vector2(_face, 1))
	draw_texture_rect_region(MARKER, Rect2(-MARKER_W * 0.5, -MARKER_H, MARKER_W, MARKER_H),
		Rect2(frame * MARKER_W, 0, MARKER_W, MARKER_H))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
