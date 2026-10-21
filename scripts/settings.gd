extends Node
## Configurações do jogador (autoload "Settings"), salvas em user://settings.cfg.
## Volume (0 a 10), tela cheia e opções de ajuda ("modo assistido").

const PATH := "user://settings.cfg"
const SPEEDS := [1.0, 0.9, 0.8, 0.7]

var music_level := 7          # 0..10 (7 = volume padrão)
var sfx_level := 7
var fullscreen := false
var infinite_dash := false    # ajuda: o dash recarrega sempre
var speed_index := 0          # ajuda: jogo mais lento (SPEEDS)
var title_style := 0          # tela inicial: 0 = nova (flores), 1 = clássica (retrato)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()


func game_speed() -> float:
	return SPEEDS[clampi(speed_index, 0, SPEEDS.size() - 1)]


## Aplica tudo que vale para o jogo inteiro (áudio e janela).
func apply() -> void:
	Sfx.set_levels(music_level, sfx_level)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_level)
	cfg.set_value("audio", "sfx", sfx_level)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("assist", "infinite_dash", infinite_dash)
	cfg.set_value("assist", "speed", speed_index)
	cfg.set_value("video", "title_style", title_style)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_level = clampi(int(cfg.get_value("audio", "music", 7)), 0, 10)
	sfx_level = clampi(int(cfg.get_value("audio", "sfx", 7)), 0, 10)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	infinite_dash = bool(cfg.get_value("assist", "infinite_dash", false))
	speed_index = clampi(int(cfg.get_value("assist", "speed", 0)), 0, SPEEDS.size() - 1)
	title_style = clampi(int(cfg.get_value("video", "title_style", 0)), 0, 1)
