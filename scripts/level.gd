extends Node2D
## Monta a fase a partir de uma cena com TileMap (levels/level_N.tscn) ou de um
## arquivo de texto (levels/level_N.txt). Veja scripts/tile_level.gd e o README.
##
## Formato de texto:
## Legenda do mapa (1 caractere = 1 bloco de 8x8 px):
##   #  bloco sólido (concreto)   ^  espinho (ferragem)   P  início do jogador
##   C  cristal de dash           S  memória              K  checkpoint
##   F  porta de chegada
##   B  mola   D  plataforma que desmorona   H / V  plataforma móvel (horizontal / vertical)
##   .  vazio
## Depois de uma linha "---" ficam as dicas escritas no cenário: coluna,linha,texto

const TILE := 8
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PICKUP_SCRIPT := preload("res://scripts/pickup.gd")
const SPRING_SCRIPT := preload("res://scripts/spring.gd")
const CRUMBLE_SCRIPT := preload("res://scripts/crumble.gd")
const MOVER_SCRIPT := preload("res://scripts/mover.gd")
const BG_TEX := preload("res://assets/bg/ruins_bg.png")

# Paleta: ruínas de concreto tomadas pelo musgo e pela ferrugem
const COL_CONCRETE := Color("3f4759")
const COL_CONCRETE_LIGHT := Color("566077")
const COL_CONCRETE_DARK := Color("2e3445")
const COL_CRACK := Color("222836")
const COL_MOSS := Color("66b36e")
const COL_MOSS_DARK := Color("3f7f52")
const COL_RUST := Color("b9583a")
const COL_RUST_LIGHT := Color("eb9360")
const COL_RUST_DARK := Color("6b2e28")

const BG_PARALLAX := 0.25

@export_file("*.txt", "*.tscn") var level_path := "res://levels/level_1.txt"

var grid: Array[String] = []
var cols := 0
var rows := 0
var start_spawn := Vector2.ZERO
var spawn := Vector2.ZERO

var player            # sem tipo de propósito: o script do jogador é anexado na cena
var camera: Camera2D

var strawberries := 0
var strawberries_total := 0
var deaths := 0
var elapsed := 0.0
var finished := false

var _finished_at_ms := 0
var _shake := 0.0
var _hints: Array[String] = []
var _last_tick := -1
var _hint_labels: Array[Label] = []
var _tile_scene: Node        # cena TileMap carregada (se a fase for .tscn)
var _solid_body: StaticBody2D
var _checkpoints: Array = []
var _current_cp_x := -1.0
var _leaving := false

var _bg_sprite: Sprite2D
var _bg_py := 0.06
var _fade: ColorRect
var _crown: Node2D
var _power_box: Control
var _power_fill: ColorRect
var _power_label: Label
var _power_msg: Label
var _power_was_on := false
var _aura: Node2D
var _berry_box: Control
var _berry_label: Label
var _berry_timer := 0.0
var _pause: Control
var _pause_closed_frame := -1
var _end_panel: Control
var _end_label: Label


func _ready() -> void:
	Sfx.play_music(Game.LEVELS[Game.current].get("music", "dusty"))
	Game.power_left = Game.POWER_TIME if Game.LEVELS[Game.current].get("final", false) else 0.0
	_power_was_on = Game.power_left > 0.0
	Engine.time_scale = Settings.game_speed()
	level_path = Game.current_level_path()
	if not _load_level():
		return
	_build_background()
	_build_world()
	_spawn_player()
	_build_camera()
	_build_atmosphere()
	_build_hud()
	_build_hints()
	queue_redraw()


func _exit_tree() -> void:
	Engine.time_scale = 1.0   # a velocidade lenta (ajuda) vale só dentro da fase


