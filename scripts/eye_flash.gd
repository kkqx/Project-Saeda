extends CanvasLayer
## Clarão do olho verde: os olhos dela se abrem rápido, brilham e somem.
## Usado quando ela pega uma memória verde e desperta o poder de novo.

const FRAMES := [
	preload("res://assets/intro/eye_5.png"), preload("res://assets/intro/eye_6.png"),
	preload("res://assets/intro/eye_7.png"), preload("res://assets/intro/eye_8.png"),
	preload("res://assets/intro/eye_9.png"),
]
const SCALE := 0.8

var _t0 := 0
var _dim: ColorRect
var _eyes: Array = []
var _fx: Node2D


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_dim = ColorRect.new()
	_dim.size = Vector2(320, 180)
	_dim.color = Color(0.0, 0.05, 0.03, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	for i in 2:
		var s := Sprite2D.new()
		s.texture = FRAMES[0]
		s.centered = true
		s.scale = Vector2(SCALE * (1 if i == 0 else -1), SCALE)
		s.position = Vector2(160 + (-70 if i == 0 else 70), 90)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(s)
		_eyes.append(s)
	_fx = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = add
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _t() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _process(_delta: float) -> void:
	var t := _t()
	# 0.00-0.30 abrindo; 0.30-0.65 brilhando; 0.65-0.95 sumindo
	var idx := clampi(int(t / 0.06), 0, FRAMES.size() - 1)
	var fade := 1.0 - clampf((t - 0.65) / 0.3, 0.0, 1.0)
	_dim.color.a = 0.55 * minf(clampf(t / 0.1, 0.0, 1.0), fade)
	for e in _eyes:
		e.texture = FRAMES[idx]
		e.modulate.a = fade
	_fx.queue_redraw()
	if t > 1.0:
		queue_free()


func _draw_fx() -> void:
	var t := _t()
	if t < 0.28:
		return
	var k := clampf((t - 0.28) / 0.3, 0.0, 1.0)
	var fade := 1.0 - clampf((t - 0.65) / 0.3, 0.0, 1.0)
	for sx in [-1.0, 1.0]:
		var c := Vector2(160.0 + sx * 70.0 + sx * 3.0, 94.0)
		_fx.draw_circle(c, 40.0 * k, Color(0.1, 0.9, 0.4, 0.10 * fade))
		_fx.draw_circle(c, 22.0 * k, Color(0.2, 1.0, 0.5, 0.22 * fade))
		_fx.draw_circle(c, 9.0 * k, Color(0.8, 1.0, 0.85, 0.7 * fade))
	# clarão branco-esverdeado no auge
	var flash := clampf(1.0 - absf(t - 0.32) / 0.12, 0.0, 1.0)
	_fx.draw_rect(Rect2(0, 0, 320, 180), Color(0.6, 1.0, 0.75, 0.55 * flash))
