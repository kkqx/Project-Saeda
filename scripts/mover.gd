extends AnimatableBody2D
## Plataforma móvel (3 blocos de largura) que vai e volta na horizontal ou vertical.
## No mapa de texto: "H" (horizontal) e "V" (vertical); no TileMap, "mover_h" e "mover_v".
## A personagem é carregada junto automaticamente.

@export var vertical := false
@export var travel := 32.0      # distância para cada lado, em pixels
@export var period := 4.0       # segundos para ida e volta

const COL_METAL := Color("6b6f86")
const COL_METAL_LIGHT := Color("a4a8c4")
const COL_METAL_DARK := Color("3a3c52")
const COL_LAMP := Color("ffc26b")

var _origin := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	sync_to_physics = true
	_origin = position
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 6)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)


func _physics_process(delta: float) -> void:
	_t += delta
	var s := sin(_t / period * TAU) * travel
	position = _origin + (Vector2(0, s) if vertical else Vector2(s, 0))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-12, -3, 24, 6), COL_METAL)
	draw_rect(Rect2(-12, -3, 24, 1), COL_METAL_LIGHT)
	draw_rect(Rect2(-12, 2, 24, 1), COL_METAL_DARK)
	# parafusos e luzinhas
	for x in [-10, 9]:
		draw_rect(Rect2(x, -1, 1, 1), COL_METAL_DARK)
	var blink := 0.5 + 0.5 * sin(_t * 6.0)
	draw_rect(Rect2(-1, -1, 2, 2), COL_LAMP.lerp(COL_METAL_DARK, 1.0 - blink))
	# setinha indicando o sentido
	if vertical:
		draw_rect(Rect2(-6, -1, 1, 3), COL_METAL_DARK); draw_rect(Rect2(5, -1, 1, 3), COL_METAL_DARK)
	else:
		draw_rect(Rect2(-7, 0, 3, 1), COL_METAL_DARK); draw_rect(Rect2(4, 0, 3, 1), COL_METAL_DARK)
