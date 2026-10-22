extends Node2D
## Animação do fundo (filho do sprite do fundo, então acompanha o parallax):
## estrelas piscando, sol/lua pulsando, mar brilhando e gaivotas na praia, luzes de
## aviso piscando nas torres, relâmpagos distantes na cidade e estrela cadente na montanha.
## As posições vêm de assets/bg/bg_fx.json (geradas a partir da própria imagem).

const NAMES := ["praia", "torres", "pontes", "cidade", "montanha"]
const GLOWS := {   # fase -> [posição no fundo, raio, cor]
	0: [Vector2(720, 60), 26.0, Color(1.0, 0.95, 0.75)],
	2: [Vector2(880, 55), 24.0, Color(1.0, 0.97, 0.8)],
	3: [Vector2(818, 40), 22.0, Color(1.0, 0.35, 0.25)],
	4: [Vector2(320, 74), 34.0, Color(1.0, 0.8, 0.5)],
}

var _t := 0.0
var _stars: Array = []
var _lights: Array = []
var _lvl := 0
var _rng := RandomNumberGenerator.new()
var _flash := 0.0
var _next_flash := 6.0
var _meteor := {"t": -1.0, "x": 0.0, "y": 0.0}
var _next_meteor := 4.0
var _gulls: Array = []
var _add: Node2D


func _ready() -> void:
	_lvl = Game.current
	_rng.seed = 7 + _lvl
	var f := FileAccess.open("res://assets/bg/bg_fx.json", FileAccess.READ)
	if f != null:
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary and data.has(NAMES[clampi(_lvl, 0, 4)]):
			var d: Dictionary = data[NAMES[clampi(_lvl, 0, 4)]]
			_stars = d.get("stars", [])
			_lights = d.get("lights", [])
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add = Node2D.new()
	_add.material = m
	_add.draw.connect(_draw_add)
	add_child(_add)
	if _lvl == 0 or _lvl == 2:
		for i in (5 if _lvl == 0 else 3):
			_gulls.append({"x": _rng.randf_range(0, 1071), "y": _rng.randf_range(18, 70) if _lvl == 0 else _rng.randf_range(22, 60),
				"v": _rng.randf_range(10, 22), "ph": _rng.randf() * TAU, "s": _rng.randf_range(0.8, 1.3)})


func _process(delta: float) -> void:
	_t += delta
	for g in _gulls:
		g["x"] += g["v"] * delta
		if g["x"] > 1090.0:
			g["x"] = -20.0
	if _lvl == 3:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = _rng.randf_range(9.0, 20.0)
		_flash = maxf(_flash - delta * 3.5, 0.0)
	if _lvl == 4 or _lvl == 1:
		_next_meteor -= delta
		if _next_meteor <= 0.0 and _meteor["t"] < 0.0:
			_meteor = {"t": 0.0, "x": _rng.randf_range(120, 950), "y": _rng.randf_range(6, 40)}
			_next_meteor = _rng.randf_range(7.0, 16.0)
		if _meteor["t"] >= 0.0:
			_meteor["t"] += delta
			if _meteor["t"] > 0.9:
				_meteor["t"] = -1.0
	queue_redraw()
	_add.queue_redraw()


func _draw() -> void:
	# mar da praia: brilhos que correm e uma linha de espuma
	if _lvl == 0:
		for i in 46:
			var x := fposmod(float(i) * 23.7 + _t * (3.0 + float(i % 4)), 1071.0)
			var y := 128.0 + float((i * 7) % 20)
			var a := 0.5 + 0.5 * sin(_t * 1.8 + float(i) * 1.9)
			draw_rect(Rect2(x, y, 3.0 + float(i % 3), 1.0), Color(1, 1, 0.92, 0.18 + 0.32 * a))
		for i in 18:
			var fx := fposmod(float(i) * 61.0 + sin(_t * 0.6 + float(i)) * 6.0, 1071.0)
			draw_rect(Rect2(fx, 149.0 + sin(_t * 1.1 + float(i)) * 0.8, 14.0, 1.0), Color(1, 1, 1, 0.22))
	for g in _gulls:
		var flap := sin(_t * 5.0 + g["ph"])
		var s: float = g["s"]
		var p := Vector2(g["x"], g["y"] + sin(_t * 0.7 + g["ph"]) * 2.0)
		var c := Color(0.16, 0.16, 0.2, 0.85)
		draw_line(p + Vector2(-4, 1.0 - flap * 2.0) * s, p, c, 1.0)
		draw_line(p, p + Vector2(4, 1.0 - flap * 2.0) * s, c, 1.0)


func _draw_add() -> void:
	# estrelas piscando
	for i in _stars.size():
		var s: Array = _stars[i]
		var tw := 0.5 + 0.5 * sin(_t * (1.2 + float(i % 5) * 0.5) + float(i) * 2.3)
		var a := 0.15 + 0.7 * tw * tw
		var p := Vector2(float(s[0]), float(s[1]))
		_add.draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 1, a))
		if tw > 0.93:     # brilho em cruz no pico
			_add.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(1, 1, 1, 0.35))
			_add.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), Color(1, 1, 1, 0.35))
	# sol ou lua pulsando
	if GLOWS.has(_lvl):
		var gl: Array = GLOWS[_lvl]
		var pos: Vector2 = gl[0]
		var r: float = gl[1]
		var c: Color = gl[2]
		var pulse := 0.85 + 0.15 * sin(_t * 0.8)
		for k in 6:
			_add.draw_circle(pos, r * (1.0 - float(k) * 0.14) * pulse, Color(c.r, c.g, c.b, 0.03))
	# luzes de aviso das torres
	for i in _lights.size():
		var l: Array = _lights[i]
		var on := fmod(_t + float(i) * 0.37, 1.8) < 0.35
		var p2 := Vector2(float(l[0]), float(l[1]))
		if on:
			_add.draw_circle(p2, 3.5, Color(1.0, 0.15, 0.1, 0.12))
			_add.draw_rect(Rect2(p2, Vector2(1, 1)), Color(1.0, 0.45, 0.35, 0.95))
		else:
			_add.draw_rect(Rect2(p2, Vector2(1, 1)), Color(0.5, 0.1, 0.1, 0.35))
	# relâmpago distante (cidade)
	if _flash > 0.0:
		var fl := _flash * (0.6 + 0.4 * sin(_t * 60.0))
		_add.draw_rect(Rect2(0, 0, 1071, 130), Color(0.55, 0.62, 0.9, 0.12 * fl))
		_add.draw_rect(Rect2(0, 90, 1071, 60), Color(0.5, 0.6, 1.0, 0.07 * fl))
	# estrela cadente
	if _meteor["t"] >= 0.0:
		var k: float = float(_meteor["t"]) / 0.9
		var head := Vector2(float(_meteor["x"]), float(_meteor["y"])) + Vector2(60.0, 22.0) * k
		for j in 10:
			var tp := head - Vector2(6.0, 2.2) * float(j)
			_add.draw_rect(Rect2(tp, Vector2(1, 1)), Color(1, 0.95, 0.85, (1.0 - float(j) / 10.0) * (1.0 - k)))
