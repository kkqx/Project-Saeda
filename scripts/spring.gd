extends Area2D
## Planta saltitante: quem pisa no bulbo é arremessado para cima (e recupera o dash).
## O bulbo amassa, a planta solta esporos e o caule se estica de volta.
## No mapa de texto é o caractere "B"; no TileMap, o tile "spring".

const BOUNCE_SPEED := 280.0
const COL_SOIL := Color("3a2a22")
const COL_SOIL_L := Color("57402f")
const COL_STEM := Color("2f7a35")
const COL_STEM_L := Color("49a64a")
const COL_BULB := Color("78d654")
const COL_BULB_L := Color("b6f58a")
const COL_BULB_D := Color("3f9a3c")
const COL_SPOT := Color("e0527a")

var _spores: Array = []
var _t := 0.0
var _squash := 0.0     # 1 = totalmente comprimida
var _cooldown := 0.0


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 5)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -2.5)   # origem = base da mola (centro do tile, embaixo)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	# se o jogador já estava em cima quando a mola ficou pronta, lança de novo
	if _cooldown <= 0.0:
		for b in get_overlapping_bodies():
			_try_bounce(b)
	_squash = move_toward(_squash, 0.0, delta * 6.0)
	_t += delta
	for sp in _spores:
		sp.life += delta
		sp.p += sp.v * delta
		sp.v.y += 18.0 * delta
	_spores = _spores.filter(func(q): return q.life < 0.7)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	_try_bounce(body)


func _try_bounce(body: Node) -> void:
	if _cooldown > 0.0 or not body.has_method("bounce"):
		return
	if body.velocity.y < -20.0:
		return   # subindo: não prende
	_cooldown = 0.25
	_squash = 1.0
	body.bounce(BOUNCE_SPEED)
	Sfx.play("boing", -2.0)
	for i in 8:
		_spores.append({"p": Vector2(randf_range(-4, 4), -9.0), "v": Vector2(randf_range(-22, 22), randf_range(-50, -20)), "life": 0.0})


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	var sway := sin(_t * 2.2 + position.x * 0.3) * 0.7 * (1.0 - _squash)
	var h := 6.0 - 3.5 * _squash                      # altura do caule
	# terra
	draw_rect(Rect2(-4, -2, 8, 2), COL_SOIL)
	draw_rect(Rect2(-3, -3, 6, 1), COL_SOIL_L)
	# folhinhas na base
	draw_colored_polygon(PackedVector2Array([Vector2(-1, -3), Vector2(-5, -5 - 2 * (1.0 - _squash)), Vector2(-4, -3)]), COL_STEM_L)
	draw_colored_polygon(PackedVector2Array([Vector2(1, -3), Vector2(5, -5 - 2 * (1.0 - _squash)), Vector2(4, -3)]), COL_STEM)
	# caule (levemente curvo)
	var n := 4
	for i in n:
		var k0 := float(i) / n
		var y := -3.0 - h * (k0 + 0.25)
		draw_rect(Rect2(-1 + sway * k0, y, 2, h / n + 1.0), COL_STEM if i % 2 == 0 else COL_STEM_L)
	# bulbo no topo: amassa e alarga quando pisado
	var top := Vector2(sway, -3.0 - h - 2.0 + 1.5 * _squash)
	var rx := 5.0 * (1.0 + 0.35 * _squash)
	var ry := 3.4 * (1.0 - 0.4 * _squash)
	# folhas em volta do bulbo abrem quando ele salta de volta
	var open := 1.0 - _squash
	draw_colored_polygon(PackedVector2Array([top + Vector2(-rx + 1, 0), top + Vector2(-rx - 2.5, -3.5 * open - 0.5), top + Vector2(-rx + 2, -1.5)]), COL_BULB_D)
	draw_colored_polygon(PackedVector2Array([top + Vector2(rx - 1, 0), top + Vector2(rx + 2.5, -3.5 * open - 0.5), top + Vector2(rx - 2, -1.5)]), COL_BULB_D)
	draw_colored_polygon(_ellipse(top, rx, ry), COL_BULB)
	draw_colored_polygon(_ellipse(top + Vector2(0, ry * 0.35), rx * 0.85, ry * 0.55), COL_BULB_D)
	draw_colored_polygon(_ellipse(top + Vector2(-rx * 0.3, -ry * 0.35), rx * 0.45, ry * 0.35), COL_BULB_L)
	draw_rect(Rect2(top + Vector2(rx * 0.25, -0.5), Vector2(1.4, 1.4)), COL_SPOT)
	draw_rect(Rect2(top + Vector2(-0.5, ry * 0.3), Vector2(1.2, 1.2)), COL_SPOT)
	# esporos
	for sp in _spores:
		var a: float = 1.0 - float(sp.life) / 0.7
		draw_rect(Rect2(sp.p, Vector2(1, 1)), Color(0.75, 1.0, 0.55, a))