func _process(delta: float) -> void:
	if grid.is_empty() or camera == null:
		return

	if not finished:
		elapsed += delta
		if Game.LEVELS[Game.current].get("final", false):
			_update_power(delta)

	# fundo em parallax
	var c := camera.get_screen_center_position()
	_bg_sprite.position = Vector2(-(c.x - 160.0) * BG_PARALLAX, -14.0 - (c.y - 90.0) * _bg_py)

	_update_hints()

	# R: volta ao último checkpoint (útil se o poder acabar e você ficar preso)
	if Input.is_action_just_pressed("retry") and not finished and not _leaving and player != null and not player.dead:
		player.die()

	# contador de memórias aparece só um instante
	if _berry_timer > 0.0:
		_berry_timer -= delta
		_berry_box.modulate.a = clampf(_berry_timer / 0.5, 0.0, 1.0)
	elif _berry_box.modulate.a != 0.0:
		_berry_box.modulate.a = 0.0

	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 12.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	else:
		camera.offset = Vector2.ZERO

	if finished and _end_panel.visible and Time.get_ticks_msec() - _finished_at_ms > 900 \
			and Input.is_action_just_pressed("jump"):
		_go_map()
	elif Input.is_action_just_pressed("ui_cancel") and not finished and not _leaving \
			and Engine.get_process_frames() != _pause_closed_frame:
		_pause.open()


func _physics_process(_delta: float) -> void:
	if player != null and camera != null:
		camera.position = player.position + Vector2(0, -8)


# ------------------------------------------------------------- CARREGAR -----

func _load_level() -> bool:
	if not ResourceLoader.exists(level_path) and not FileAccess.file_exists(level_path):
		push_error("Fase não encontrada: " + level_path)
		return false

	if level_path.ends_with(".tscn"):
		return _load_tile_level()

	var in_hints := false
	for raw in FileAccess.get_file_as_string(level_path).split("\n"):
		var line: String = raw.trim_suffix("\r")
		if line.strip_edges() == "---":
			in_hints = true
		elif in_hints:
			if line.strip_edges() != "":
				_hints.append(line)
		elif line != "":
			grid.append(line)

	rows = grid.size()
	for row_text in grid:
		cols = maxi(cols, row_text.length())
	for i in rows:
		grid[i] = grid[i].rpad(cols, ".")
	return rows > 0


## Fase feita com TileMap: o desenho dos blocos vem do TileSet; o jogo só lê o
## significado de cada tile (dado "kind") para criar colisão, espinhos e objetos.
func _load_tile_level() -> bool:
	var packed: PackedScene = load(level_path)
	_tile_scene = packed.instantiate()
	var info := TileLevel.read(_tile_scene, TILE)
	if info.is_empty():
		push_error("Fase sem tiles: " + level_path)
		return false
	grid = info["grid"]
	_hints = info["hints"]
	rows = grid.size()
	for row_text in grid:
		cols = maxi(cols, row_text.length())
	for i in rows:
		grid[i] = grid[i].rpad(cols, ".")
	# camadas visíveis no jogo: só o chão (os marcadores viram objetos de verdade)
	var origin: Vector2i = info["origin"]
	for child in _tile_scene.get_children():
		if child is TileMapLayer:
			child.position = Vector2(-origin * TILE)
			child.collision_enabled = false   # a colisão é montada por _build_collision()
			if child.name == "Objetos":
				child.visible = false
		elif child.name == "Dicas":
			child.visible = false
	add_child(_tile_scene)
	move_child(_tile_scene, 0)
	return true


func _is_solid(x: int, y: int) -> bool:
	# fora do mapa vale o bloco da borda: o chão não ganha "quina" nas pontas da fase
	return grid[clampi(y, 0, rows - 1)][clampi(x, 0, cols - 1)] == "#"


# ---------------------------------------------------------------- MUNDO -----

