extends StaticBody2D
## Plataforma que desmorona: treme quando você pisa, cai e volta depois de um tempo.
## No mapa de texto é o caractere "D"; no TileMap, o tile "crumble".

const SHAKE_TIME := 0.35
const FALL_TIME := 0.5
const RESPAWN_TIME := 2.0
const COL_STONE := Color("8a7f8c")
const COL_STONE_LIGHT := Color("b3a8b2")
const COL_CRACK := Color("4a4252")

enum S { IDLE, SHAKING, FALLING, GONE }

var _state := S.IDLE
var _t := 0.0
var _fall_y := 0.0
var _fall_v := 0.0
var _cs: CollisionShape2D
var _top: Area2D


func _ready() -> void:
	_cs = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 8)
	_cs.shape = shape
	add_child(_cs)
	# sensor logo acima: detecta quem pisa
	_top = Area2D.new()
	var tcs := CollisionShape2D.new()
	var tshape := RectangleShape2D.new()
	tshape.size = Vector2(7, 3)
	tcs.shape = tshape
	tcs.position = Vector2(0, -5)
	_top.add_child(tcs)
	add_child(_top)
	_top.body_entered.connect(_on_step)


func _on_step(body: Node) -> void:
	if _state == S.IDLE and body.has_method("bounce"):
		_state = S.SHAKING
		_t = 0.0
		Sfx.play("step", -6.0, 0.7)


func _physics_process(delta: float) -> void:
	match _state:
		S.SHAKING:
			_t += delta
			if _t >= SHAKE_TIME:
				_state = S.FALLING
				_t = 0.0
				_fall_y = 0.0
				_fall_v = 20.0
				_cs.set_deferred("disabled", true)
				Sfx.play("land", -8.0, 0.8)
		S.FALLING:
			_t += delta
			_fall_v += 420.0 * delta
			_fall_y += _fall_v * delta
			if _t >= FALL_TIME:
				_state = S.GONE
				_t = 0.0
		S.GONE:
			_t += delta
			if _t >= RESPAWN_TIME:
				_state = S.IDLE
				_t = 0.0
				_cs.set_deferred("disabled", false)
	queue_redraw()


func _draw() -> void:
	var off := Vector2.ZERO
	var alpha := 1.0
	match _state:
		S.SHAKING:
			off = Vector2(sin(_t * 90.0) * 0.8, 0.0)
		S.FALLING:
			off = Vector2(0.0, _fall_y)
			alpha = 1.0 - _t / FALL_TIME
		S.GONE:
			# fantasma piscando antes de voltar
			if _t > RESPAWN_TIME - 0.5 and int(_t * 12.0) % 2 == 0:
				alpha = 0.3
			else:
				return
	var r := Rect2(Vector2(-4, -4) + off, Vector2(8, 8))
	draw_rect(r, Color(COL_STONE, alpha))
	draw_rect(Rect2(r.position, Vector2(8, 1)), Color(COL_STONE_LIGHT, alpha))
	draw_rect(Rect2(r.position + Vector2(0, 7), Vector2(8, 1)), Color(COL_CRACK, alpha))
	# rachaduras
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(1, 2)), Color(COL_CRACK, alpha))
	draw_rect(Rect2(r.position + Vector2(3, 4), Vector2(1, 2)), Color(COL_CRACK, alpha))
	draw_rect(Rect2(r.position + Vector2(5, 1), Vector2(1, 3)), Color(COL_CRACK, alpha))
