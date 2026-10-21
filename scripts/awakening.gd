extends Control
## Despertar do poder: com todas as memórias, Saeda abre a porta da montanha,
## a luz azul a atinge e o olho verde acende. Depois vem a fase final (dash infinito).
## Enter / Z pula.

const BG := preload("res://assets/bg/bg_montanha.png")
const STAND := preload("res://assets/intro/wake_4_stand.png")
const EYE_FRAMES := [
	preload("res://assets/intro/eye_5.png"), preload("res://assets/intro/eye_6.png"),
	preload("res://assets/intro/eye_7.png"), preload("res://assets/intro/eye_8.png"),
	preload("res://assets/intro/eye_9.png"),
]
const FACE_FRAMES := [
	preload("res://assets/intro/face_0.png"), preload("res://assets/intro/face_1.png"),
	preload("res://assets/intro/face_2.png"), preload("res://assets/intro/face_3.png"),
	preload("res://assets/intro/face_4.png"),
]
const FACE_SCALE := 320.0 / 550.0
const IRIS_L := Vector2(116.0, 84.4)
const IRIS_R := Vector2(246.0, 83.2)

const DOOR_C := Vector2(232, 148)      # base da porta (centro)
const SAEDA := Vector2(128, 148)       # pés da Saeda
const TOTAL := 24.0
const DEMO_AT := 3.2      # segundos de olho antes da demonstração do poder
const BLUE := Color("7cc4ff")

const LINES := [
	[1.4, "As memórias... elas me guiam.", 2.6],
	[8.4, "O poder das memórias despertou.", 2.6],
	[11.6, "Dash infinito. Agora nada me segura.", 3.4],
]

var _t := 0.0
var _stage: Node2D
var _fx: Node2D
var _eyes: Node2D
var _face: Sprite2D
var _me: Sprite2D
var _demo := false
var _demo_t := 0.0
var _ghosts: Array = []
var _demo_pos := Vector2.ZERO
var _shake := 0.0
var _rings: Array = []
var _flash: ColorRect
var _fade: ColorRect
var _text: Label
var _hint: Label
var _wisps: Array = []
var _door_glow := 0.0
var _hit := 0
var _going := false
var _done := false
var _beam := 0.0
var _eye_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play_music("last", 2.0)
	var sky := ColorRect.new()
	sky.color = Color("4e3a68")
	sky.size = Vector2(320, 180)
	add_child(sky)
	var bg := Sprite2D.new()
	bg.texture = BG
	bg.centered = false
	bg.position = Vector2(-380, -8)
	add_child(bg)
	_stage = Node2D.new()
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	var me := Sprite2D.new()
	_me = me
	me.texture = STAND
	me.centered = false
	me.offset = Vector2(-STAND.get_width() * 0.5, -STAND.get_height())
	me.scale = Vector2(0.5, 0.5)
	me.position = SAEDA
	me.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(me)
	_fx = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = add
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var n := clampi(Game.memory_status().x, 3, 10)
	for i in n:
		_wisps.append({"i": i, "n": n, "state": 0, "t": 0.0, "from": Vector2.ZERO, "pos": Vector2.ZERO,
			"go": 3.8 + i * 0.45})
	_eyes = Node2D.new()
	_eyes.visible = false
	var bgd := ColorRect.new()
	bgd.color = Color("0b0612")
	bgd.size = Vector2(320, 180)
	_eyes.add_child(bgd)
	_face = Sprite2D.new()
	_face.texture = FACE_FRAMES[0]
	_face.centered = false
	_face.scale = Vector2(FACE_SCALE, FACE_SCALE)
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_eyes.add_child(_face)
	add_child(_eyes)
	var eyefx := Node2D.new()
	eyefx.material = add
	eyefx.draw.connect(func() -> void: _draw_eye_glow(eyefx))
	eyefx.name = "EyeFx"
	eyefx.visible = false
	add_child(eyefx)
	_flash = _rect(Color(0.8, 0.92, 1.0, 0.0))
	_fade = _rect(Color.BLACK)
	_text = Label.new()
	_text.position = Vector2(0, 152)
	_text.size = Vector2(320, 20)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_text, 10)
	_text.modulate.a = 0.0
	add_child(_text)
	_hint = Label.new()
	_hint.text = "ENTER: pular"
	_hint.position = Vector2(236, 168)
	_style(_hint, 7)
	_hint.modulate.a = 0.4
	add_child(_hint)


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.size = Vector2(320, 180)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _style(lab: Label, size: int) -> void:
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_constant_override("outline_size", 3)
	lab.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.1, 0.95))
	lab.add_theme_color_override("font_color", Color("f2ecd8"))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if _going or _done:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel"):
		_leave(0.3)