func _build_world() -> void:
	_solid_body = StaticBody2D.new()
	add_child(_solid_body)
	_build_collision()
	_build_borders()

	for y in rows:
		for x in cols:
			match grid[y][x]:
				"^":
					_add_spike(x, y)
				"P":
					start_spawn = Vector2(x * TILE + TILE * 0.5, (y + 1) * TILE)
				"B":
					var sp := SPRING_SCRIPT.new()
					sp.position = Vector2(x * TILE + 4, (y + 1) * TILE)
					add_child(sp)
				"D":
					var cr := CRUMBLE_SCRIPT.new()
					cr.position = Vector2(x * TILE + 4, y * TILE + 4)
					add_child(cr)
				"H", "V":
					var mv := MOVER_SCRIPT.new()
					mv.vertical = grid[y][x] == "V"
					mv.position = Vector2(x * TILE + 4, y * TILE + 3)
					add_child(mv)
				"C":
					_add_pickup("crystal", Vector2(x * TILE + 4, y * TILE + 4))
				"S":
					if Game.LEVELS[Game.current].get("final", false):
						_add_pickup("power", Vector2(x * TILE + 4, y * TILE + 4))   # memória verde
					else:
						strawberries_total += 1
						_add_pickup("strawberry", Vector2(x * TILE + 4, y * TILE + 4))
				"K":
					_add_pickup("checkpoint", Vector2(x * TILE + 4, (y + 1) * TILE))
				"F":
					_add_pickup("door", Vector2(x * TILE + 4, (y + 1) * TILE))
	spawn = start_spawn


## Junta blocos vizinhos em retângulos grandes (menos formas de colisão e
## sem "emendas" que travam o personagem ao deslizar na parede).
func _build_collision() -> void:
	var open := {}   # "x0,x1" -> linha onde o retângulo começou
	for y in range(rows + 1):
		var runs := {}
		if y < rows:
			var x := 0
			while x < cols:
				if _is_solid(x, y):
					var x0 := x
					while x < cols and _is_solid(x, y):
						x += 1
					runs["%d,%d" % [x0, x]] = true   # x final é exclusivo
				else:
					x += 1
		for key in open.keys():
			if not runs.has(key):
				_add_solid_rect(key, open[key], y)
				open.erase(key)
		for key in runs.keys():
			if not open.has(key):
				open[key] = y


## A fase não tem moldura de blocos: quem limita a visão é a câmera, e estas
## paredes invisíveis só impedem a personagem de sair do mapa.
func _build_borders() -> void:
	var w := cols * TILE
	var h := rows * TILE
	var rects: Array[Rect2] = [
		Rect2(-24, -64, 24, h + 128),      # esquerda
		Rect2(w, -64, 24, h + 128),        # direita
		Rect2(-24, -64, w + 48, 64),       # topo
	]
	for r in rects:
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		_solid_body.add_child(cs)


func _add_solid_rect(key: String, y0: int, y1: int) -> void:
	var parts := key.split(",")
	var x0 := int(parts[0])
	var x1 := int(parts[1])
	var size := Vector2((x1 - x0) * TILE, (y1 - y0) * TILE)
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(x0 * TILE, y0 * TILE) + size * 0.5
	_solid_body.add_child(cs)


func _add_spike(x: int, y: int) -> void:
	var area := Area2D.new()
	area.position = Vector2(x * TILE, y * TILE)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6, 4)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(4, 6)
	area.add_child(cs)
	area.body_entered.connect(_on_hazard_body_entered)
	add_child(area)


