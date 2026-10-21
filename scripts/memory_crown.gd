extends Node2D
## Coroa de memórias: as fadinhas azuis que Saeda já recuperou giram em volta da cabeça.
## Memórias de fases anteriores já começam na coroa; as novas voam até ela.

const BLUE := Color("7cc4ff")
const FAIRY := preload("res://assets/sprites/fairy_blue.png")
const BLUE_DEEP := Color("3a7cff")
const HEAD := Vector2(0, -21)

var _items: Array = []     # {"from": Vector2 (local) , "t": 1.0, "phase": float}
var _time := 0.0


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func set_initial(n: int) -> void:
	_items.clear()
	for i in n:
		_items.append({"from": Vector2.ZERO, "t": 1.0, "phase": i * 1.7})


## Uma memória nova sai de `world_pos` e entra na coroa.
func add_memory(world_pos: Vector2) -> void:
	_items.append({"from": to_local(world_pos), "t": 0.0, "phase": _items.size() * 1.7})


func count() -> int:
	return _items.size()


func _process(delta: float) -> void:
	_time += delta
	for it in _items:
		if it.t < 1.0:
			it.t = minf(it.t + delta / 0.8, 1.0)
	queue_redraw()


func _draw() -> void:
	var n := _items.size()
	if n == 0:
		return
	var rx := 5.0 + 0.45 * minf(n, 8)
	var ry := 1.8 + 0.12 * minf(n, 8)
	for i in n:
		var it: Dictionary = _items[i]
		var ang: float = _time * 1.1 + TAU * float(i) / n
		var slot := HEAD + Vector2(cos(ang) * rx, sin(ang) * ry + sin(_time * 2.0 + it.phase) * 0.5)
		var k: float = it.t * it.t * (3.0 - 2.0 * it.t)
		var p: Vector2 = it["from"].lerp(slot, k)
		if it.t < 1.0:
			p.y -= sin(k * PI) * 6.0     # sobe em arco até a cabeça
		var back := sin(ang) < 0.0        # atrás da cabeça: mais fraca
		var a := 0.55 if back else 1.0
		var tw := 0.75 + 0.25 * sin(_time * 6.0 + it.phase)
		draw_circle(p, 3.0, Color(BLUE_DEEP, 0.38 * a * tw))
		var flap := 1.0 + 0.2 * sin(_time * 20.0 + it.phase)
		draw_set_transform(p, 0.0, Vector2(flap, 1.0))
		draw_texture_rect(FAIRY, Rect2(-3.2, -3.0, 6.4, 6.0), false, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
