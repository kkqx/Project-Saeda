extends SceneTree
## Converte uma fase de texto (levels/level_N.txt) em uma cena com TileMap (.tscn),
## que você pode abrir e editar pintando com o TileSet na Godot.
##
## Uso (na pasta do projeto):
##   godot --headless --script res://tools/txt_para_tilemap.gd -- res://levels/level_4.txt res://levels/level_4.tscn

const TILESET := preload("res://assets/tiles/tileset.tres")
const SPIKE := Vector2i(0, 4)
const MARKERS := {"P": Vector2i(1, 4), "K": Vector2i(2, 4), "C": Vector2i(3, 4), "S": Vector2i(4, 4), "F": Vector2i(5, 4),
	"B": Vector2i(6, 4), "D": Vector2i(7, 4), "H": Vector2i(8, 4), "V": Vector2i(9, 4)}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("uso: -- <entrada.txt> <saida.tscn>")
		quit(1)
		return
	var ok := _convert(args[0], args[1])
	quit(0 if ok else 1)


func _convert(txt_path: String, out_path: String) -> bool:
	var grid: Array[String] = []
	var hints: Array[String] = []
	var in_hints := false
	for raw in FileAccess.get_file_as_string(txt_path).split("\n"):
		var line: String = raw.trim_suffix("\r")
		if line.strip_edges() == "---":
			in_hints = true
		elif in_hints:
			if line.strip_edges() != "":
				hints.append(line)
		elif line != "":
			grid.append(line)
	if grid.is_empty():
		push_error("arquivo vazio: " + txt_path)
		return false

	var root := Node2D.new()
	root.name = "Nivel"
	var chao := TileMapLayer.new()
	chao.name = "Chao"
	chao.tile_set = TILESET
	var objetos := TileMapLayer.new()
	objetos.name = "Objetos"
	objetos.tile_set = TILESET
	var dicas := Node2D.new()
	dicas.name = "Dicas"
	root.add_child(chao)
	root.add_child(objetos)
	root.add_child(dicas)
	for n in [chao, objetos, dicas]:
		n.owner = root

	var ground: Array[Vector2i] = []
	for y in grid.size():
		for x in grid[y].length():
			var ch := grid[y][x]
			var cell := Vector2i(x, y)
			if ch == "#":
				ground.append(cell)
			elif ch == "^":
				chao.set_cell(cell, 0, SPIKE)
			elif MARKERS.has(ch):
				objetos.set_cell(cell, 0, MARKERS[ch])
	chao.set_cells_terrain_connect(ground, 0, 0)

	for hint in hints:
		var parts := hint.split(",", true, 2)
		if parts.size() < 3:
			continue
		var lab := Label.new()
		lab.text = parts[2]
		lab.position = Vector2(int(parts[0]) * 8, int(parts[1]) * 8)
		lab.add_theme_font_size_override("font_size", 8)
		dicas.add_child(lab)
		lab.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, out_path)
	print("salvo: ", out_path, " (erro=", err, ", chão=", ground.size(), " tiles)")
	return err == OK
