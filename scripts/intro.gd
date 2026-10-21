extends Control
## Cena de abertura: Saeda acorda na floresta perto da praia, e as memórias
## (fadinhas azuis) que a rodeavam vão embora. Qualquer tecla de confirmar pula.

# poses dela acordando: deitada -> esfrega o olho -> ajoelhada -> apoia a mão -> em pé
const WAKE := [
	preload("res://assets/intro/wake_0_lying.png"),
	preload("res://assets/intro/wake_1_rub.png"),
	preload("res://assets/intro/wake_2_kneel.png"),
	preload("res://assets/intro/wake_3_lean.png"),
	preload("res://assets/intro/wake_4_stand.png"),
]
const WAKE_AT := [0.0, 10.2, 12.6, 15.6, 17.0]   # quando cada pose começa
const WAKE_SCALE := 0.46
const FAR := preload("res://assets/intro/intro_far.png")
const MID := preload("res://assets/intro/intro_mid.png")
const FORE := preload("res://assets/intro/intro_fore.png")

const TOTAL := 27.0
const GROUND := Vector2(150, 142)     # onde ela dorme (centro dos pés)
const MEM_COUNT := 8
const BLUE := Color("7cc4ff")
const BLUE_DEEP := Color("3a7cff")

# (tempo, texto, duração)
const LINES := [
	[10.6, "...onde eu estou?", 2.2],
	[13.0, "Minhas memórias...", 2.4],
	[17.6, "Esperem... não vão embora.", 3.2],
	[22.0, "Eu vou encontrar vocês.", 3.4],
]

var _t := 0.0
var _world: Node2D
var _body: Node2D
var _mem: Node2D
var _lid_top: ColorRect
var _lid_bot: ColorRect
var _fade: ColorRect
var _text: Label
var _hint: Label
var _skipping := false
var _done := false
var _wisps: Array = []
var _motes: Array = []
var _wake_sprites: Array = []
var _stage := 0
var _line_i := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play_music("dusty", 3.0)

	_world = Node2D.new()
	_world.position = Vector2(160, 110)
	add_child(_world)
	var root := Node2D.new()
	root.position = Vector2(-160, -110)
	_world.add_child(root)
	_add_tex(root, FAR)
	_add_tex(root, MID)

	_body = Node2D.new()
	_body.position = GROUND
	for i in WAKE.size():
		var sp := Sprite2D.new()
		sp.texture = WAKE[i]
		sp.centered = false
		var sz: Vector2 = WAKE[i].get_size()
		sp.offset = Vector2(-sz.x * 0.5, -sz.y)
		sp.scale = Vector2(WAKE_SCALE, WAKE_SCALE)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sp.modulate.a = 1.0 if i == 0 else 0.0
		_body.add_child(sp)
		_wake_sprites.append(sp)
	_add_tex(root, FORE)
	root.add_child(_body)

	# memórias: fadinhas azuis, em cima de tudo, com brilho aditivo
	_mem = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mem.material = add
	_mem.draw.connect(_draw_memories)
	root.add_child(_mem)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in MEM_COUNT:
		_wisps.append({
			"phase": r.randf() * TAU,
			"orbit": Vector2(r.randf_range(18, 46), r.randf_range(8, 18)),
			"cy": r.randf_range(96, 124),
			"speed": r.randf_range(0.5, 0.9) * (1 if i % 2 == 0 else -1),
			"leave": 14.2 + i * 0.95,
			"state": 0,         # 0 = orbitando, 1 = indo embora, 2 = sumiu
			"t_out": 0.0,
			"pos": Vector2(GROUND.x, 110),
			"trail": [],
			"size": r.randf_range(0.8, 1.2),
		})
	for i in 26:
		_motes.append(Vector2(r.randf_range(0, 320), r.randf_range(20, 150)))

	# pálpebras (abrir os olhos) e fade
	_lid_top = _rect(Color.BLACK)
	_lid_bot = _rect(Color.BLACK)
	_fade = _rect(Color.BLACK)
	_fade.color.a = 1.0

	_text = Label.new()
	_text.position = Vector2(0, 150)
	_text.size = Vector2(320, 20)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_text, 10)
	_text.modulate.a = 0.0
	add_child(_text)

	_hint = Label.new()
	_hint.text = "ENTER: pular"
	_hint.position = Vector2(236, 168)
	_style(_hint, 7)
	_hint.modulate.a = 0.0
	add_child(_hint)


func _add_tex(parent: Node, tex: Texture2D) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(320, 180)
	add_child(r)
	return r


func _style(lab: Label, size: int) -> void:
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_constant_override("outline_size", 3)
	lab.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.09, 0.95))
	lab.add_theme_color_override("font_color", Color("f2ecd8"))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if _skipping or _done:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel"):
		_finish(0.4)


