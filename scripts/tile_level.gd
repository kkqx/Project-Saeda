class_name TileLevel
extends RefCounted
## Lê uma fase feita com TileMap (levels/level_N.tscn) e devolve o mesmo formato
## do arquivo de texto: uma grade de caracteres + as dicas.
##
## A cena da fase tem 3 nós:
##   Chao     (TileMapLayer)  blocos de chão e espinhos
##   Objetos  (TileMapLayer)  marcadores: início, checkpoint, cristal, memória, porta
##   Dicas    (Node2D)        textos (nós Label) que aparecem quando o jogador chega perto
## Cada tile do tileset tem o dado customizado "kind" (ground, spike, start, checkpoint,
## crystal, berry, door). É ele que diz ao jogo o que cada tile significa.

const KIND_CHAR := {
	"ground": "#", "spike": "^", "start": "P", "checkpoint": "K",
	"crystal": "C", "berry": "S", "door": "F", "flag": "F",
	"spring": "B", "crumble": "D", "mover_h": "H", "mover_v": "V",
}


## Retorna {"grid": Array[String], "hints": Array[String], "origin": Vector2i} ou {} se inválida.
static func read(scene_root: Node, tile_size: int) -> Dictionary:
	var layers: Array[TileMapLayer] = []
	for child in scene_root.get_children():
		if child is TileMapLayer:
			layers.append(child)
	if layers.is_empty():
		return {}

	# Área da fase: sempre começa no tile (0, 0) (canto de cima à esquerda) e cresce para
	# cobrir tudo que foi pintado. Assim o céu vazio acima do chão também faz parte da fase.
	var area := Rect2i(0, 0, 1, 1)
	var any := false
	for layer in layers:
		var r := layer.get_used_rect()
		if r.size == Vector2i.ZERO:
			continue
		area = area.merge(r)
		any = true
	if not any:
		return {}

	var rows_arr: Array[PackedStringArray] = []
	for y in area.size.y:
		var row := PackedStringArray()
		row.resize(area.size.x)
		row.fill(".")
		rows_arr.append(row)

	for layer in layers:
		for cell in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data == null:
				continue
			var kind := str(data.get_custom_data("kind"))
			if not KIND_CHAR.has(kind):
				continue
			var p := cell - area.position
			rows_arr[p.y][p.x] = KIND_CHAR[kind]

	var grid: Array[String] = []
	for row in rows_arr:
		grid.append("".join(row))

	var hints: Array[String] = []
	var dicas := scene_root.get_node_or_null("Dicas")
	if dicas:
		for lab in dicas.get_children():
			if lab is Label and lab.text.strip_edges() != "":
				var col := int(floor(lab.position.x / tile_size)) - area.position.x
				var row := int(floor(lab.position.y / tile_size)) - area.position.y
				hints.append("%d,%d,%s" % [col, row, lab.text.replace("\n", " ")])
	return {"grid": grid, "hints": hints, "origin": area.position}
