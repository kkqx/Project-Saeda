extends Area2D
## Item da fase: cristal de dash ("crystal"), memória ("strawberry", fadinha azul),
## checkpoint ("checkpoint") ou porta de chegada ("door").
## O visual é desenhado por código (troque por sprites quando tiver arte).

signal collected(kind: String, node: Node)

@export var kind := "crystal"

const CRYSTAL_COLOR := Color("7df9ff")
const STRAWBERRY_COLOR := Color("7cc4ff")
const POWER_COLOR := Color("5dff8a")
const FAIRY_BLUE := preload("res://assets/sprites/fairy_blue.png")
const FAIRY_GREEN := preload("res://assets/sprites/fairy_green.png")
const LEAF_COLOR := Color("5fd068")

var is_current := false   # checkpoint: é o ponto de retorno atual?
var visited := false      # checkpoint: já foi ativado alguma vez?

var cat_mode := false       # fase final: no lugar da porta fica o gatinho
var cat_happy := false
const CAT_TEX := preload("res://assets/cat/cat.png")

var open_t := 0.0         # porta: 0 = fechada, 1 = aberta (a fase anima isso ao entrar)

var _active := true
var _time := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	match kind:
		"door":
			var rect := RectangleShape2D.new()
			rect.size = Vector2(10, 18)
			shape.shape = rect
			shape.position = Vector2(0, -9)
		"checkpoint":
			var rect2 := RectangleShape2D.new()
			rect2.size = Vector2(12, 22)
			shape.shape = rect2
			shape.position = Vector2(0, -11)
		_:
			var circle := CircleShape2D.new()
			circle.radius = 5.0
			shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_time = randf() * TAU
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _physics_process(_delta: float) -> void:
	# O cristal também é coletado se o jogador já estava dentro dele quando usou o dash
	if kind == "crystal" and _active:
		for body in get_overlapping_bodies():
			_try_collect(body)


func _on_body_entered(body) -> void:
	_try_collect(body)


func _try_collect(body) -> void:
	if not _active or not body.has_method("refill_dash"):
		return
	match kind:
		"crystal":
			if body.dashes_left >= body.max_dashes:
				return
			body.refill_dash()
			_active = false
			collected.emit(kind, self)
			get_tree().create_timer(2.5).timeout.connect(_respawn)
		"strawberry":
			_active = false
			collected.emit(kind, self)
			queue_free()
		"power":
			# memória verde: acorda o poder de novo (volta depois de um tempo)
			if Game.power_left > Game.POWER_TIME - 3.0:
				return
			_active = false
			collected.emit(kind, self)
			get_tree().create_timer(9.0).timeout.connect(_respawn)
		"checkpoint":
			if is_current:
				return
			collected.emit(kind, self)
		"door":
			_active = false
			collected.emit(kind, self)


func _respawn() -> void:
	_active = true


## Chamado pela fase: marca este checkpoint como o atual (ou não).
func set_current(value: bool) -> void:
	is_current = value
	if value:
		visited = true


# ---------------------------------------------------------------- VISUAL ----

func _draw() -> void:
	match kind:
		"crystal":
			_draw_crystal()
		"strawberry":
			_draw_strawberry()
		"power":
			_draw_power()
		"checkpoint":
			_draw_checkpoint()
		"door":
			if cat_mode:
				_draw_cat()
			else:
				_draw_door()


func _draw_crystal() -> void:
	# cristal do desenho: losango alto, duas faces escuras opostas e um losango por dentro
	var c := Vector2(0, sin(_time * 3.0) * 1.5)
	var t := c + Vector2(0, -7.0)
	var r := c + Vector2(4.5, 0)
	var bt := c + Vector2(0, 7.0)
	var l := c + Vector2(-4.5, 0)
	if not _active:
		draw_polyline(PackedVector2Array([t, r, bt, l, t]), Color(CRYSTAL_COLOR, 0.35), 1.0)
		return
	draw_circle(c, 9.0, Color(CRYSTAL_COLOR, 0.14))
	var dark := Color(0.16, 0.58, 0.76)
	var light := Color(0.74, 0.97, 1.0)
	draw_colored_polygon(PackedVector2Array([t, r, c]), dark)
	draw_colored_polygon(PackedVector2Array([r, bt, c]), light)
	draw_colored_polygon(PackedVector2Array([bt, l, c]), dark)
	draw_colored_polygon(PackedVector2Array([l, t, c]), light)
	var it := c + Vector2(0, -3.4)
	var ir := c + Vector2(2.2, 0)
	var ib := c + Vector2(0, 3.4)
	var il := c + Vector2(-2.2, 0)
	draw_colored_polygon(PackedVector2Array([it, ir, ib, il]), Color(0.42, 0.86, 1.0))
	draw_line(it, ib, Color(1, 1, 1, 0.7), 1.0)
	draw_line(il, ir, Color(1, 1, 1, 0.7), 1.0)
	draw_polyline(PackedVector2Array([it, ir, ib, il, it]), Color(0.1, 0.45, 0.62), 1.0)
	draw_polyline(PackedVector2Array([t, r, bt, l, t]), Color(0.08, 0.38, 0.55), 1.0)