func _leave(t: float) -> void:
	_going = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	tw.tween_callback(func() -> void:
		_done = true
		Game.awakened = true
		Game.save_progress()
		get_tree().change_scene_to_file(Game.LEVEL_SCENE))


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _head() -> Vector2:
	return SAEDA + Vector2(0, -34)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var t := _t
	if not _going:
		_fade.color.a = 1.0 - _ease(t / 1.2)
	# memórias: coroa -> voam para a porta
	for w in _wisps:
		if w.state == 0:
			var a: float = t * 1.2 + TAU * w.i / w.n
			w.pos = _head() + Vector2(cos(a) * 11.0, sin(a) * 3.5 - 4.0)
			if t >= w.go:
				w.state = 1
				w.t = 0.0
				w.from = w.pos
				Sfx.play("crystal", -10.0, 0.8 + 0.08 * w.i)
		elif w.state == 1:
			w.t += delta
			var k: float = _ease(w.t / 1.4)
			var target := DOOR_C + Vector2(0, -26)
			var mid: Vector2 = (w.from + target) * 0.5 + Vector2(0, -34)
			var p0: Vector2 = w.from.lerp(mid, k)
			var p1: Vector2 = mid.lerp(target, k)
			w.pos = p0.lerp(p1, k)
			if k >= 1.0:
				w.state = 2
				_hit += 1
				_door_glow = minf(1.0, _door_glow + 1.0 / w.n)
				Sfx.play("unlock", -12.0, 0.9 + 0.1 * _hit)
	_door_glow = lerpf(_door_glow, 1.0 if _hit >= _wisps.size() else _door_glow, 0.0)
	# raio da porta até ela e clarão
	if _hit >= _wisps.size() and _beam == 0.0 and t > 3.8:
		_beam = 0.001
	if _beam > 0.0:
		_beam += delta
	if _beam > 0.0 and _beam < 1.3:
		pass
	if _beam >= 1.0 and not _eyes.visible and not _demo:
		_eyes.visible = true
		get_node("EyeFx").visible = true
		Sfx.play("finish", -4.0, 0.8)
		_flash.color.a = 1.0
	if _eyes.visible:
		_eye_t += delta
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.1)
		_eyes.position = Vector2(0, 0)
		# abre os olhos: fechados, uma tremida, depois os quadros da folha de sprites
		var fi := 0
		if _eye_t > 0.7:
			fi = clampi(int((_eye_t - 0.7) / 0.14), 0, FACE_FRAMES.size() - 1)
		_face.texture = FACE_FRAMES[fi]
		var dim := _ease((_eye_t - 1.3) / 1.6)
		_face.modulate = Color.WHITE.lerp(Color(0.62, 0.72, 0.66), dim)
		if _eye_t > 0.7 and _eye_t < 0.9:
			_shake = 1.2
		if _eye_t >= DEMO_AT:
			_start_demo()
	if _demo:
		_update_demo(delta)
	_shake = maxf(0.0, _shake - delta * 4.0)
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	# falas
	var shown := false
	for ln in LINES:
		var a2: float = ln[0]
		var d: float = ln[2]
		if t >= a2 and t < a2 + d:
			_text.text = ln[1]
			_text.modulate.a = minf(clampf((t - a2) / 0.5, 0.0, 1.0), clampf((a2 + d - t) / 0.5, 0.0, 1.0))
			shown = true
	if not shown:
		_text.modulate.a = 0.0
	if ((_demo and _demo_t > 5.6) or t >= TOTAL) and not _going:
		_leave(1.0)
	_stage.queue_redraw()
	_fx.queue_redraw()
	get_node("EyeFx").queue_redraw()


func _start_demo() -> void:
	_eyes.visible = false
	get_node("EyeFx").visible = false
	_demo = true
	_demo_t = 0.0
	_demo_pos = SAEDA
	_flash.color = Color(0.7, 1.0, 0.85, 1.0)
	_shake = 3.0
	_me.modulate = Color(0.8, 1.0, 0.88)
	Sfx.play("finish", -2.0, 1.2)
	Sfx.play("unlock", -4.0, 1.7)
	_rings.append({"c": SAEDA + Vector2(0, -18), "t": 0.0})


const DASHES := [Vector2(176, 112), Vector2(132, 76), Vector2(190, 44), Vector2(236, 36)]


