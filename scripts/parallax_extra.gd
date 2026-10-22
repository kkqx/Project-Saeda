extends Node
## Camadas extras de paralaxe, somadas às de parallax_layers.gd:
##   far  nuvens distantes que andam sozinhas (deriva) e acompanham a câmera bem devagar
##   mid  silhuetas afastadas, entre a imagem de fundo e as faixas a/b/c
## Imagens em assets/bg/layers/<N>_far.png e <N>_mid.png (N = índice da fase), sem emenda.

const W := 640
const SPEEDS := {   # camada: [fator x, fator y (vezes o do fundo), y base na tela, deriva px/s]
	"far": [0.10, 0.4, 2.0, 3.5],
	"mid": [0.30, 1.6, 70.0, 0.0],
}

var _layers: Array = []
var _t := 0.0
var _ref := Vector2.ZERO
var _ref_set := false
var _bg_py := 0.06


## `back` = CanvasLayer do fundo; as camadas entram em ordem depois da imagem de fundo.
func setup(level_index: int, back: CanvasLayer, bg_py: float) -> void:
	_bg_py = bg_py
	for name in ["far", "mid"]:
		var path := "res://assets/bg/layers/%d_%s.png" % [level_index, name]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		sp.region_rect = Rect2(0, 0, 320, tex.get_height())
		sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if level_index == 4 and name == "mid":
			sp.modulate.a = 0.7      # na montanha o pôr do sol precisa continuar aparecendo
		back.add_child(sp)
		_layers.append({"sprite": sp, "name": name, "h": float(tex.get_height())})


func update_layers(cam: Vector2, delta: float) -> void:
	if not _ref_set:
		_ref = cam      # a câmera inicial é a referência
		_ref_set = true
	_t += delta
	for l in _layers:
		var spec: Array = SPEEDS[l["name"]]
		var sp: Sprite2D = l["sprite"]
		var sx := fposmod((cam.x - _ref.x) * float(spec[0]) + _t * float(spec[3]), float(W))
		sp.region_rect = Rect2(sx, 0, 320, l["h"])
		var dy := (_ref.y - cam.y) * _bg_py * float(spec[1])      # subir na fase = camadas afundam
		sp.position = Vector2(0, float(spec[2]) + dy)
