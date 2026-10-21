extends Node2D
## Desenha a personagem com transição suave entre poses (crossfade por shader),
## inclinação, balanço de passo e squash/stretch. Quem manda nos valores é o player.gd.

const POSE_SHADER := preload("res://shaders/pose_blend.gdshader")

var textures: Dictionary = {}
var frame_w := 72.0
var frame_h := 112.0
var idle_h := 104.0
var feet_pad := 2.0
var sprite_height := 18.0
var fade_time := 0.05           # duração do crossfade entre poses

var face := 1
var squash := Vector2.ONE
var lean := 0.0                 # radianos, no sentido da tela (positivo = horário)
var bob := 0.0                  # px que o corpo sobe (balanço do passo)
var tint := Color.WHITE

var _cur := "idle"
var _prev := "idle"
var _blend := 1.0
var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = POSE_SHADER
	material = _mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func set_pose(pose: String) -> void:
	if pose == _cur:
		return
	# se a pose anterior ainda estava dissolvendo, a mais recente vira a base
	_prev = _cur
	_cur = pose
	_blend = 0.0


func advance(delta: float) -> void:
	_blend = minf(_blend + delta / fade_time, 1.0)
	queue_redraw()


func _draw() -> void:
	if textures.is_empty():
		return
	var s := sprite_height / idle_h
	var t := _blend * _blend * (3.0 - 2.0 * _blend)
	var a: Texture2D = textures[_prev]
	var b: Texture2D = textures[_cur]
	_mat.set_shader_parameter("tex_b", b)
	_mat.set_shader_parameter("mix_amount", t)
	_mat.set_shader_parameter("tint", tint)
	draw_set_transform(Vector2(0.0, -bob), lean, Vector2(face * squash.x, squash.y))
	draw_texture_rect(a, Rect2(-frame_w * 0.5 * s, -(frame_h - feet_pad) * s, frame_w * s, frame_h * s), false, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