func _update_demo(delta: float) -> void:
	_demo_t += delta
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.6)
	var base := SAEDA
	var pos := base
	# carga: ela levita tremendo, depois 4 dashes verdes em zigue-zague para cima
	var charge := _ease(_demo_t / 1.1)
	pos = base + Vector2(0, -8.0 * charge)
	var from := base + Vector2(0, -8.0)
	for i in DASHES.size():
		var t0 := 1.3 + i * 0.5
		var k := clampf((_demo_t - t0) / 0.16, 0.0, 1.0)
		if _demo_t >= t0:
			pos = from.lerp(DASHES[i], k)
			if k > 0.0 and k < 1.0:
				_ghosts.append({"p": pos, "a": 0.85})
				if k < 0.2:
					Sfx.play("dash", -6.0, 1.0 + 0.12 * i)
					_shake = 1.6
					_rings.append({"c": pos + Vector2(0, -18), "t": 0.0})
		from = DASHES[i]
	if _demo_t < 1.1:
		pos += Vector2(randf_range(-0.6, 0.6), 0.0)
	_demo_pos = pos
	_me.position = pos
	for g in _ghosts:
		g.a -= delta * 2.0
	_ghosts = _ghosts.filter(func(q): return q.a > 0.0)
	for r in _rings:
		r.t += delta
	_rings = _rings.filter(func(q): return q.t < 0.7)


func _draw_stage() -> void:
	if _eyes.visible:
		return
	# chão e rocha da montanha
	var rock := Color("2a2440")
	var rock_l := Color("3d3558")
	_stage.draw_colored_polygon(PackedVector2Array([Vector2(0, 150), Vector2(0, 180), Vector2(320, 180), Vector2(320, 150)]), Color("2e2a48"))
	_stage.draw_rect(Rect2(0, 148, 320, 2), Color("4a4468"))
	_stage.draw_colored_polygon(PackedVector2Array([
		Vector2(176, 150), Vector2(188, 96), Vector2(206, 70), Vector2(232, 44), Vector2(262, 62), Vector2(288, 84), Vector2(320, 76), Vector2(320, 150)]), rock)
	_stage.draw_colored_polygon(PackedVector2Array([
		Vector2(232, 44), Vector2(262, 62), Vector2(250, 60), Vector2(226, 56)]), rock_l)
	# moldura e porta
	var d := DOOR_C
	_stage.draw_rect(Rect2(d.x - 22, d.y - 64, 44, 64), Color("4a4468"))
	_stage.draw_rect(Rect2(d.x - 18, d.y - 60, 36, 60), Color("1a1630"))
	_stage.draw_rect(Rect2(d.x - 14, d.y - 66, 28, 6), Color("4a4468"))
	_stage.draw_rect(Rect2(d.x - 22, d.y - 64, 3, 64), Color("5e5886"))
	var g := _door_glow
	var inner := Color(0.05 + 0.3 * g, 0.08 + 0.5 * g, 0.2 + 0.8 * g, 1.0)
	_stage.draw_rect(Rect2(d.x - 14, d.y - 56, 28, 56), inner)
	_stage.draw_rect(Rect2(d.x - 10, d.y - 60, 20, 4), inner)
	# runas
	for i in 5:
		var on := g * 5.0 > i
		var c := Color(0.45, 0.75, 1.0, 0.95) if on else Color(0.2, 0.2, 0.35, 0.8)
		_stage.draw_rect(Rect2(d.x - 20 + (i % 2) * 38, d.y - 52 + (i / 2) * 18, 2, 6), c)
	_stage.draw_rect(Rect2(d.x - 1, d.y - 63, 2, 3), Color(0.45, 0.75, 1.0, 0.4 + 0.6 * g))
	# degrau
	_stage.draw_rect(Rect2(d.x - 26, d.y - 2, 52, 4), Color("3d3558"))


func _draw_fx() -> void:
	if _eyes.visible:
		return
	if _demo:
		_draw_demo_fx()
	var t := _t
	var g := _door_glow
	if g > 0.0:
		var pulse := 0.8 + 0.2 * sin(t * 6.0)
		_fx.draw_circle(DOOR_C + Vector2(0, -28), (22.0 + 20.0 * g) * pulse, Color(0.3, 0.6, 1.0, 0.10 * g))
		_fx.draw_circle(DOOR_C + Vector2(0, -28), 12.0 * g, Color(0.6, 0.85, 1.0, 0.2 * g))
	for w in _wisps:
		if w.state == 2:
			continue
		var p: Vector2 = w.pos
		if p == Vector2.ZERO:
			continue
		_fx.draw_circle(p, 6.0, Color(0.23, 0.49, 1.0, 0.10))
		_fx.draw_circle(p, 3.4, Color(0.49, 0.77, 1.0, 0.28))
		_fx.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.93, 0.98, 1.0, 1.0))
	if _beam > 0.0 and not _demo:
		# raio de luz da porta até a Saeda
		var k := clampf(_beam / 1.0, 0.0, 1.0)
		var a := DOOR_C + Vector2(-8, -30)
		var b := a.lerp(_head(), k)
		for i in 3:
			_fx.draw_line(a, b, Color(0.5, 0.8, 1.0, 0.25 * (3 - i) / 3.0), 7.0 - i * 2.5)
		_fx.draw_circle(b, 8.0 + 4.0 * sin(t * 20.0), Color(0.6, 0.9, 1.0, 0.4))


