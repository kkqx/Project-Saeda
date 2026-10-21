extends Control
## Tela inicial: "Project Saeda".
## A arte é montada em camadas: fundo parado + camada só com as mechas de cabelo,
## que balança por um shader (shaders/hair_sway.gdshader).

const PLATE := preload("res://assets/title/title_plate.png")
const HAIR := preload("res://assets/title/title_hair.png")
const LOGO := preload("res://assets/title/title_logo.png")
const FLORES := preload("res://assets/title/title_flores.png")
const FAIRY := preload("res://assets/sprites/fairy_blue.png")
const SWAY_SHADER := preload("res://shaders/portrait_sway.gdshader")
const HAIR_SHADER := preload("res://shaders/hair_sway.gdshader")

const VIEW := Vector2(320, 180)
const COL_TEXT := Color("e9dcff")
const COL_SELECTED := Color("ffb98a")
const COL_DIM := Color("8f86b8")

var _selected := 0
var _items: Array[String] = ["NOVO JOGO", "OPÇÕES", "SAIR"]
var _confirm_new := false
var _labels: Array[Label] = []
var _fade: ColorRect
var _hint: Label
var _time := 0.0
var _busy := false
var _wisp_layer: Node2D
var _wisps: Array = []
var _novo := true            # tela nova (flores) ou a atual/clássica (retrato)
var _style_at_start := 0


func _ready() -> void:
	Sfx.play_music("dusty")
	_style_at_start = Settings.title_style
	_novo = Settings.title_style == 0
	if not Game.progress.is_empty():
		_items = ["CONTINUAR", "NOVO JOGO", "OPÇÕES", "SAIR"]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_art()
	if not _novo:
		_build_logo()
	_build_menu()
	_build_fade()


func _process(delta: float) -> void:
	_time += delta
	# o item selecionado "respira" em brilho
	for i in _labels.size():
		var lab := _labels[i]
		if i == _selected:
			var pulse := 0.85 + 0.15 * sin(_time * 5.0)
			lab.add_theme_color_override("font_color",
				Color(COL_SELECTED.r * pulse, COL_SELECTED.g * pulse, COL_SELECTED.b * pulse, 1.0))
		else:
			lab.add_theme_color_override("font_color", COL_DIM if not _novo else Color("c4dbe6"))
	_hint.modulate.a = 0.45 + 0.25 * sin(_time * 2.0)
	if _wisp_layer:
		_wisp_layer.queue_redraw()


func _draw_wisps() -> void:
	for w in _wisps:
		var y := fposmod(w.y - _time * w.v, 190.0) - 5.0
		var x: float = w.x + sin(_time * 0.8 + w.ph) * w.amp
		var edge := clampf(minf(y + 5.0, 185.0 - y) / 25.0, 0.0, 1.0)
		var tw := (0.7 + 0.3 * sin(_time * 4.0 + w.ph)) * edge
		var p := Vector2(x, y)
		if _novo:
			var fs: float = 0.22 * float(w.sz)
			_wisp_layer.draw_circle(p, 5.0 * w.sz, Color(0.3, 0.6, 1.0, 0.05 * tw))
			_wisp_layer.draw_texture_rect(FAIRY, Rect2(p - FAIRY.get_size() * fs * 0.5, FAIRY.get_size() * fs), false, Color(1, 1, 1, 0.9 * tw))
			continue
		_wisp_layer.draw_circle(p, 6.0 * w.sz, Color(0.23, 0.49, 1.0, 0.07 * tw))
		_wisp_layer.draw_circle(p, 3.4 * w.sz, Color(0.49, 0.77, 1.0, 0.18 * tw))
		_wisp_layer.draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1.4, 1.4)), Color(0.93, 0.98, 1.0, 0.9 * tw))


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_select((_selected + 1) % _items.size())
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_select((_selected - 1 + _items.size()) % _items.size())
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_activate()


# ------------------------------------------------------------------ MONTAGEM ----

