extends CanvasLayer
## Atmosfera da fase em cima do cenário (e abaixo do HUD): vento, partículas, raios
## de luz e névoa. Cada fase tem um tema (THEMES, na ordem de Game.LEVELS).
## Tudo é desenhado por código e usa pouquíssimo processamento.

const THEMES := [
	# 0 Praia: vento com areia, luz fraca do sol
	{"kind": "dust", "count": 46, "col": Color("e8d9a8"), "shafts": 2, "shaft_col": Color(1.0, 0.93, 0.7), "streaks": 7, "fog": 0},
	# 1 Torres médias: cinzas e brasas subindo
	{"kind": "embers", "count": 38, "col": Color("ff9a4a"), "shafts": 1, "shaft_col": Color(1.0, 0.7, 0.45), "streaks": 3, "fog": 2},
	# 2 Pontes: folhas levadas pelo vento e névoa
	{"kind": "leaves", "count": 26, "col": Color("a9c46a"), "shafts": 2, "shaft_col": Color(0.9, 1.0, 0.85), "streaks": 5, "fog": 3},
	# 3 Cidade (noite): garoa fina e névoa fria
	{"kind": "rain", "count": 70, "col": Color("9fc4e8"), "shafts": 0, "shaft_col": Color.WHITE, "streaks": 0, "fog": 3},
	# 4 Montanha (pôr do sol): luzinhas flutuando e raios quentes
	{"kind": "motes", "count": 40, "col": Color("ffd6a0"), "shafts": 3, "shaft_col": Color(1.0, 0.8, 0.55), "streaks": 6, "fog": 0},
]

var level: Node
var _theme: Dictionary
var _add: Node2D        # camada de brilho (mistura aditiva)
var _norm: Node2D       # camada normal
var _t := 0.0
var _parts: Array = []
var _streaks: Array = []
var _fogs: Array = []
var _cam_prev := Vector2.ZERO
var _cam_move := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func setup(lv: Node) -> void:
	level = lv
	layer = 2
	_theme = THEMES[clampi(Game.current, 0, THEMES.size() - 1)]
	_rng.seed = 100 + Game.current
	_norm = Node2D.new()
	_norm.draw.connect(_draw_norm)
	add_child(_norm)
	_add = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = m
	_add.draw.connect(_draw_add)
	add_child(_add)
	for i in int(_theme["count"]):
		_parts.append(_new_part(true))
	for i in int(_theme["streaks"]):
		_streaks.append({"x": _rng.randf_range(-40, 320), "y": _rng.randf_range(10, 170), "len": _rng.randf_range(14, 44),
			"v": _rng.randf_range(160, 260), "a": 0.0, "wait": _rng.randf_range(0.0, 4.0)})
	for i in int(_theme["fog"]):
		_fogs.append({"x": _rng.randf_range(-60, 380), "y": _rng.randf_range(90, 175), "r": _rng.randf_range(50, 90),
			"v": _rng.randf_range(3, 9), "ph": _rng.randf() * TAU})
	if level != null and level.get("camera") != null:
		_cam_prev = level.camera.get_screen_center_position()


## Rajada de vento 0..1 que vai e volta devagar (todo o resto usa isso).
func gust(t: float = -1.0) -> float:
	if t < 0.0:
		t = _t
	var g := 0.5 + 0.5 * sin(t * 0.37)
	g *= 0.55 + 0.45 * sin(t * 0.91 + 1.3)
	return clampf(0.25 + g * 0.9, 0.0, 1.0)


func _new_part(anywhere: bool) -> Dictionary:
	var p := {
		"x": _rng.randf_range(-10, 330), "y": _rng.randf_range(-10, 190) if anywhere else -6.0,
		"z": _rng.randf_range(0.4, 1.0),       # profundidade: perto = rápido e maior
		"ph": _rng.randf() * TAU, "s": _rng.randf_range(0.7, 1.4),
	}
	match _theme["kind"]:
		"embers":
			p["y"] = _rng.randf_range(0, 190) if anywhere else 186.0
		"dust":
			if not anywhere:
				p["x"] = -6.0
				p["y"] = _rng.randf_range(0, 180)
	return p