func _finish(fade_time: float) -> void:
	_skipping = true
	Sfx.play("confirm", -8.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	tw.tween_callback(func() -> void:
		_done = true
		Game.go_map())


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var t := _t

	# câmera: recuo lento (estilo Ocarina of Time)
	var z := lerpf(1.22, 1.0, _ease(t / 24.0))
	_world.scale = Vector2(z, z)

	# abertura inicial da tela e das pálpebras (dois piscares, depois abre)
	if not _skipping:
		_fade.color.a = 1.0 - _ease((t - 0.4) / 2.4)
	var open := 0.0
	if t > 3.0:
		open = 0.30 * _ease((t - 3.0) / 0.8)
	if t > 4.2:
		open = lerpf(0.30, 0.0, _ease((t - 4.2) / 0.5))
	if t > 5.2:
		open = 1.0 * _ease((t - 5.2) / 1.8)
	# 0 = fechadas (preto cobrindo), 1 = abertas
	var cover := 1.0 - open if t > 3.0 else 1.0
	_lid_top.size = Vector2(320, 90 * cover)
	_lid_top.position = Vector2.ZERO
	_lid_bot.size = Vector2(320, 90 * cover)
	_lid_bot.position = Vector2(0, 180 - 90 * cover)
	_lid_top.visible = cover > 0.001
	_lid_bot.visible = cover > 0.001

	# a personagem: troca de pose com dissolução suave
	var want := 0
	for i in WAKE_AT.size():
		if t >= WAKE_AT[i]:
			want = i
	if want != _stage:
		var old: Sprite2D = _wake_sprites[_stage]
		var nu: Sprite2D = _wake_sprites[want]
		var tw := create_tween().set_parallel(true)
		tw.tween_property(old, "modulate:a", 0.0, 0.5)
		tw.tween_property(nu, "modulate:a", 1.0, 0.5)
		_stage = want
		Sfx.play("step", -16.0, 0.6 + 0.1 * want)
	# respiração / balanço leve; antes de acordar, um tremorzinho
	var cur: Sprite2D = _wake_sprites[_stage]
	var br := 1.0 + 0.012 * sin(t * 1.7)
	cur.scale = Vector2(WAKE_SCALE, WAKE_SCALE * br)
	if _stage == 0 and t > 8.8 and t < 10.2:
		cur.position.x = sin(t * 28.0) * 0.4
	else:
		cur.position.x = 0.0
	if _stage == 1:
		cur.position.y = -absf(sin(t * 5.0)) * 0.6   # esfregando o olho

	# falas
	var shown := false
	for ln in LINES:
		var a: float = ln[0]
		var d: float = ln[2]
		if t >= a and t < a + d:
			_text.text = ln[1]
			var fin := clampf((t - a) / 0.6, 0.0, 1.0)
			var fout := clampf((a + d - t) / 0.6, 0.0, 1.0)
			_text.modulate.a = minf(fin, fout)
			shown = true
	if not shown:
		_text.modulate.a = 0.0
	_hint.modulate.a = clampf((t - 1.5) / 1.0, 0.0, 0.5) * (0.0 if _skipping else 1.0)

	_update_wisps(delta, t)
	_mem.queue_redraw()

	if t >= TOTAL - 1.4 and not _skipping:
		_finish(1.4)


func _update_wisps(delta: float, t: float) -> void:
	var glow := _ease((t - 1.5) / 4.0)
	for w in _wisps:
		if w.state == 2:
			continue
		var pos: Vector2
		if w.state == 0:
			var a: float = w.phase + t * w.speed
			pos = Vector2(GROUND.x + cos(a) * w.orbit.x, w.cy + sin(a * 1.3) * w.orbit.y)
			if t >= w.leave:
				w.state = 1
				w.t_out = 0.0
				w.from = pos
				Sfx.play("crystal", -16.0, randf_range(0.8, 1.2))
		else:
			w.t_out += delta
			var k: float = w.t_out
			# sobe em curva em direção ao mar / céu, acelerando
			var dir := Vector2(1.0, -0.55).normalized()
			var wob := Vector2(0, sin(k * 3.0 + w.phase) * 6.0)
			pos = w.from + dir * (k * k * 9.0 + k * 22.0) + wob
			if k > 5.0:
				w.state = 2
		w.pos = pos
		w.trail.push_front(pos)
		if w.trail.size() > 14:
			w.trail.pop_back()
		w["glow"] = glow


func _draw_memories() -> void:
	var t := _t
	# raios de luz do sol
	var ray := _ease((t - 5.0) / 4.0) * 0.07
	for i in 4:
		var x0 := 200.0 + i * 22.0
		_mem.draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 14, 0), Vector2(x0 - 50, 140), Vector2(x0 - 78, 140)]), Color(1.0, 0.9, 0.6, ray))
	# partículas de poeira / pólen
	for i in _motes.size():
		var m: Vector2 = _motes[i]
		var p := Vector2(fposmod(m.x + t * (3.0 + (i % 5)) , 320.0), m.y + sin(t * 0.7 + i) * 5.0)
		_mem.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.95, 0.75, 0.35 * _ease((t - 4.0) / 3.0)))
	for w in _wisps:
		if w.state == 2:
			continue
		var gl: float = w.get("glow", 0.0)
		var fade := 1.0
		if w.state == 1:
			fade = clampf(1.0 - (w.t_out - 3.2) / 1.8, 0.0, 1.0)
		var tw := 0.75 + 0.25 * sin(t * 5.0 + w.phase)
		var tr: Array = w.trail
		for i in tr.size():
			var k := 1.0 - float(i) / tr.size()
			var c := BLUE_DEEP
			c.a = 0.35 * k * k * gl * fade * (1.0 if w.state == 1 else 0.4)
			_mem.draw_circle(tr[i], 1.1 * k * w.size, c)
		var p: Vector2 = w.pos
		for r in [5.0, 3.4, 2.0]:
			var c := BLUE
			c.a = 0.10 * gl * fade * tw * (6.0 - r) / 3.0
			_mem.draw_circle(p, r * w.size * 1.9, c)
		_mem.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.9, 0.97, 1.0, minf(1.0, gl * fade * 1.4)))
