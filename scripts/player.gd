extends CharacterBody2D
## Saeda — personagem jogável (Godot 4.x)
## Valores pensados para viewport de 320x180 (pixel art).
## O pé do personagem fica na origem do nó (0, 0); a caixa de colisão tem 7x16 px.
## Controles (Mapa de Entrada, criado por scripts/input_setup.gd):
##   move_left/right/up/down, jump, dash

enum State { NORMAL, DASH }

@export_group("Corrida")
@export var max_run := 90.0
@export var run_accel := 1000.0
@export var run_reduce := 400.0      # desaceleração quando acima da velocidade máxima
@export var air_mult := 0.65         # multiplicador de aceleração no ar

@export_group("Pulo")
@export var gravity := 900.0
@export var max_fall := 160.0
@export var jump_speed := -105.0
@export var jump_hold_time := 0.2    # segura o botão = pulo mais alto
@export var coyote_time := 0.1       # pode pular logo após sair da plataforma
@export var jump_buffer_time := 0.1  # pulo "pré-apertado" antes de tocar o chão
@export var apex_threshold := 40.0   # perto do topo do pulo, gravidade reduz

@export_group("Parede")
@export var wall_slide_speed := 30.0
@export var wall_jump_h_speed := 130.0
@export var wall_jump_lock_time := 0.16  # trava o controle horizontal brevemente

@export_group("Dash")
@export var dash_speed := 240.0
@export var dash_time := 0.15
@export var dash_freeze_time := 0.05     # "hit stop" no início do dash
@export var dash_end_speed := 160.0      # velocidade mantida ao terminar
@export var dash_cooldown := 0.2
@export var max_dashes := 1

@export_group("Visual")
@export var sprite_height := 18.0        # altura do sprite parado, em pixels do jogo
@export var walk_frame_time := 0.05

# Frames da sprite sheet (assets/sprites). Todos têm 72x112 px, pés alinhados na base.
const FRAME_W := 72.0
const FRAME_H := 112.0
const FRAME_IDLE_H := 104.0              # altura útil do frame "idle" dentro do arquivo
const FEET_PAD := 2.0                    # folga entre os pés e a borda inferior do frame
const TEX := {
	"idle": preload("res://assets/sprites/idle.png"),
	"walk1": preload("res://assets/sprites/walk1.png"),
	"walk2": preload("res://assets/sprites/walk2.png"),
	"walk3": preload("res://assets/sprites/walk3.png"),
	"walk4": preload("res://assets/sprites/walk4.png"),
	"walk5": preload("res://assets/sprites/walk5.png"),
	"walk6": preload("res://assets/sprites/walk6.png"),
	"walk7": preload("res://assets/sprites/walk7.png"),
	"walk8": preload("res://assets/sprites/walk8.png"),
	"crouch": preload("res://assets/sprites/crouch.png"),
	"jump": preload("res://assets/sprites/jump.png"),
}
const WALK_CYCLE := ["walk1", "walk2", "walk3", "walk4", "walk5", "walk6", "walk7", "walk8"]
const BODY_SCRIPT := preload("res://scripts/player_sprite.gd")
const TINT_NO_DASH := Color(0.55, 0.72, 1.0, 1.0)      # sem dash: personagem azulado
const GHOST_WITH_DASH := Color(1.0, 0.72, 0.58)
const GHOST_POWER := Color(0.25, 1.0, 0.5)
const GHOST_NO_DASH := Color(0.55, 0.75, 1.0)

signal dashed(direction: Vector2)
signal landed(strength: float)
signal jumped
signal died

var state: State = State.NORMAL
var facing := 1
var dashes_left := 1
var dead := false
var kill_y := 100000.0   # cair abaixo disso = morrer (a fase define)

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_hold_timer := 0.0
var _wall_lock_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _freeze_timer := 0.0
var _dash_dir := Vector2.ZERO

