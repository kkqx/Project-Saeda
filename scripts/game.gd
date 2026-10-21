extends Node
## Estado global do jogo (autoload "Game"): lista de fases, progresso salvo e troca de cenas.
## Para criar uma fase nova: crie levels/level_N.txt, adicione uma linha em LEVELS
## e um nó no mapa (assets/map/map_data.json).

const SAVE_PATH := "user://project_saeda.cfg"
const TITLE_SCENE := "res://scenes/title.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"
const AWAKEN_SCENE := "res://scenes/awakening.tscn"
const CREDITS_SCENE := "res://scenes/credits.tscn"
const MAP_SCENE := "res://scenes/world_map.tscn"
const LEVEL_SCENE := "res://scenes/main.tscn"

const LEVELS := [
	{"name": "Praia", "music": "dusty", "subtitle": "Primeiros passos", "path": "res://levels/level_1.tscn", "bg": "res://assets/bg/bg_praia.png", "sky": Color("5d6a5a")},
	{"name": "Torres Médias", "music": "ultima", "subtitle": "Parede e ferragem", "path": "res://levels/level_2.tscn", "bg": "res://assets/bg/bg_torres.png", "sky": Color("2a2038")},
	{"name": "Pontes", "music": "last", "subtitle": "Planta saltitante, chão frágil e plataformas", "path": "res://levels/level_3.tscn", "bg": "res://assets/bg/bg_pontes.png", "sky": Color("5f7a82")},
	{"name": "Cidade", "music": "ultima", "subtitle": "Dash no limite", "path": "res://levels/level_4.tscn", "bg": "res://assets/bg/bg_cidade.png", "sky": Color("0a0818")},
	{"name": "Montanha", "music": "last", "subtitle": "O topo", "path": "res://levels/level_5.txt", "bg": "res://assets/bg/bg_montanha.png", "sky": Color("4e3a68"), "bg_parallax_y": 0.015, "infinite_dash": true, "final": true, "needs_all_memories": true},
]

var current := 0           # fase que está sendo jogada
var map_node := 0          # em qual nó do mapa o marcador está
var just_completed := -1   # fase recém-concluída (o mapa anima o desbloqueio)
const POWER_TIME := 20.0   # segundos de dash infinito por despertar (fase final)
var power_left := 0.0      # tempo restante do poder (só vale na fase final)
var awakened := false      # já viu a cena do despertar (olho verde)
var finished := false      # já terminou o jogo (créditos)
var progress := {}         # "0": {"done", "berries", "berries_total", "best_time", "deaths"}


func _ready() -> void:
	load_progress()


# ------------------------------------------------------------ REGISTRO ----
## Registro de jogo: uma linha por morte/conclusão em user://playtest_log.txt.
## (No Godot: Projeto > Abrir pasta de dados do usuário.) Mande esse arquivo para
## ajustar as fases: ele mostra onde você morre mais.
const LOG_PATH := "user://playtest_log.txt"


func log_event(text: String) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s | %s" % [Time.get_datetime_string_from_system(false, true), text])
	f.close()


# ---------------------------------------------------------------- PROGRESSO ----

func is_done(index: int) -> bool:
	return progress.get(str(index), {}).get("done", false)


## A fase já pode ser alcançada no mapa (a anterior foi concluída)?
func is_reachable(index: int) -> bool:
	if index < 0 or index >= LEVELS.size():
		return false
	return index == 0 or is_done(index - 1)


## Pode entrar na fase? A porta final também exige todas as memórias.
func is_unlocked(index: int) -> bool:
	if not is_reachable(index):
		return false
	if LEVELS[index].get("needs_all_memories", false):
		var m := memory_status()
		return m.x >= m.y
	return true


## (memórias recuperadas, total) nas fases normais; o total só é conhecido
## nas fases já concluídas (o jogo grava o total ao concluir).
func memory_status() -> Vector2i:
	var got := 0
	var total := 0
	for i in LEVELS.size():
		if LEVELS[i].get("final", false):
			continue
		var d: Dictionary = progress.get(str(i), {})
		got += int(d.get("berries", 0))
		total += int(d.get("berries_total", 0))
	return Vector2i(got, total)


func level_info(index: int) -> Dictionary:
	return progress.get(str(index), {})


func complete_level(index: int, berries: int, berries_total: int, time: float, deaths: int) -> void:
	var key := str(index)
	var old: Dictionary = progress.get(key, {})
	var was_done: bool = old.get("done", false)
	var best_time: float = time if not was_done else minf(old.get("best_time", time), time)
	progress[key] = {
		"done": true,
		"berries": maxi(int(old.get("berries", 0)), berries),
		"berries_total": berries_total,
		"best_time": best_time,
		"deaths": deaths if not was_done else mini(int(old.get("deaths", deaths)), deaths),
	}
	map_node = index
	if not was_done:
		just_completed = index
	save_progress()


## Memórias já recuperadas em outras fases (formam a coroa da Saeda).
func memories_before(index: int) -> int:
	var n := 0
	for key in progress.keys():
		if int(key) != index:
			n += int(progress[key].get("berries", 0))
	return n


func reset_progress() -> void:
	progress = {}
	map_node = 0
	just_completed = -1
	awakened = false
	finished = false
	save_progress()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	for key in progress.keys():
		var d: Dictionary = progress[key]
		for field in d.keys():
			cfg.set_value("level_" + key, field, d[field])
	cfg.set_value("map", "node", map_node)
	cfg.set_value("meta", "awakened", awakened)
	cfg.set_value("meta", "finished", finished)
	cfg.save(SAVE_PATH)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	progress = {}
	for section in cfg.get_sections():
		if section.begins_with("level_"):
			var key := section.trim_prefix("level_")
			var d := {}
			for field in cfg.get_section_keys(section):
				d[field] = cfg.get_value(section, field)
			progress[key] = d
	map_node = int(cfg.get_value("map", "node", 0))
	awakened = bool(cfg.get_value("meta", "awakened", false))
	finished = bool(cfg.get_value("meta", "finished", false))


# -------------------------------------------------------------------- CENAS ----

## O poder do despertar está ativo agora (fase final e contagem não zerou)?
func power_on() -> bool:
	return LEVELS[clampi(current, 0, LEVELS.size() - 1)].get("final", false) and power_left > 0.0


## Dash infinito vale agora? (ajuda nas opções, ou poder desperto na fase final)
func dash_unlimited() -> bool:
	if Settings.infinite_dash:
		return true
	return LEVELS[clampi(current, 0, LEVELS.size() - 1)].get("infinite_dash", false) and power_left > 0.0


func start_level(index: int, skip_cutscene := false) -> void:
	current = clampi(index, 0, LEVELS.size() - 1)
	map_node = current
	# a fase final sempre começa com a cena do despertar (Enter pula)
	if LEVELS[current].get("final", false) and not skip_cutscene:
		get_tree().change_scene_to_file(AWAKEN_SCENE)
		return
	get_tree().change_scene_to_file(LEVEL_SCENE)


func go_credits() -> void:
	finished = true
	save_progress()
	get_tree().change_scene_to_file(CREDITS_SCENE)


func current_level_path() -> String:
	return LEVELS[clampi(current, 0, LEVELS.size() - 1)]["path"]


func go_intro() -> void:
	get_tree().change_scene_to_file(INTRO_SCENE)


func go_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


func go_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