## Fadinha das memórias (sprite do jogador). Asas batendo e brilho pulsando.
func _draw_fairy(tex: Texture2D, glow: Color, active := true) -> void:
	var c := Vector2(sin(_time * 1.3) * 1.5, sin(_time * 2.5) * 2.0)
	var tw := 0.75 + 0.25 * sin(_time * 6.0)
	if not active:
		draw_circle(c, 5.0, Color(glow, 0.12))
		return
	draw_circle(c, 9.0, Color(glow, 0.10 * tw))
	draw_circle(c, 6.0, Color(glow, 0.18 * tw))
	var flap := 1.0 + 0.18 * sin(_time * 22.0)
	draw_set_transform(c, sin(_time * 1.3) * 0.12, Vector2(flap, 1.0))
	var w := tex.get_width() * 0.5
	var h := tex.get_height() * 0.5
	draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_strawberry() -> void:
	_draw_fairy(FAIRY_BLUE, Color(STRAWBERRY_COLOR))


func _draw_power() -> void:
	_draw_fairy(FAIRY_GREEN, POWER_COLOR, _active)


func _draw_checkpoint() -> void:
	# poste enferrujado com uma lamparina
	draw_rect(Rect2(-3.0, -2.0, 6.0, 2.0), Color("34303f"))
	draw_rect(Rect2(-1.0, -15.0, 2.0, 13.0), Color("57505f"))
	draw_rect(Rect2(-1.0, -15.0, 1.0, 13.0), Color("6d6577"))
	var c := Vector2(0, -17.0)
	var lamp := Color("6f7391")
	if visited:
		lamp = Color("ffc26b")
	if is_current:
		var pulse := 0.8 + 0.2 * sin(_time * 4.0)
		draw_circle(c, 10.0, Color(1.0, 0.72, 0.38, 0.10 * pulse))
		draw_circle(c, 6.5, Color(1.0, 0.76, 0.42, 0.18 * pulse))
		lamp = Color("fff0b8")
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -3.5), c + Vector2(3, 0), c + Vector2(0, 3.5), c + Vector2(-3, 0)
	]), lamp)


## Anima a porta abrindo (open_t 0 -> 1) ou fechando (1 -> 0).
func animate_door(to_open: bool, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "open_t", 1.0 if to_open else 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


func _draw_cat() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var frame := 0
	if cat_happy:
		frame = 3
	else:
		frame = int(_time / 0.7) % 2
		if fmod(_time, 3.1) < 0.14:
			frame = 2          # piscada
	var s := 0.3
	var src := Rect2(frame * 72, 0, 72, 64)
	draw_texture_rect_region(CAT_TEX, Rect2(Vector2(-36 * s, -(64 - 2) * s), Vector2(72 * s, 64 * s)), src)
	if not cat_happy:
		# brilho azul fraquinho: ele estava esperando
		draw_circle(Vector2(0, -7), 10.0 + sin(_time * 3.0), Color(0.4, 0.7, 1.0, 0.07))


func _draw_door() -> void:
	var stone := Color("3f4759")
	var stone_dark := Color("2e3445")
	var stone_light := Color("566077")
	var wood := Color("7a4f35")
	var wood_dark := Color("553523")
	var iron := Color("34303f")
	var warm := Color("ffe2a8")

	# luz saindo pela porta (só quando abre): feixes para cima e poça no chão
	if open_t > 0.01:
		var k := open_t
		for i in 3:
			var spread := 5.0 + i * 5.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, -18), Vector2(5, -18), Vector2(spread + 6.0, -34.0 - i * 4.0), Vector2(-spread - 6.0, -34.0 - i * 4.0)
			]), Color(1.0, 0.9, 0.62, 0.07 * k))
		draw_rect(Rect2(-9, -1, 18, 1), Color(1.0, 0.9, 0.62, 0.45 * k))
		draw_rect(Rect2(-12, 0, 24, 1), Color(1.0, 0.9, 0.62, 0.2 * k))

	# batente de pedra com arco
	draw_rect(Rect2(-8, -22, 16, 22), stone_dark)
	draw_rect(Rect2(-8, -22, 16, 3), stone)
	draw_rect(Rect2(-7, -23, 14, 1), stone_light)
	draw_rect(Rect2(-8, -22, 1, 22), stone_light)
	draw_rect(Rect2(7, -22, 1, 22), Color("222836"))
	draw_rect(Rect2(-9, -2, 18, 2), stone)          # soleira

	# vão da porta: escuro por dentro, claro quando aberta
	var inner := Color("14101c").lerp(warm, open_t)
	draw_rect(Rect2(-6, -19, 12, 19), inner)
	if open_t > 0.01:
		for y in range(-19, 0, 3):
			draw_rect(Rect2(-6, y, 12, 1), Color(1, 1, 1, 0.18 * open_t))

	# folha de madeira: gira em torno da dobradiça da esquerda (fica mais estreita ao abrir)
	var w := 12.0 * (1.0 - open_t * 0.88)
	if w > 0.5:
		draw_rect(Rect2(-6, -19, w, 19), wood)
		var x := -6.0 + 3.0
		while x < -6.0 + w:
			draw_rect(Rect2(x, -19, 1, 19), wood_dark)
			x += 3.0
		draw_rect(Rect2(-6, -15, w, 1), iron)
		draw_rect(Rect2(-6, -6, w, 1), iron)
		draw_rect(Rect2(-6.0 + w - 1.0, -19, 1, 19), wood_dark)
		if w > 5.0:
			draw_rect(Rect2(-6.0 + w - 3.0, -10, 1, 2), Color("f2c36b"))
	# fresta de luz embaixo da porta fechada: chama atenção
	if open_t < 0.05:
		var pulse := 0.55 + 0.25 * sin(_time * 3.0)
		draw_rect(Rect2(-5, -1, 10, 1), Color(1.0, 0.85, 0.5, pulse))