func _add_pickup(kind: String, pos: Vector2):
	var pickup = PICKUP_SCRIPT.new()
	pickup.kind = kind
	pickup.position = pos
	pickup.collected.connect(_on_collected)
	add_child(pickup)
	if kind == "checkpoint":
		_checkpoints.append(pickup)
	if kind == "door" and Game.LEVELS[Game.current].get("final", false):
		pickup.cat_mode = true
	return pickup


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = spawn
	player.kill_y = rows * TILE + 24.0
	add_child(player)
	player.died.connect(_on_player_died)
	player.dashed.connect(_on_player_dashed)
	player.landed.connect(_on_player_landed)
	player.jumped.connect(_on_player_jumped)
	if Game.LEVELS[Game.current].get("final", false):
		_aura = preload("res://scripts/power_aura.gd").new()
		player.add_child(_aura)
	_crown = preload("res://scripts/memory_crown.gd").new()
	player.add_child(_crown)
	_crown.set_initial(Game.memories_before(Game.current))


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = cols * TILE
	camera.limit_bottom = rows * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.position = player.position + Vector2(0, -8)
	add_child(camera)
	camera.reset_smoothing()


# ---------------------------------------------------------- CENÁRIO/ATMOSFERA -----

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var sky := ColorRect.new()
	sky.color = Game.LEVELS[Game.current].get("sky", Color("5d8fb8"))
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky)
	_bg_sprite = Sprite2D.new()
	var info: Dictionary = Game.LEVELS[Game.current]
	_bg_py = info.get("bg_parallax_y", 0.06)
	_bg_sprite.texture = load(info.get("bg", "res://assets/bg/ruins_bg.png"))
	_bg_sprite.centered = false
	_bg_sprite.position = Vector2(0, -14)
	_bg_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(_bg_sprite)


func _build_atmosphere() -> void:
	# Vinheta nas bordas da tela (sem partículas flutuando no fundo)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.04, 0.03, 0.09, 0.55)])
	var vt := GradientTexture2D.new()
	vt.gradient = grad
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.0, 0.5)
	vt.width = 160
	vt.height = 90
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var vignette := TextureRect.new()
	vignette.texture = vt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vignette)


# ------------------------------------------------------------------ HUD -----
# HUD limpa: nada fixo na tela. O contador de memórias aparece por um instante
# quando você pega um; o resumo da fase só aparece no final.

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_berry_box = Control.new()
	_berry_box.position = Vector2(10, 8)
	_berry_box.modulate.a = 0.0
	_berry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_berry_box)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(10, 10)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_circle(Vector2(5, 5), 4.5, Color(0.23, 0.49, 1.0, 0.25))
		icon.draw_texture_rect(preload("res://assets/sprites/fairy_blue.png"), Rect2(0, 0, 10, 9), false))
	_berry_box.add_child(icon)
	_berry_label = Label.new()
	_berry_label.position = Vector2(13, -3)
	_style_label(_berry_label, 9)
	_berry_box.add_child(_berry_label)

	if Game.LEVELS[Game.current].get("final", false):
		_build_power_hud(layer)

	_end_panel = Control.new()
	_end_panel.visible = false
	_end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_end_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.08, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_panel.add_child(shade)
	_end_label = Label.new()
	_end_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(_end_label, 10)
	_end_panel.add_child(_end_label)

	# nome da fase: aparece e some sozinho
	var banner := Label.new()   # (desativado: sem texto de nome da fase)
	banner.text = "%d · %s" % [Game.current + 1, Game.LEVELS[Game.current]["name"]]
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.position.y = 12
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(banner, 10)
	banner.free()

	# fade de entrada/saída
	_pause = preload("res://scripts/pause_menu.gd").new()
	_pause.resumed.connect(func() -> void: _pause_closed_frame = Engine.get_process_frames())
	_pause.restart_requested.connect(func() -> void: Game.start_level(Game.current, true))
	_pause.map_requested.connect(_go_map)
	layer.add_child(_pause)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)