# visual
var _trail: Array = []       # rastro do dash: {"pos", "alpha", "frame", "facing"}
var _frame_name := "idle"
var _walk_i := 0
var _walk_timer := 0.0
var _land_timer := 0.0
var _squash := Vector2.ONE
var _anim_time := 0.0
var _lean := 0.0
var _walk_phase := 0.0
var _body: Node2D

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	dashes_left = max_dashes
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # sprite em alta resolução, reduzido suavemente
	# o corpo é um nó filho: ele cuida do crossfade entre poses (o rastro do dash fica aqui)
	_body = BODY_SCRIPT.new()
	_body.textures = TEX
	_body.frame_w = FRAME_W
	_body.frame_h = FRAME_H
	_body.idle_h = FRAME_IDLE_H
	_body.feet_pad = FEET_PAD
	_body.sprite_height = sprite_height
	add_child(_body)


func _physics_process(delta: float) -> void:
	if dead:
		return

	if position.y > kill_y:
		die()
		return

	_update_trail(delta)

	# Freeze frame: congela tudo por instantes quando o dash começa
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		queue_redraw()
		return

	if Game.dash_unlimited():
		dashes_left = max_dashes
	_update_timers(delta)

	match state:
		State.NORMAL:
			_state_normal(delta)
		State.DASH:
			_state_dash(delta)

	_forgive_corners(delta)

	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_on_landed(fall_speed)

	_update_anim(delta)
	queue_redraw()


# ---------------------------------------------------- QUINAS (perdão) ----
## Ajuda de "feeling", como no Celeste:
##  - bater a cabeça na quina de um teto empurra o personagem de lado (até 4 px);
##  - pulo/dash que bate de lado logo abaixo do topo de uma plataforma sobe até 4 px.

const CORNER_FORGIVE := 4


func _forgive_corners(delta: float) -> void:
	if is_on_floor():
		return
	# cabeça na quina do teto
	if velocity.y < 0.0 and test_move(global_transform, Vector2(0.0, velocity.y * delta)):
		for k in range(1, CORNER_FORGIVE + 1):
			for dir in [1, -1]:
				var off := Vector2(k * dir, 0.0)
				if not test_move(global_transform.translated(off), Vector2(0.0, velocity.y * delta)) \
						and not test_move(global_transform, off):
					position.x += off.x
					return
	# beirada: sobe um pouquinho para passar para cima da plataforma
	if velocity.y <= 0.0 and absf(velocity.x) > 1.0:
		var step := Vector2(signf(velocity.x), 0.0) * maxf(absf(velocity.x) * delta, 1.0)
		if test_move(global_transform, step):
			for k in range(1, CORNER_FORGIVE + 1):
				var up := Vector2(0.0, -k)
				if not test_move(global_transform, up) \
						and not test_move(global_transform.translated(up), step):
					position.y -= k
					return


# ------------------------------------------------------------ VIDA/MORTE ----

func die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	state = State.NORMAL
	_trail.clear()
	_spawn_death_fx()
	visible = false
	_shape.set_deferred("disabled", true)
	died.emit()


## Animação de morte: um "fantasma" branco do sprite sobe girando e some.
func _spawn_death_fx() -> void:
	var fx := DeathFx.new()
	fx.tex = TEX["idle"]
	fx.sprite_scale = sprite_height / FRAME_IDLE_H
	fx.face = facing
	fx.top_level = true
	fx.global_position = global_position
	get_parent().add_child(fx)


class DeathFx extends Node2D:
	var tex: Texture2D
	var sprite_scale := 0.17
	var face := 1
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t > 0.6:
			queue_free()

	func _draw() -> void:
		var k := _t / 0.6
		var w := 72.0 * sprite_scale
		var h := 112.0 * sprite_scale
		var s := (1.0 - k * 0.8)
		draw_set_transform(Vector2(0, -h * 0.5 - k * 14.0), k * 2.5 * face, Vector2(face * s, s))
		var flash := Color(1, 1, 1, 1.0 - k)
		draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, flash)
		# anel de luz
		draw_set_transform(Vector2(0, -h * 0.4), 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, 3.0 + k * 22.0, 0.0, TAU, 24, Color(1.0, 0.8, 0.7, 0.8 * (1.0 - k)), 1.0)