func _draw_demo_fx() -> void:
	var t := _demo_t
	var pulse := 0.8 + 0.2 * sin(t * 18.0)
	var c := _demo_pos + Vector2(0, -18)
	var charge := _ease(t / 1.1)
	_fx.draw_circle(c, (14.0 + 10.0 * charge) * pulse, Color(0.1, 0.9, 0.4, 0.10))
	_fx.draw_circle(c, (8.0 + 6.0 * charge) * pulse, Color(0.3, 1.0, 0.55, 0.16))
	# partículas verdes subindo enquanto ela carrega
	for i in 18:
		var ph := float(i) * 0.37
		var yy := fposmod(t * (30.0 + i * 3.0) + ph * 40.0, 44.0)
		var xx := sin(ph * 9.0 + t * 3.0) * (10.0 + 4.0 * charge)
		_fx.draw_rect(Rect2(c + Vector2(xx, 12.0 - yy), Vector2(1, 2)), Color(0.6, 1.0, 0.7, 0.8 * charge))
	# rastro verde dos dashes (cópias da Saeda)
	var w := float(STAND.get_width()) * 0.5
	var h := float(STAND.get_height()) * 0.5
	for g in _ghosts:
		var gp: Vector2 = g.p
		_fx.draw_texture_rect(STAND, Rect2(gp.x - w * 0.5, gp.y - h, w, h), false, Color(0.2, 1.0, 0.5, 0.7 * g.a))
	# anéis de choque verdes
	for r in _rings:
		var k: float = r.t / 0.7
		_fx.draw_arc(r.c, 6.0 + 54.0 * k, 0.0, TAU, 40, Color(0.4, 1.0, 0.6, 0.9 * (1.0 - k)), 1.5)
		_fx.draw_arc(r.c, 3.0 + 30.0 * k, 0.0, TAU, 32, Color(0.8, 1.0, 0.9, 0.7 * (1.0 - k)), 1.0)


func _draw_eye_glow(fx: Node2D) -> void:
	var t := _eye_t
	# posições das íris na imagem (400x225 * 0.8)
	var iris := [IRIS_L, IRIS_R]
	var grow := _ease((t - 1.3) / 1.6)
	var pulse := 0.85 + 0.15 * sin(t * 6.0)
	for c in iris:
		fx.draw_circle(c, 52.0 * grow * pulse, Color(0.1, 0.9, 0.4, 0.05 * grow))
		fx.draw_circle(c, 30.0 * grow * pulse, Color(0.2, 1.0, 0.5, 0.10 * grow))
		fx.draw_circle(c, 13.0 * grow, Color(0.4, 1.0, 0.6, 0.55 * grow))
		fx.draw_circle(c, 4.0 * grow, Color(0.85, 1.0, 0.9, 0.9 * grow))
	# raios horizontais de luz verde saindo dos olhos
	for c in iris:
		for k in range(-3, 4):
			var fade := 1.0 - absf(k) / 4.0
			fx.draw_line(c + Vector2(-150.0 * grow, k * 7.0), c + Vector2(150.0 * grow, k * 7.0 - 1.0), Color(0.2, 0.8, 0.45, 0.10 * fade * grow), 2.0)
	# fios de energia azul cruzando a tela
	for i in 26:
		var seed_v := float(i) * 12.9898
		var y := fposmod(sin(seed_v) * 43758.5453, 1.0) * 180.0
		var sp := 80.0 + fposmod(sin(seed_v * 1.7) * 9871.3, 1.0) * 160.0
		var x := fposmod(t * sp + fposmod(sin(seed_v * 3.1) * 5123.7, 1.0) * 420.0, 460.0) - 70.0
		var len := 16.0 + fposmod(sin(seed_v * 2.3) * 721.1, 1.0) * 26.0
		var a := 0.5 * grow
		fx.draw_line(Vector2(x, y), Vector2(x - len, y + 2.0), Color(0.5, 0.8, 1.0, a), 1.0)
		fx.draw_rect(Rect2(x, y, 1.5, 1.5), Color(0.9, 0.97, 1.0, a))