func _build_hints() -> void:
	# Sem textos nas fases, exceto na primeira (praia): só os comandos básicos.
	if Game.current != 0:
		return
	var walk_txt := "Setas / A D"
	var dash_txt := "X / Shift"
	var dash_key := "X"
	if not Settings.key_map.is_empty():
		walk_txt = "%s / %s" % [Settings.key_name("move_left"), Settings.key_name("move_right")]
		dash_txt = Settings.key_name("dash")
		dash_key = dash_txt
	_hints = ["3,21,%s: andar" % walk_txt, "33,21,%s: DASH" % dash_txt, "33,22,Segure uma direção e aperte %s" % dash_key]
	for hint in _hints:
		var parts := hint.split(",", true, 2)
		if parts.size() < 3:
			continue
		var label := Label.new()
		label.text = parts[2]
		label.position = Vector2(int(parts[0]) * TILE, int(parts[1]) * TILE)
		_style_label(label, 8)
		label.modulate = Color(1, 1, 1, 0.0)   # só aparece quando o jogador chega perto
		add_child(label)
		_hint_labels.append(label)


## As dicas surgem aos poucos quando você se aproxima e somem quando se afasta.
func _update_hints() -> void:
	if player == null:
		return
	for label in _hint_labels:
		var size: Vector2 = label.get_minimum_size()
		var dx := maxf(maxf(label.position.x - player.position.x, player.position.x - (label.position.x + size.x)), 0.0)
		var dy := absf(player.position.y - 8.0 - (label.position.y + size.y * 0.5))
		var dist := maxf(dx, dy * 0.6)
		label.modulate.a = clampf(1.0 - (dist - 36.0) / 48.0, 0.0, 1.0) * 0.95


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.09, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _format_time(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _show_berry_count() -> void:
	_berry_label.text = "%d / %d" % [strawberries, strawberries_total]
	_berry_timer = 2.4
	_berry_box.modulate.a = 1.0


# --------------------------------------------------------------- EVENTOS ----

func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _on_hazard_body_entered(body) -> void:
	if body.has_method("die"):
		body.die()


func _on_collected(kind: String, node: Node) -> void:
	match kind:
		"strawberry":
			strawberries += 1
			Sfx.play("memoria")
			add_shake(1.0)
			_puff(node.position, 12, Color("7cc4ff"), 50.0)
			if _crown != null:
				_crown.add_memory(node.global_position)
			_show_berry_count()
		"power":
			_awaken_again(node)
		"crystal":
			Sfx.play("crystal")
			add_shake(0.5)
			_puff(node.position, 8, Color("7df9ff"), 40.0)
		"checkpoint":
			_set_checkpoint(node)
		"door":
			_finish(node)


func _set_checkpoint(node: Node) -> void:
	if node.position.x <= _current_cp_x:
		return   # não volta para um checkpoint já ultrapassado
	_current_cp_x = node.position.x
	Sfx.play("checkpoint")
	for cp in _checkpoints:
		cp.set_current(cp == node)
	spawn = node.position
	add_shake(0.6)
	_puff(node.position + Vector2(0, -17), 10, Color("ffc26b"), 30.0)


func _on_player_died() -> void:
	deaths += 1
	Game.log_event("morte | fase %d (%s) | tile %d,%d | tempo %.1fs | morte nº %d" % [
		Game.current + 1, Game.LEVELS[Game.current]["name"],
		int(player.position.x / TILE), int(player.position.y / TILE), elapsed, deaths])
	Sfx.play("death")
	add_shake(3.0)
	_puff(player.position + Vector2(0, -8), 14, Color("f6a77d"), 100.0)
	_puff(player.position + Vector2(0, -6), 10, Color("5a4a9a"), 80.0)
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree() and not finished:
		player.respawn(spawn)
		if Game.LEVELS[Game.current].get("final", false):
			Game.power_left = Game.POWER_TIME   # voltar do checkpoint recarrega o poder
			_power_was_on = true
			_power_msg.modulate.a = 0.0


func _on_player_dashed(_dir: Vector2) -> void:
	Sfx.play("dash")
	add_shake(1.0)
	if player.is_on_floor():
		_puff(player.position + Vector2(0, -1), 6, Color("c9c2d8"), 40.0)


func _on_player_landed(strength: float) -> void:
	if strength > 0.35:
		Sfx.play("land", -4.0 + 4.0 * strength)
	if strength > 0.4:
		_puff(player.position + Vector2(0, -1), 5, Color("b9b4c8"), 30.0)


func _on_player_jumped() -> void:
	Sfx.play("jump")
	_puff(player.position + Vector2(0, -1), 3, Color("b9b4c8"), 22.0)


func _finish(door: Node) -> void:
	if finished:
		return
	finished = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	Game.complete_level(Game.current, strawberries, strawberries_total, elapsed, deaths)
	Game.log_event("concluida | fase %d (%s) | tempo %.1fs | mortes %d | memorias %d/%d" % [
		Game.current + 1, Game.LEVELS[Game.current]["name"], elapsed, deaths, strawberries, strawberries_total])
	_end_label.text = "FASE %d COMPLETA\n%s\n\nMemórias  %d / %d\nMortes  %d\nTempo  %s\n\nZ: voltar ao mapa" % [
		Game.current + 1, Game.LEVELS[Game.current]["name"],
		strawberries, strawberries_total, deaths, _format_time(elapsed)
	]
	if Game.LEVELS[Game.current].get("final", false):
		_cat_ending(door)
	else:
		_enter_door(door)


## Final do jogo: Saeda chega ao topo, o gatinho vem correndo e vai para os braços dela.
func _cat_ending(cat: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var lab := Label.new()
	lab.position = Vector2(0, 150)
	lab.size = Vector2(320, 20)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(lab, 10)
	lab.modulate.a = 0.0
	layer.add_child(lab)
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.size = Vector2(320, 180)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(white)
	player.facing = 1 if cat.position.x >= player.position.x else -1
	var stop_x: float = cat.position.x - 22.0
	var tw := create_tween()
	tw.tween_property(player, "position:x", stop_x, 1.2)
	tw.tween_callback(func() -> void:
		lab.text = "...é você mesmo?"
		lab.modulate.a = 1.0)
	tw.tween_interval(1.4)
	tw.tween_callback(func() -> void:
		cat.cat_happy = true
		Sfx.play("miau")
		Sfx.play("unlock", -8.0, 1.4)
		_puff(cat.position + Vector2(0, -8), 14, Color("9fd0ff"), 45.0))
	tw.tween_property(cat, "position", player.position + Vector2(6, 0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		lab.text = "Te encontrei."
		Sfx.play("finish")
		_puff(player.position + Vector2(0, -10), 20, Color("ffe2a8"), 60.0)
		add_shake(0.8))
	tw.tween_interval(2.4)
	tw.tween_property(lab, "modulate:a", 0.0, 0.5)
	tw.tween_property(white, "color:a", 1.0, 1.6)
	tw.tween_callback(func() -> void: Game.go_credits())


## Animação de chegada: a personagem vai até a porta, a porta abre soltando luz,
## ela entra (some na luz), a porta fecha e aparece o resultado.
func _enter_door(door: Node) -> void:
	var target: Vector2 = door.position
	player.facing = 1 if target.x >= player.position.x else -1
	var tw := create_tween()
	tw.tween_property(player, "position", target + Vector2(0, 0), 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		Sfx.play("unlock")
		add_shake(0.8)
		door.animate_door(true, 0.55))
	tw.tween_interval(0.5)
	# entra na porta: encolhe de lado, sobe um pouquinho e some na luz
	tw.tween_property(player, "scale", Vector2(0.55, 1.0), 0.4)
	tw.parallel().tween_property(player, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(player, "position:y", target.y - 1.0, 0.4)
	tw.tween_callback(func() -> void:
		_puff(door.position + Vector2(0, -9), 12, Color("ffe2a8"), 55.0)
		door.animate_door(false, 0.5))
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		Sfx.play("finish")
		_finished_at_ms = Time.get_ticks_msec()
		_end_panel.visible = true)


func _go_map() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void: Game.go_map())


func _puff(pos: Vector2, amount: int, color: Color, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.0
	p.color = color
	p.emitting = true
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- VISUAL ----

func _hash(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff


func _draw() -> void:
	if grid.is_empty() or _tile_scene != null:
		return
	for y in rows:
		for x in cols:
			var pos := Vector2(x * TILE, y * TILE)
			match grid[y][x]:
				"#":
					_draw_solid(x, y, pos)
				"^":
					_draw_spike(x, y, pos)


func _draw_solid(x: int, y: int, pos: Vector2) -> void:
	var h := _hash(x, y)
	# quanto mais fundo no bloco, mais escuro
	var depth := 0
	for k in range(1, 4):
		if _is_solid(x, y - k):
			depth += 1
	var base := COL_CONCRETE.lerp(COL_CONCRETE_DARK, depth / 3.0 * 0.85)
	if h % 5 == 0:
		base = base.lightened(0.05)
	draw_rect(Rect2(pos, Vector2(TILE, TILE)), base)

	# placas de concreto: junta horizontal a cada 2 blocos de altura
	if y % 2 == 0 and _is_solid(x, y - 1):
		draw_rect(Rect2(pos, Vector2(TILE, 1)), COL_CRACK)
	# rachaduras e ferragem exposta
	if h % 7 == 0:
		draw_rect(Rect2(pos + Vector2(2, 2), Vector2(1, 2)), COL_CRACK)
		draw_rect(Rect2(pos + Vector2(3, 4), Vector2(1, 2)), COL_CRACK)
		draw_rect(Rect2(pos + Vector2(4, 6), Vector2(1, 1)), COL_CRACK)
	elif h % 23 == 0:
		draw_rect(Rect2(pos + Vector2(3, 1), Vector2(1, 5)), COL_RUST)
		draw_rect(Rect2(pos + Vector2(3, 1), Vector2(1, 1)), COL_RUST_LIGHT)

	# bordas
	if not _is_solid(x - 1, y):
		draw_rect(Rect2(pos, Vector2(1, TILE)), COL_CONCRETE_LIGHT)
	if not _is_solid(x + 1, y):
		draw_rect(Rect2(pos + Vector2(TILE - 1, 0), Vector2(1, TILE)), COL_CRACK)
	if not _is_solid(x, y + 1):
		draw_rect(Rect2(pos + Vector2(0, TILE - 1), Vector2(TILE, 1)), COL_CRACK)

	# musgo por cima das superfícies
	if not _is_solid(x, y - 1):
		draw_rect(Rect2(pos, Vector2(TILE, 2)), COL_MOSS)
		draw_rect(Rect2(pos + Vector2(0, 2), Vector2(TILE, 1)), COL_MOSS_DARK)
		if h % 3 == 0:
			draw_rect(Rect2(pos + Vector2(h % 6, -1), Vector2(1, 1)), COL_MOSS)
		if h % 4 == 1:
			draw_rect(Rect2(pos + Vector2((h >> 3) % 7, 3), Vector2(1, 2)), COL_MOSS_DARK)
	# musgo pendurado nas laterais de vez em quando
	elif not _is_solid(x - 1, y) and h % 6 == 0:
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(1, 3)), COL_MOSS_DARK)


func _draw_spike(_x: int, _y: int, pos: Vector2) -> void:
	# barra de base
	draw_rect(Rect2(pos + Vector2(0, 7), Vector2(TILE, 1)), COL_RUST_DARK)
	for i in 2:
		var o := pos + Vector2(i * 4, 0)
		draw_colored_polygon(PackedVector2Array([
			o + Vector2(0, 7), o + Vector2(2, 2), o + Vector2(4, 7)
		]), COL_RUST)
		draw_colored_polygon(PackedVector2Array([
			o + Vector2(0.5, 7), o + Vector2(2, 2), o + Vector2(2, 7)
		]), COL_RUST_LIGHT)
		draw_rect(Rect2(o + Vector2(1.5, 1), Vector2(1, 1)), Color("f6c9a0"))


# ------------------------------------------------------- PODER (FASE FINAL) ----
# O dash infinito dura Game.POWER_TIME segundos. Quando acaba, é preciso pegar uma
# memória verde para despertar de novo.

func _build_power_hud(layer: CanvasLayer) -> void:
	_power_box = Control.new()
	_power_box.position = Vector2(112, 6)
	_power_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_power_box)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.06, 0.65)
	bg.size = Vector2(96, 9)
	_power_box.add_child(bg)
	_power_fill = ColorRect.new()
	_power_fill.position = Vector2(1, 1)
	_power_fill.size = Vector2(94, 7)
	_power_fill.color = Color("3dff7a")
	_power_box.add_child(_power_fill)
	var icon := Control.new()
	icon.position = Vector2(-13, -1)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_circle(Vector2(6, 5), 5.0, Color(0.2, 1.0, 0.45, 0.25))
		icon.draw_texture_rect(preload("res://assets/sprites/fairy_green.png"), Rect2(0, 0, 12, 11), false))
	_power_box.add_child(icon)
	_power_label = Label.new()
	_power_label.position = Vector2(99, -4)
	_style_label(_power_label, 9)
	_power_box.add_child(_power_label)
	_power_msg = Label.new()
	_power_msg.position = Vector2(0, 20)
	_power_msg.size = Vector2(320, 14)
	_power_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_power_msg, 9)
	_power_msg.modulate.a = 0.0
	layer.add_child(_power_msg)


