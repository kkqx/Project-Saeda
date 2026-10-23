extends Node
## Parallax em camadas, tudo com UMA regra só para ficar como uma cena única:
##  - cada camada (fundo, mid, a, b, c) é uma massa sólida que vai até a borda de baixo
##    da imagem (com sobra), colorida a partir do horizonte do fundo;
##  - na horizontal anda `fx` vezes a câmera; na vertical afunda (bottom_ref - cam.y) * fx * k,
##    isto é, na base da fase fica encostada na tela e, ao subir, TODAS afundam juntas na
##    mesma proporção (nada fica boiando);
##  - `fg` é só um capim na frente, preso à borda de baixo.
## Imagens em assets/bg/layers/<fase>_<camada>.png (feitas por script).

const NAMES := ["praia", "torres", "pontes", "cidade", "montanha"]
const TILE_W := 640.0
const PAD := 220.0                  # sobra opaca abaixo da base visível de cada imagem
const BG_FX := 0.25                 # fator horizontal do fundo (level.gd)
const SINK_MAX := 48.0              # quanto a camada mais próxima (c) pode afundar no máximo
# [camada, fator horizontal]
const CFG := [["mid", 0.32], ["a", 0.40], ["b", 0.52], ["c", 0.70]]
const FG_FACTOR := 1.35

var k := 1.0                        # escala vertical (fases altas = parallax vertical menor)
var bottom_ref := 90.0              # y da câmera quando está no ponto mais baixo da fase
var _layers: Array = []             # {node, fx, vis}
var _fg: Sprite2D


## `back` é o CanvasLayer do fundo (atrás do cenário); `limit_bottom` = altura da fase em px.
func setup(back: CanvasLayer, level: Node, limit_bottom: float) -> void:
	bottom_ref = limit_bottom - 90.0
	var travel := maxf(limit_bottom - 180.0, 1.0)
	k = clampf(SINK_MAX / (0.70 * travel), 0.05, 1.0)
	var nm: String = NAMES[clampi(Game.current, 0, NAMES.size() - 1)]
	for cfg in CFG:
		var path := "res://assets/bg/layers/%s_%s.png" % [nm, cfg[0]]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var sp := _make_sprite(tex)
		back.add_child(sp)
		_layers.append({"node": sp, "fx": float(cfg[1]), "vis": tex.get_height() - PAD})
	var fg_path := "res://assets/bg/layers/%s_fg.png" % nm
	if ResourceLoader.exists(fg_path):
		var fg_layer := CanvasLayer.new()
		fg_layer.layer = 1
		level.add_child(fg_layer)
		_fg = _make_sprite(load(fg_path))
		fg_layer.add_child(_fg)


func _make_sprite(tex: Texture2D) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(0, 0, 320.0 + TILE_W, tex.get_height())
	return sp


## Quanto uma camada de fator horizontal `fx` afunda quando a câmera está em cam_y.
func sink(cam_y: float, fx: float) -> float:
	return maxf(bottom_ref - cam_y, 0.0) * fx * k


func update(cam: Vector2) -> void:
	for l in _layers:
		var fx: float = l["fx"]
		l["node"].position = Vector2(-fposmod(cam.x * fx, TILE_W), 180.0 - float(l["vis"]) + sink(cam.y, fx))
	if _fg != null:
		_fg.position = Vector2(-fposmod(cam.x * FG_FACTOR, TILE_W), 180.0 - _fg.texture.get_height())