func _build_art() -> void:
	var back := ColorRect.new()
	back.color = Color("1a1730")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	if _novo:
		_build_art_flores()
		return
	# A arte tem 1376x768; ajustamos pela altura (180) e centralizamos.
	var art_w := VIEW.y * float(PLATE.get_width()) / float(PLATE.get_height())
	var rect_pos := Vector2((VIEW.x - art_w) * 0.5, 0.0)
	var rect_size := Vector2(art_w, VIEW.y)

	var plate := TextureRect.new()
	plate.texture = PLATE
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = rect_pos
	plate.size = rect_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sway := ShaderMaterial.new()
	sway.shader = SWAY_SHADER
	plate.material = sway
	add_child(plate)

	var hair := TextureRect.new()
	hair.texture = HAIR
	hair.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hair.stretch_mode = TextureRect.STRETCH_SCALE
	hair.position = rect_pos
	hair.size = rect_size
	hair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = HAIR_SHADER
	hair.material = mat
	hair.visible = false  # camada de cabelo era da arte antiga
	add_child(hair)

	# Vinheta suave nas bordas
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.03, 0.02, 0.08, 0.6)])
	var vt := GradientTexture2D.new()
	vt.gradient = grad
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.0, 0.5)
	vt.width = 160
	vt.height = 90
	var vignette := TextureRect.new()
	vignette.texture = vt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# memórias (fadinhas azuis) flutuando pela tela
	_wisp_layer = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_wisp_layer.material = add
	_wisp_layer.draw.connect(_draw_wisps)
	add_child(_wisp_layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 16:
		_wisps.append({
			"x": rng.randf_range(0, 250), "y": rng.randf_range(0, 180),
			"v": rng.randf_range(4.0, 10.0), "ph": rng.randf() * TAU,
			"amp": rng.randf_range(4.0, 12.0), "sz": rng.randf_range(0.7, 1.3)})


## Tela nova: campo de flores azuis (o título já faz parte da arte). Sobre ela,
## as memórias (fadinhas) sobem devagar e algumas luzinhas piscam nas flores.
func _build_art_flores() -> void:
	var plate := TextureRect.new()
	plate.texture = FLORES
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	_wisp_layer = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_wisp_layer.material = add
	_wisp_layer.draw.connect(_draw_wisps)
	add_child(_wisp_layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in 30:
		_wisps.append({
			"x": rng.randf_range(0, 320), "y": rng.randf_range(0, 180),
			"v": rng.randf_range(3.0, 9.0), "ph": rng.randf() * TAU,
			"amp": rng.randf_range(4.0, 14.0), "sz": rng.randf_range(0.7, 1.5)})


func _build_logo() -> void:
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.stretch_mode = TextureRect.STRETCH_KEEP
	logo.position = Vector2(20, 22)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.modulate.a = 0.0
	add_child(logo)
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 1.2).set_delay(0.3)


func _build_menu() -> void:
	for i in _items.size():
		var lab := Label.new()
		lab.text = _items[i]
		if _novo:
			lab.position = Vector2(0, 118 + i * 11)
			lab.size = Vector2(320, 12)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_style_label(lab, 9)
		else:
			lab.position = Vector2(34, 98 + i * 14)
			_style_label(lab, 10)
		add_child(lab)
		_labels.append(lab)
	_update_menu_text()

	_hint = Label.new()
	_hint.text = "SETAS + Z / ENTER"
	_hint.position = Vector2(16, 164)
	if _novo:
		_hint.position = Vector2(0, 164)
		_hint.size = Vector2(320, 10)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_hint, 7)
	_hint.add_theme_color_override("font_color", COL_TEXT)
	add_child(_hint)


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.8)


func _style_label(lab: Label, size: int) -> void:
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_constant_override("outline_size", 3)
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.95))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ------------------------------------------------------------------ MENU ----

func _select(index: int) -> void:
	Sfx.play("select")
	_confirm_new = false
	_update_menu_text()
	_selected = index
	_update_menu_text()


func _update_menu_text() -> void:
	for i in _labels.size():
		var t := _items[i]
		if _confirm_new and t == "NOVO JOGO" and i == _selected:
			t = "APAGAR SAVE? ENTER"
		_labels[i].text = ("> " if i == _selected else "  ") + t


func _activate() -> void:
	if _items[_selected] == "NOVO JOGO" and not Game.progress.is_empty() and not _confirm_new:
		_confirm_new = true
		Sfx.play("select")
		_update_menu_text()
		return
	_busy = true
	Sfx.play("confirm")
	if _items[_selected] == "OPÇÕES":
		Sfx.play("confirm")
		var opt := preload("res://scripts/options_menu.gd").new()
		opt.closed.connect(func() -> void:
			if Settings.title_style != _style_at_start:
				get_tree().reload_current_scene()
			else:
				_busy = false)
		add_child(opt)
		return
	if _items[_selected] == "SAIR":
		var tq := create_tween()
		tq.tween_property(_fade, "color:a", 1.0, 0.35)
		tq.tween_callback(func() -> void: get_tree().quit())
		return
	if _items[_selected] == "NOVO JOGO":
		Game.reset_progress()
	var is_new: bool = _items[_selected] == "NOVO JOGO"
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: Game.go_intro() if is_new else Game.go_map())
