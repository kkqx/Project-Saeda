extends Node2D
## Matinho no topo dos blocos: balança com o vento e se curva quando a personagem passa.
## Só desenha o que está perto da câmera. Quem decide a cor é a fase (Game.LEVELS → THEMES).

const TILE := 8
const COLORS := {
	0: [Color("6f7a3e"), Color("a9b565")],    # praia: capim seco
	1: [Color("3d5e3c"), Color("6f9a5a")],    # torres: musgo
	2: [Color("4a7d44"), Color("9acb6a")],    # pontes: verde vivo
	3: [Color("2f5a52"), Color("5fa090")],    # cidade: verde frio
}

var level: Node
var ambient: Node
var _t := 0.0
var _cols: Array = []


func setup(lv: Node, amb: Node) -> void:
	level = lv
	ambient = amb
	_cols = COLORS.get(Game.current, [])
	if _cols.is_empty():
		set_process(false)
		visible = false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _solid(x: int, y: int) -> bool:
	if y < 0 or y >= level.rows or x < 0 or x >= level.cols:
		return false
	return level.grid[y][x] == "#"


func _draw() -> void:
	if level == null or level.camera == null:
		return
	var c: Vector2 = level.camera.get_screen_center_position()
	var x0 := maxi(int((c.x - 168.0) / TILE), 0)
	var x1 := mini(int((c.x + 168.0) / TILE) + 1, level.cols - 1)
	var y0 := maxi(int((c.y - 96.0) / TILE), 0)
	var y1 := mini(int((c.y + 96.0) / TILE) + 1, level.rows - 1)
	var g: float = ambient.gust(_t) if ambient != null else 0.5
	var pp := Vector2(-1000.0, -1000.0)
	if level.player != null:
		pp = level.player.global_position
	var dark: Color = _cols[0]
	var light: Color = _cols[1]
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not _solid(tx, ty) or _solid(tx, ty - 1):
				continue
			if ty > 0 and level.grid[ty - 1][tx] == "^":
				continue
			for b in 4:
				var bx := tx * TILE + 1.0 + b * 2.0 + float((tx * 7 + b * 3) % 3) * 0.4
				var by := float(ty * TILE)
				var h := 2.0 + float((tx * 5 + b * 11) % 4) * 0.9          # alturas diferentes
				var wave := sin(_t * (1.8 + 0.8 * g) + bx * 0.17 + float(b)) * (0.35 + 1.1 * g)
				var push := g * 1.2
				# a personagem passando empurra o matinho para o lado
				var dx := bx - pp.x
				var dy := absf(by - (pp.y + 1.0))
				if absf(dx) < 9.0 and dy < 9.0:
					push += signf(dx) * (1.0 - absf(dx) / 9.0) * 2.2
				var lean := (wave + push) * (h / 3.0)
				var base := Vector2(bx, by)
				var mid := Vector2(bx + lean * 0.45, by - h * 0.55)
				var tip := Vector2(bx + lean, by - h)
				draw_line(base, mid, dark, 1.0)
				draw_line(mid, tip, light, 1.0)