func _update_power(delta: float) -> void:
	if player == null or _power_box == null:
		return
	if Game.power_left > 0.0 and not player.dead:
		Game.power_left = maxf(0.0, Game.power_left - delta)
	var frac := Game.power_left / Game.POWER_TIME
	_power_fill.size.x = 94.0 * frac
	var col := Color("3dff7a")
	if Game.power_left < 5.0:
		col = Color("ffd34d").lerp(Color("ff4d4d"), 1.0 - Game.power_left / 5.0)
	_power_fill.color = col
	_power_label.text = "%d" % ceili(Game.power_left)
	_power_label.add_theme_color_override("font_color", col)
	_power_box.modulate.a = 1.0
	if Game.power_left > 0.0 and Game.power_left < 5.0:
		var sec := ceili(Game.power_left)
		if sec != _last_tick:
			_last_tick = sec
			Sfx.play("tique", -6.0, 1.0 + (5 - sec) * 0.06)
		_power_box.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.016)
	var on := Game.power_left > 0.0
	if _power_was_on and not on:
		_power_out()
	_power_was_on = on
	if _power_msg.modulate.a > 0.0 and not on:
		_power_msg.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)


func _power_out() -> void:
	Sfx.play("death", -10.0, 0.6)
	add_shake(1.0)
	_puff(player.position + Vector2(0, -9), 18, Color("5dff8a"), 40.0)
	_power_msg.text = "O poder acabou: ache uma memória verde ou aperte R"
	_power_msg.modulate.a = 1.0
	_power_label.text = "0"


## Pegou uma memória verde: o poder desperta de novo (câmera lenta, olho verde, clarão).
func _awaken_again(node: Node) -> void:
	Game.power_left = Game.POWER_TIME
	_power_was_on = true
	_power_msg.modulate.a = 0.0
	Sfx.play("verde")
	add_shake(2.0)
	_puff(node.global_position, 24, Color("5dff8a"), 70.0)
	if _aura != null and _aura.has_method("burst"):
		_aura.burst()
	var flash := preload("res://scripts/persona_flash.gd").new()
	add_child(flash)
	# câmera lenta curtinha (o timer ignora a escala de tempo)
	Engine.time_scale = 0.05
	get_tree().create_timer(0.9, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = Settings.game_speed())