func respawn(pos: Vector2) -> void:
	position = pos
	reset_physics_interpolation()   # sem "deslizar" do ponto da morte até o checkpoint
	_lean = 0.0
	velocity = Vector2.ZERO
	state = State.NORMAL
	dashes_left = max_dashes
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_jump_hold_timer = 0.0
	_wall_lock_timer = 0.0
	_dash_timer = 0.0
	_dash_cooldown_timer = 0.0
	_freeze_timer = 0.0
	_squash = Vector2.ONE
	_land_timer = 0.0
	dead = false
	visible = true
	_shape.set_deferred("disabled", false)


## Chamado pelos cristais.
func refill_dash() -> void:
	dashes_left = max_dashes


## Lançado para cima por uma mola (ou algo parecido).
func bounce(speed: float) -> void:
	if state == State.DASH:
		_end_dash(false)
	velocity.y = -speed
	_jump_hold_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	dashes_left = max_dashes
	_squash = Vector2(0.7, 1.35)


# ---------------------------------------------------------------- TIMERS ----

func _update_timers(delta: float) -> void:
	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown_timer = max(_dash_cooldown_timer - delta, 0.0)
	_wall_lock_timer = max(_wall_lock_timer - delta, 0.0)

	if is_on_floor():
		_coyote_timer = coyote_time
		# Só recarrega fora do dash: evita ganhar dash extra ao sair do chão dashando
		if state == State.NORMAL and _dash_cooldown_timer <= 0.0:
			dashes_left = max_dashes
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


# ---------------------------------------------------------------- NORMAL ----

