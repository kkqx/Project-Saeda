extends Node
## Camadas de parallax extras por fase: três faixas de silhuetas que repetem na horizontal
## (a, b, c: da mais longe para a mais perto, cada uma anda mais rápido que a anterior)
## e uma camada "fg" na frente do cenário (cipós, cabos, névoa) que anda mais rápido
## que o chão. Imagens em assets/bg/layers/<fase>_<camada>.png (feitas por script).

const NAMES := ["praia", "torres", "pontes", "cidade", "montanha"]
const TILE_W := 512.0
# [camada, fator horizontal, fator vertical, alinhamento (px acima da base da tela), transparência]
const CFG := [
	["a", 0.36, 0.08, -4.0, 0.95],
	["b", 0.50, 0.12, -2.0, 0.92],
	["c", 0.70, 0.16, 0.0, 0.95],
]
const FG_FACTOR := 1.35

var _layers: Array = []     # {node, fx, fy, base_y}
var _fg: Sprite2D
var _fg_layer: CanvasLayer


## `back` é o CanvasLayer do fundo (atrás do cenário).
func setup(back: CanvasLayer, level: Node) -> void:
	var nm: String = NAMES[clampi(Game.current, 0, NAMES.size() - 1)]
	for cfg in CFG:
		var path := "res://assets/bg/layers/%s_%s.png" % [nm, cfg[0]]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var sp := _make_sprite(tex, float(cfg[4]))
		back.add_child(sp)
		_layers.append({"node": sp, "fx": cfg[1], "fy": cfg[2], "base": 180.0 - tex.get_height() - float(cfg[3])})
	var fg_path := "res://assets/bg/layers/%s_fg.png" % nm
	if ResourceLoader.exists(fg_path):
		_fg_layer = CanvasLayer.new()
		_fg_layer.layer = 1
		level.add_child(_fg_layer)
		_fg = _make_sprite(load(fg_path), 1.0)
		_fg_layer.add_child(_fg)


func _make_sprite(tex: Texture2D, alpha: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(0, 0, 320.0 + TILE_W, tex.get_height())
	sp.modulate.a = alpha
	return sp


func update(cam: Vector2) -> void:
	for l in _layers:
		var x := -fposmod(cam.x * float(l["fx"]), TILE_W)
		var y := float(l["base"]) - clampf((cam.y - 90.0) * float(l["fy"]), -36.0, 60.0)
		l["node"].position = Vector2(x, y)
	if _fg != null:
		_fg.position = Vector2(-fposmod(cam.x * FG_FACTOR, TILE_W), clampf(-(cam.y - 90.0) * 0.2, -30.0, 4.0) - 2.0)
