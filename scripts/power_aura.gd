extends Node2D
## Aura do poder das memórias (fase final): brilho verde em volta da Saeda,
## partículas subindo e o olho verde aceso. Só aparece enquanto o poder está ativo
## (contagem regressiva). Fica como filho do jogador. burst() = anéis do despertar.

var player
var _time := 0.0
var _parts: Array = []
var _burst := 99.0


func _ready() -> void:
	z_index = 1
	player = get_parent()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


func burst() -> void:
	_burst = 0.0


func _process(delta: float) -> void:
	_time += delta
	_burst += delta
	if not Game.power_on() and _burst > 1.0:
		visible = false
		return
	visible = true
	if randf() < delta * 14.0:
		_parts.append({"p": Vector2(randf_range(-6, 6), randf_range(-4, -14)), "life": 0.0, "v": randf_range(14, 28)})
	for pt in _parts:
		pt.life += delta
		pt.p.y -= pt.v * delta
		pt.p.x += sin(pt.life * 6.0 + pt.v) * 3.0 * delta
	_parts = _parts.filter(func(q): return q.life < 0.9)
	queue_redraw()


func _draw() -> void:
	var low := Game.power_left < 5.0
	var pulse := 0.8 + 0.2 * sin(_time * (10.0 if low else 4.0))
	var c := Vector2(0, -9)
	if Game.power_on():
		draw_circle(c, 15.0 * pulse, Color(0.1, 0.9, 0.4, 0.08))
		draw_circle(c, 10.0 * pulse, Color(0.3, 1.0, 0.55, 0.12))
		for pt in _parts:
			var a: float = 1.0 - float(pt.life) / 0.9
			draw_rect(Rect2(pt.p, Vector2(1, 1)), Color(0.6, 1.0, 0.7, 0.9 * a))
		# olho verde aceso (olha para onde ela está virada)
		var face := 1.0
		if player != null and "facing" in player:
			face = float(player.facing)
		var e := Vector2(face * 2.4, -14.2)
		draw_circle(e, 3.0, Color(0.2, 1.0, 0.5, 0.18 * pulse))
		draw_circle(e, 1.6, Color(0.3, 1.0, 0.55, 0.45))
		draw_rect(Rect2(e - Vector2(0.5, 0.5), Vector2(1.2, 1.0)), Color(0.8, 1.0, 0.85, 1.0))
	# anéis do despertar
	if _burst < 1.0:
		for i in 3:
			var k := clampf(_burst * 1.6 - i * 0.18, 0.0, 1.0)
			if k > 0.0 and k < 1.0:
				draw_arc(c, 6.0 + 46.0 * k, 0.0, TAU, 40, Color(0.4, 1.0, 0.6, 0.8 * (1.0 - k)), 1.5)
		for j in 12:
			var ang := TAU * j / 12.0 + 0.2
			var r0 := 8.0 + 50.0 * _burst
			draw_line(c + Vector2(cos(ang), sin(ang)) * r0, c + Vector2(cos(ang), sin(ang)) * (r0 + 10.0), Color(0.7, 1.0, 0.8, 1.0 - _burst), 1.0)