func _state_normal(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	if input_x != 0.0:
		facing = int(signf(input_x))

	# Dash
	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash()
		return

	# Movimento horizontal (travado brevemente após wall jump)
	if _wall_lock_timer <= 0.0:
		var mult := 1.0 if is_on_floor() else air_mult
		if absf(velocity.x) > max_run and signf(velocity.x) == input_x:
			velocity.x = move_toward(velocity.x, max_run * input_x, run_reduce * mult * delta)
		else:
			velocity.x = move_toward(velocity.x, max_run * input_x, run_accel * mult * delta)

	# Gravidade (mais leve no ápice do pulo se o botão estiver pressionado)
	if not is_on_floor():
		var g := gravity
		if absf(velocity.y) < apex_threshold and Input.is_action_pressed("jump"):
			g *= 0.5
		var fall_limit := max_fall
		if _is_wall_sliding(input_x):
			fall_limit = wall_slide_speed
		velocity.y = move_toward(velocity.y, fall_limit, g * delta)

	# Pulo variável: segurar o botão estende o impulso
	if _jump_hold_timer > 0.0:
		if Input.is_action_pressed("jump"):
			velocity.y = jump_speed
			_jump_hold_timer -= delta
		else:
			_jump_hold_timer = 0.0

	# Pulo normal (com coyote time + jump buffer)
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_do_jump()
	# Wall jump
	elif _jump_buffer_timer > 0.0 and not is_on_floor():
		var side := _wall_side()
		if side != 0:
			_do_wall_jump(side)


func _do_jump() -> void:
	velocity.y = jump_speed
	_jump_hold_timer = jump_hold_time
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_squash = Vector2(0.8, 1.25)
	jumped.emit()


func _do_wall_jump(side: int) -> void:
	velocity.x = -side * wall_jump_h_speed   # empurra para longe da parede
	velocity.y = jump_speed
	facing = -side
	_jump_hold_timer = jump_hold_time
	_wall_lock_timer = wall_jump_lock_time
	_jump_buffer_timer = 0.0
	_squash = Vector2(0.8, 1.25)
	jumped.emit()


## Lado da parede encostada: 1 = direita, -1 = esquerda, 0 = nenhuma.
## Usa uma margem de 2px, então não precisa estar pressionando contra a parede.
func _wall_side() -> int:
	if test_move(global_transform, Vector2(2, 0)):
		return 1
	if test_move(global_transform, Vector2(-2, 0)):
		return -1
	return 0


func _is_wall_sliding(input_x: float) -> bool:
	if is_on_floor() or velocity.y <= 0.0 or input_x == 0.0:
		return false
	return _wall_side() == int(signf(input_x))


func _on_landed(fall_speed: float) -> void:
	var strength := clampf(fall_speed / max_fall, 0.0, 1.0)
	if strength > 0.35:
		_land_timer = 0.07
		_squash = Vector2(1.0 + 0.3 * strength, 1.0 - 0.3 * strength)
	landed.emit(strength)


# ------------------------------------------------------------------ DASH ----

func _can_dash() -> bool:
	return dashes_left > 0 and _dash_cooldown_timer <= 0.0


func _start_dash() -> void:
	dashes_left -= 1
	_freeze_timer = dash_freeze_time

	# Direção de 8 vias; sem input, dá dash para onde está olhando
	_dash_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2(facing, 0)
	_dash_dir = _dash_dir.normalized()
	if absf(_dash_dir.x) > 0.1:
		facing = int(signf(_dash_dir.x))

	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown   # conta desde o início do dash (permite encadear com cristais)
	_jump_hold_timer = 0.0
	state = State.DASH
	_squash = Vector2(1.35, 0.72) if absf(_dash_dir.x) >= absf(_dash_dir.y) else Vector2(0.75, 1.35)
	dashed.emit(_dash_dir)


func _state_dash(delta: float) -> void:
	velocity = _dash_dir * dash_speed
	_dash_timer -= delta
	_trail.append({"pos": global_position, "alpha": 1.0, "frame": "jump", "facing": facing,
		"blue": dashes_left <= 0, "power": Game.power_on()})

	# "Dash jump" / "hyper": pular durante o dash no chão
	if _jump_buffer_timer > 0.0 and is_on_floor():
		_end_dash(false)
		_do_jump()
		# Dash horizontal + pulo = "super" (mais velocidade horizontal)
		if _dash_dir.y == 0.0:
			velocity.x = _dash_dir.x * dash_speed * 1.25
		return

	if _dash_timer <= 0.0:
		_end_dash(true)


func _end_dash(keep_momentum: bool) -> void:
	state = State.NORMAL
	if keep_momentum:
		velocity = _dash_dir * dash_end_speed
		# Dash para cima perde um pouco de força, como no Celeste
		if _dash_dir.y < 0.0:
			velocity *= 0.75


# ---------------------------------------------------------------- VISUAL ----

func _update_trail(delta: float) -> void:
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i]["alpha"] -= delta * (3.2 if _trail[i].get("power", false) else 5.0)
		if _trail[i]["alpha"] <= 0.0:
			_trail.remove_at(i)