func _process(delta: float) -> void:
	_t += delta
	var cam := Vector2.ZERO
	if level != null and level.get("camera") != null:
		cam = level.camera.get_screen_center_position()
	_cam_move = cam - _cam_prev
	_cam_prev = cam
	var g := gust()
	var kind: String = _theme["kind"]
	for i in _parts.size():
		var p: Dictionary = _parts[i]
		var z: float = p["z"]
		var par := _cam_move * (0.6 + 0.4 * z)      # a câmera arrasta as partículas
		p["x"] -= par.x
		p["y"] -= par.y
		match kind:
			"dust":
				p["x"] += (28.0 + 120.0 * g) * z * delta
				p["y"] += sin(_t * 2.0 + p["ph"]) * 6.0 * delta + 4.0 * z * delta
			"embers":
				p["x"] += (6.0 + 40.0 * g) * z * delta + sin(_t * 1.7 + p["ph"]) * 8.0 * delta
				p["y"] -= (10.0 + 14.0 * z) * delta
			"leaves":
				p["x"] += (20.0 + 90.0 * g) * z * delta
				p["y"] += (10.0 + 8.0 * z) * delta + sin(_t * 3.0 + p["ph"]) * 10.0 * delta
			"rain":
				p["x"] += (-14.0 - 22.0 * g) * z * delta
				p["y"] += (170.0 + 90.0 * z) * delta
			"motes":
				p["x"] += (6.0 + 30.0 * g) * z * delta + sin(_t * 0.9 + p["ph"]) * 6.0 * delta
				p["y"] += cos(_t * 0.7 + p["ph"]) * 5.0 * delta - 2.0 * z * delta
		if p["x"] > 330.0 or p["x"] < -14.0 or p["y"] > 192.0 or p["y"] < -12.0:
			var np := _new_part(false)
			if kind == "rain":
				np["x"] = _rng.randf_range(-10, 340)
			elif kind == "motes" or kind == "leaves":
				np["y"] = _rng.randf_range(-6, 180) if p["x"] > 330.0 else -6.0
				if p["x"] > 330.0:
					np["x"] = -8.0
			_parts[i] = np
	# riscos de vento: aparecem quando a rajada é forte
	for s in _streaks:
		if s["wait"] > 0.0:
			s["wait"] -= delta
			s["a"] = maxf(s["a"] - delta * 2.0, 0.0)
			if s["wait"] <= 0.0 and g > 0.45:
				s["x"] = -50.0
				s["y"] = _rng.randf_range(10, 170)
				s["a"] = _rng.randf_range(0.18, 0.4)
				s["len"] = _rng.randf_range(14, 48)
			elif s["wait"] <= 0.0:
				s["wait"] = 0.4
			continue
		s["x"] += s["v"] * (0.6 + g) * delta
		if s["x"] > 340.0:
			s["wait"] = _rng.randf_range(0.5, 3.5)
			s["a"] = 0.0
	for f in _fogs:
		f["x"] += (f["v"] + 20.0 * g) * delta - _cam_move.x * 0.35
		if f["x"] > 400.0:
			f["x"] = -90.0
		elif f["x"] < -100.0:
			f["x"] = 395.0
	_norm.queue_redraw()
	_add.queue_redraw()


func _draw_norm() -> void:
	var col: Color = _theme["col"]
	var kind: String = _theme["kind"]
	# névoa: círculos suaves empilhados
	for f in _fogs:
		var fc := Color(0.78, 0.84, 0.9, 0.0)
		if Game.current == 3:
			fc = Color(0.35, 0.5, 0.62, 0.0)
		elif Game.current == 1:
			fc = Color(0.55, 0.45, 0.5, 0.0)
		var breathe := 0.8 + 0.2 * sin(_t * 0.4 + f["ph"])
		for k in 7:
			var r: float = f["r"] * (1.0 - k * 0.12)
			fc.a = 0.022 * breathe
			_norm.draw_circle(Vector2(f["x"], f["y"] + k * 0.5), r, fc)
	for p in _parts:
		var z: float = p["z"]
		var pos := Vector2(p["x"], p["y"])
		match kind:
			"dust":
				var c := col
				c.a = 0.35 + 0.35 * z
				_norm.draw_rect(Rect2(pos, Vector2(1.0, 1.0) * (1.0 if z < 0.75 else 2.0)), c)
			"leaves":
				var ang: float = _t * (2.0 + p["s"]) + p["ph"]
				var lc := col.lerp(Color("d6a050"), fmod(p["ph"], 1.0) * 0.6)
				lc.a = 0.9
				var d: Vector2 = Vector2(cos(ang), sin(ang)) * 2.4 * float(p["s"])
				var n := Vector2(-d.y, d.x) * 0.45
				_norm.draw_colored_polygon(PackedVector2Array([pos + d, pos + n, pos - d, pos - n]), lc)
			"rain":
				var c2 := col
				c2.a = 0.28 + 0.25 * z
				_norm.draw_line(pos, pos + Vector2(-2.0, 7.0 + 4.0 * z), c2, 1.0)
	# riscos de vento
	for s in _streaks:
		if s["a"] > 0.0 and s["wait"] <= 0.0:
			var sc := Color(1, 1, 1, s["a"])
			var x: float = s["x"]
			_norm.draw_line(Vector2(x, s["y"]), Vector2(x + s["len"], s["y"] - 1.5), sc, 1.0)


func _draw_add() -> void:
	var kind: String = _theme["kind"]
	var col: Color = _theme["col"]
	# raios de luz diagonais que respiram
	var n := int(_theme["shafts"])
	var sc: Color = _theme["shaft_col"]
	for i in n:
		var x0 := 40.0 + i * 95.0 + sin(_t * 0.15 + i * 2.0) * 14.0
		var a := (0.035 + 0.025 * sin(_t * 0.5 + i * 1.7)) * (0.7 + 0.5 * gust())
		var w := 22.0 + i * 5.0
		_add.draw_colored_polygon(PackedVector2Array([
			Vector2(x0, -4), Vector2(x0 + w, -4), Vector2(x0 + w + 85, 184), Vector2(x0 + 30, 184)]),
			Color(sc.r, sc.g, sc.b, a))
	for p in _parts:
		var z: float = p["z"]
		var pos := Vector2(p["x"], p["y"])
		match kind:
			"embers":
				var tw := 0.5 + 0.5 * sin(_t * 6.0 + p["ph"] * 3.0)
				var c := col.lerp(Color("ffe08a"), tw * 0.5)
				_add.draw_circle(pos, 2.4 * z, Color(c.r, c.g, c.b, 0.07 * tw))
				_add.draw_rect(Rect2(pos, Vector2(1.0, 1.0)), Color(c.r, c.g, c.b, 0.55 + 0.4 * tw))
			"motes":
				var tw2 := 0.5 + 0.5 * sin(_t * 1.6 + p["ph"] * 2.0)
				_add.draw_circle(pos, 4.0 * z, Color(col.r, col.g, col.b, 0.045 * tw2))
				_add.draw_circle(pos, 1.8 * z, Color(col.r, col.g, col.b, 0.14 * tw2))
				_add.draw_rect(Rect2(pos - Vector2(0.5, 0.5), Vector2(1.2, 1.2)), Color(1.0, 0.97, 0.9, 0.5 + 0.4 * tw2))
