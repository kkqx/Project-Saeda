extends Control
## Créditos finais: Saeda e o gatinho no topo da montanha, o sol nascendo,
## as memórias girando e o texto subindo. Edite a lista CREDITS para mudar os nomes.

const BG := preload("res://assets/bg/bg_montanha.png")
const STAND := preload("res://assets/intro/wake_4_stand.png")
const CAT := preload("res://assets/cat/cat.png")
const LOGO := preload("res://assets/title/logo_flores.png")
const SERIF := preload("res://assets/fonts/Lora.ttf")

# ["título", "nome"]  ·  título vazio = só uma linha de texto  ·  ["", ""] = espaço
const CREDITS := [
	["@LOGO", ""],
	["", ""],
	["Músicas", "Dusty Horizon"],
	["", "Última luz no deserto"],
	["", "Last light in desert"],
	["", ""],
	["Feito com", "Godot Engine 4.3"],
	["", ""],
	["Personagens", "Saeda"],
	["", "e o seu gatinho"],
	["", ""],
	["@STATS", ""],
	["", ""],
	["", ""],
	["Obrigado por jogar", ""],
	["", ""],
	["FIM", ""],
]

const SPEED := 15.0
const LINE_H := 13.0
const LEFT_W := 170.0

var _t := 0.0
var _scroll: Control
var _fade: ColorRect
var _fx: Node2D
var _cat: Sprite2D
var _motes: Array = []
var _end_y := 0.0
var _leaving := false
var _total_mem := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play_music("dusty", 2.0)
	Sfx.play("creditos", -6.0)
	var sky := ColorRect.new()
	sky.color = Color("4e3a68")
	sky.size = Vector2(320, 180)
	add_child(sky)
	var bg := Sprite2D.new()
	bg.texture = BG
	bg.centered = false
	bg.position = Vector2(-330, -10)
	add_child(bg)
	var stage := Node2D.new()
	stage.draw.connect(func() -> void:
		stage.draw_colored_polygon(PackedVector2Array([
			Vector2(150, 180), Vector2(172, 150), Vector2(210, 140), Vector2(260, 142), Vector2(300, 150), Vector2(320, 148), Vector2(320, 180)]), Color("2a2440"))
		stage.draw_colored_polygon(PackedVector2Array([
			Vector2(172, 150), Vector2(210, 140), Vector2(260, 142), Vector2(300, 150), Vector2(260, 146), Vector2(210, 145)]), Color("4a4468")))
	add_child(stage)
	var me := Sprite2D.new()
	me.texture = STAND
	me.centered = false
	me.offset = Vector2(-STAND.get_width() * 0.5, -STAND.get_height())
	me.scale = Vector2(0.5, 0.5)
	me.position = Vector2(236, 146)
	me.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(me)
	_cat = Sprite2D.new()
	_cat.texture = CAT
	_cat.region_enabled = true
	_cat.region_rect = Rect2(0, 0, 72, 64)
	_cat.centered = false
	_cat.offset = Vector2(-36, -62)
	_cat.scale = Vector2(0.3, 0.3)
	_cat.position = Vector2(262, 147)
	_cat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_cat)
	_fx = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = add
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 30:
		_motes.append(Vector2(r.randf_range(0, 320), r.randf_range(0, 180)))
	_total_mem = clampi(Game.memory_status().x, 3, 10)
	# faixa escura suave atrás do texto
	var shade := TextureRect.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	gr.colors = PackedColorArray([Color(0.04, 0.03, 0.1, 0.62), Color(0.04, 0.03, 0.1, 0.45), Color(0.04, 0.03, 0.1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 64
	gt.height = 8
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(LEFT_W + 30, 180)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_build_text()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = Vector2(320, 180)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _stats() -> String:
	var deaths := 0
	for k in Game.progress.keys():
		deaths += int(Game.progress[k].get("deaths", 0))
	var m := Game.memory_status()
	return "Memórias  %d / %d\nMortes  %d" % [m.x, m.y, deaths]


func _build_text() -> void:
	_scroll = Control.new()
	_scroll.position = Vector2(0, 180)
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll)
	var y := 0.0
	for row in CREDITS:
		var title: String = row[0]
		var name_t: String = row[1]
		if title == "@STATS":
			var st := _label(_stats(), 9, Color("bfe3ff"))
			st.position = Vector2(0, y)
			_scroll.add_child(st)
			y += LINE_H * 2.0
			continue
		if title == "@LOGO":
			var lg := TextureRect.new()
			lg.texture = LOGO
			lg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			lg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lg.stretch_mode = TextureRect.STRETCH_SCALE
			lg.size = Vector2(140.0, 140.0 * float(LOGO.get_height()) / float(LOGO.get_width()))
			lg.position = Vector2((LEFT_W - 140.0) * 0.5, y)
			lg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scroll.add_child(lg)
			y += lg.size.y
			continue
		if title == "" and name_t == "":
			y += LINE_H * 0.6
			continue
		if title != "":
			var big := title == "PROJECT SAEDA" or title == "FIM" or title == "Obrigado por jogar"
			var lt := _label(title, 14 if big else 7, Color("f2ecd8") if big else Color("c9b8e8"))
			lt.position = Vector2(0, y)
			_scroll.add_child(lt)
			y += LINE_H * (1.5 if big else 0.9)
		if name_t != "":
			var ln := _label(name_t, 9, Color("f2ecd8"))
			ln.position = Vector2(0, y)
			_scroll.add_child(ln)
			y += LINE_H
	_end_y = y


func _label(text: String, size: int, col: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.size = Vector2(LEFT_W, 20)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_override("font", SERIF)
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_constant_override("outline_size", 3)
	lab.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.1, 0.95))
	lab.add_theme_color_override("font_color", col)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _t < 2.0:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel"):
		_leave(0.6)


func _leave(t: float) -> void:
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	tw.tween_callback(func() -> void: Game.go_title())


func _process(delta: float) -> void:
	_t += delta
	var speed := SPEED * (3.0 if Input.is_action_pressed("move_down") else 1.0)
	# o texto sobe até a última linha ficar no meio da tela, e para
	var stop_y := 90.0 - _end_y
	_scroll.position.y = maxf(180.0 - _t * speed, stop_y)
	if not _leaving:
		_fade.color.a = maxf(0.0, 1.0 - _t / 1.6)
		if _scroll.position.y <= stop_y and _t > (180.0 - stop_y) / SPEED + 5.0:
			_leave(1.6)
	# gatinho: pisca e balança o rabo
	var f := int(_t / 0.8) % 2
	if fmod(_t, 3.4) < 0.14:
		f = 2
	_cat.region_rect = Rect2(f * 72, 0, 72, 64)
	_fx.queue_redraw()


func _draw_fx() -> void:
	var t := _t
	# raios do sol da manhã
	for i in 3:
		var x0 := 20.0 + i * 40.0
		_fx.draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 16, 0), Vector2(x0 + 120, 150), Vector2(x0 + 70, 150)]), Color(1.0, 0.85, 0.6, 0.035))
	# coroa de memórias sobre as duas
	var c := Vector2(249, 108)
	for i in _total_mem:
		var a: float = t * 0.9 + TAU * i / _total_mem
		var p := c + Vector2(cos(a) * (26.0 + 2.0 * sin(t + i)), sin(a) * 9.0 - 4.0 + sin(t * 1.7 + i) * 2.0)
		_fx.draw_circle(p, 6.0, Color(0.23, 0.49, 1.0, 0.10))
		_fx.draw_circle(p, 3.4, Color(0.49, 0.77, 1.0, 0.28))
		_fx.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.93, 0.98, 1.0, 1.0))
	for m in _motes:
		var p := Vector2(fposmod(m.x + t * 5.0, 320.0), fposmod(m.y - t * 7.0, 180.0))
		_fx.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.95, 0.8, 0.45))