func _update_anim(delta: float) -> void:
	_anim_time += delta
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-16.0 * delta))
	_land_timer = maxf(_land_timer - delta, 0.0)

	var run_ratio := clampf(absf(velocity.x) / max_run, 0.0, 1.3)
	var bob := 0.0
	if state == State.DASH or not is_on_floor():
		_frame_name = "jump"
	elif _land_timer > 0.0:
		_frame_name = "crouch"
	elif absf(velocity.x) > 12.0:
		var step := delta * clampf(run_ratio, 0.6, 1.3)
		_walk_timer += step
		_walk_phase += step * PI / (walk_frame_time * 4.0)   # um sobe-e-desce por passo (4 quadros)
		if _walk_timer >= walk_frame_time:
			_walk_timer -= walk_frame_time
			_walk_i = (_walk_i + 1) % WALK_CYCLE.size()
			if is_on_floor() and _walk_i % 4 == 0:
				Sfx.play("step", -12.0, randf_range(0.9, 1.1))
		_frame_name = WALK_CYCLE[_walk_i]
		bob = 0.9 * absf(sin(_walk_phase)) * clampf(run_ratio, 0.0, 1.0)   # corpo sobe e desce a cada passo
	else:
		_walk_i = 0
		_walk_timer = 0.0
		_frame_name = "idle"

	# inclinação suave: para a frente ao correr, e conforme sobe/cai no ar
	var target_lean := facing * 0.07 * run_ratio
	if state == State.DASH:
		target_lean = facing * 0.2
	elif not is_on_floor():
		target_lean += facing * clampf(-velocity.y / 220.0, -1.0, 1.0) * 0.08
		if _is_wall_sliding(Input.get_axis("move_left", "move_right")):
			target_lean = _wall_side() * 0.16   # encosta o corpo na parede
	_lean = lerpf(_lean, target_lean, 1.0 - exp(-14.0 * delta))

	if _body != null:
		var sq := _squash
		if _frame_name == "idle":
			sq.y *= 1.0 + 0.012 * sin(_anim_time * 3.0)   # respirar
		# poses extras feitas por deformação do sprite (sem precisar de arte nova)
		if state == State.DASH:
			# estica na direção do dash
			sq.x *= 1.0 + 0.3 * absf(_dash_dir.x) - 0.22 * absf(_dash_dir.y)
			sq.y *= 1.0 + 0.3 * absf(_dash_dir.y) - 0.22 * absf(_dash_dir.x)
		elif not is_on_floor():
			if _is_wall_sliding(Input.get_axis("move_left", "move_right")):
				sq *= Vector2(0.9, 1.05)                      # grudada na parede
			elif velocity.y < -30.0:
				sq *= Vector2(0.95, 1.07)                     # subindo
			elif velocity.y > 60.0:
				var k := clampf((velocity.y - 60.0) / 100.0, 0.0, 1.0)
				sq *= Vector2(1.0 - 0.1 * k, 1.0 + 0.14 * k)  # caindo: estica
		_body.set_pose(_frame_name)
		_body.face = facing
		_body.squash = sq
		_body.lean = _lean
		_body.bob = bob
		_body.tint = Color.WHITE if dashes_left > 0 else TINT_NO_DASH
		_body.advance(delta)


func _draw_frame(frame: String, offset: Vector2, face: int, sq: Vector2, col: Color) -> void:
	var tex: Texture2D = TEX[frame]
	var s := sprite_height / FRAME_IDLE_H
	draw_set_transform(offset, 0.0, Vector2(face * sq.x, sq.y))
	draw_texture_rect(tex, Rect2(-FRAME_W * 0.5 * s, -(FRAME_H - FEET_PAD) * s, FRAME_W * s, FRAME_H * s), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	# Rastro do dash
	for ghost in _trail:
		var gp: Vector2 = ghost["pos"] - global_position
		var gc: Color = GHOST_NO_DASH if ghost["blue"] else GHOST_WITH_DASH
		if ghost.get("power", false):
			# poder desperto: rastro verde, mais forte e com halo
			gc = GHOST_POWER
			_draw_frame(ghost["frame"], gp, ghost["facing"], Vector2(1.35, 1.2), Color(0.1, 1.0, 0.45, ghost["alpha"] * 0.22))
			_draw_frame(ghost["frame"], gp, ghost["facing"], Vector2(1.1, 0.95), Color(gc, ghost["alpha"] * 0.75))
			continue
		_draw_frame(ghost["frame"], gp, ghost["facing"], Vector2(1.1, 0.95), Color(gc, ghost["alpha"] * 0.55))
	# o personagem em si é desenhado pelo nó filho (player_sprite.gd)
