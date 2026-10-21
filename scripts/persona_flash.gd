extends CanvasLayer
## Despertar rápido ao pegar uma memória verde (estilo "Persona"): a tela corta para preto,
## uma faixa horizontal abre mostrando os olhos em close, linhas de velocidade passam,
## um símbolo angular "pisca" no canto e tudo fecha em menos de 1 segundo.

const FACE := preload("res://assets/intro/face_4.png")
const DURATION := 0.85
const BAND_Y := 50.0
const BAND_H := 80.0
const EYE_MID := Vector2(311.0, 144.0)      # meio dos olhos na imagem do rosto
const EYE_L := Vector2(200.0, 145.0)
const EYE_R := Vector2(422.0, 143.0)
const TINT := Color(0.55, 1.0, 0.78)

const SHADER := """
shader_type canvas_item;
uniform vec3 tint = vec3(0.55, 1.0, 0.78);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	g = smoothstep(0.1, 0.95, g);
	COLOR = vec4(mix(vec3(0.0, 0.05, 0.04), tint, g) * (0.75 + 0.5 * g), c.a);
}
"""

var _t0 := 0
var fake_time := -1.0   # só para testes (captura quadro a quadro)
var _root: Control
var _bg: ColorRect
var _band: Control
var _face: Sprite2D
var _fx: Node2D
var _white: ColorRect


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_root = Control.new()
	_root.size = Vector2(320, 180)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.size = Vector2(320, 180)
	_root.add_child(_bg)
	_band = Control.new()
	_band.clip_contents = true
	_band.position = Vector2(0, BAND_Y + BAND_H * 0.5)
	_band.size = Vector2(320, 2)
	_root.add_child(_band)
	_face = Sprite2D.new()
	_face.texture = FACE
	_face.centered = false
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	_face.material = mat
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_band.add_child(_face)
	_fx = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = add
	_fx.draw.connect(_draw_fx)
	_root.add_child(_fx)
	_white = ColorRect.new()
	_white.size = Vector2(320, 180)
	_white.color = Color(0.8, 1.0, 0.9, 0.0)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_white)
	_bg.modulate.a = 0.0
	_update_face(0.0)


func _now() -> float:
	if fake_time >= 0.0:
		return fake_time
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _update_face(k: float) -> void:
	var s := 320.0 / 550.0 * lerpf(1.15, 1.45, k)
	_face.scale = Vector2(s, s)
	_face.position = Vector2(160.0, BAND_H * 0.5) - EYE_MID * s


func _process(_d: float) -> void:
	var t := _now()
	var open := clampf(t / 0.1, 0.0, 1.0)
	var close := clampf((t - (DURATION - 0.14)) / 0.14, 0.0, 1.0)
	var h := BAND_H * _e(open) * (1.0 - _e(close))
	_band.size = Vector2(320, maxf(h, 0.0))
	_band.position = Vector2(0, 90.0 - h * 0.5)
	_face.position.y = h * 0.5 - EYE_MID.y * _face.scale.y
	_bg.modulate.a = clampf(t / 0.05, 0.0, 1.0) * (1.0 - close)
	_update_face(clampf(t / DURATION, 0.0, 1.0))
	_face.position.y = h * 0.5 - EYE_MID.y * _face.scale.y
	# clarão de entrada e de saída
	_white.color.a = 0.7 * maxf(1.0 - t / 0.09, 0.0) + 0.35 * clampf(1.0 - absf(t - 0.5) / 0.06, 0.0, 1.0)
	_fx.queue_redraw()
	if t >= DURATION:
		queue_free()


func _e(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _draw_fx() -> void:
	var t := _now()
	var open := clampf(t / 0.1, 0.0, 1.0)
	var close := clampf((t - (DURATION - 0.14)) / 0.14, 0.0, 1.0)
	var h := BAND_H * _e(open) * (1.0 - _e(close))
	var top := 90.0 - h * 0.5
	# linhas de velocidade horizontais dentro da faixa
	for i in 16:
		var seed_v := float(i) * 12.9898
		var yy := top + fposmod(sin(seed_v) * 43758.5453, 1.0) * h
		var sp := 380.0 + fposmod(sin(seed_v * 1.7) * 9871.3, 1.0) * 500.0
		var ln := 30.0 + fposmod(sin(seed_v * 2.3) * 721.1, 1.0) * 70.0
		var x := fposmod(t * sp + fposmod(sin(seed_v * 3.1) * 5123.7, 1.0) * 400.0, 440.0) - 60.0
		_fx.draw_line(Vector2(x, yy), Vector2(x + ln, yy), Color(0.5, 1.0, 0.8, 0.55), 1.0)
	# brilho nas íris
	var s := _face.scale.x
	var k := clampf((t - 0.12) / 0.2, 0.0, 1.0) * (1.0 - _e(close))
	for e in [EYE_L, EYE_R]:
		var p: Vector2 = Vector2(_face.position.x, top + _face.position.y) + e * s
		_fx.draw_circle(p, 26.0 * k, Color(0.1, 0.9, 0.4, 0.14))
		_fx.draw_circle(p, 12.0 * k, Color(0.3, 1.0, 0.6, 0.35))
		_fx.draw_circle(p, 4.5 * k, Color(0.9, 1.0, 0.95, 0.9))
	# símbolo angular no canto, estilo onomatopeia, aparece com "pop" e treme
	var pop := clampf((t - 0.14) / 0.1, 0.0, 1.0)
	if pop > 0.0 and close < 1.0:
		var sc := (1.0 + 0.35 * sin(pop * PI)) * pop
		var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.0 if t < 0.4 else 0.4)
		var c := Vector2(262.0, 52.0) + shake
		_draw_sign(c, sc, 1.0 - _e(close))


func _draw_sign(c: Vector2, sc: float, a: float) -> void:
	# duas barras inclinadas (um "!" angular) com contorno em 3D
	var bars := [
		PackedVector2Array([Vector2(-6, -26), Vector2(7, -30), Vector2(5, -2), Vector2(-4, 0)]),
		PackedVector2Array([Vector2(-5, 6), Vector2(4, 5), Vector2(4, 16), Vector2(-5, 17)]),
		PackedVector2Array([Vector2(12, -20), Vector2(30, -24), Vector2(28, -17), Vector2(14, -13)]),
		PackedVector2Array([Vector2(14, -6), Vector2(32, -8), Vector2(31, -1), Vector2(16, 1)]),
	]
	for b in bars:
		var pts := PackedVector2Array()
		for p in b:
			pts.append(c + p.rotated(0.35) * sc)
		var back := PackedVector2Array()
		for p in pts:
			back.append(p + Vector2(3, 3) * sc)
		_fx.draw_colored_polygon(back, Color(0.1, 0.5, 0.3, 0.7 * a))
		_fx.draw_colored_polygon(pts, Color(0.55, 1.0, 0.8, 0.85 * a))
		_fx.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1, 1, 1, a), 1.0)
