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
## Teclas personalizadas: ação -> código físico da tecla (vazio = padrão do input_setup.gd)
var key_map := {}
const KEY_ACTIONS := {
	"move_left": "ESQUERDA", "move_right": "DIREITA", "move_up": "CIMA", "move_down": "BAIXO",
	"jump": "PULO", "dash": "DASH", "retry": "VOLTAR AO CHECKPOINT",
}
const KEY_DEFAULTS := {
	"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "move_up": KEY_UP, "move_down": KEY_DOWN,
	"jump": KEY_Z, "dash": KEY_X, "retry": KEY_R,
}
var title_style := 0          # tela inicial: 0 = nova (flores), 1 = clássica (retrato)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()


func game_speed() -> float:
	return SPEEDS[clampi(speed_index, 0, SPEEDS.size() - 1)]


## Aplica tudo que vale para o jogo inteiro (áudio e janela).
func apply() -> void:
	apply_keys()
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
	cfg.set_value("keys", "map", key_map)
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
	var km = cfg.get_value("keys", "map", {})
	key_map = km if km is Dictionary else {}
	title_style = clampi(int(cfg.get_value("video", "title_style", 0)), 0, 1)


## Troca as teclas do teclado das ações personalizadas (controle/joystick continuam iguais).
func apply_keys() -> void:
	for action in key_map:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		var e := InputEventKey.new()
		e.physical_keycode = int(key_map[action]) as Key
		InputMap.action_add_event(action, e)


func key_for(action: String) -> int:
	return int(key_map.get(action, KEY_DEFAULTS.get(action, KEY_NONE)))


func key_name(action: String) -> String:
	var n := OS.get_keycode_string(key_for(action) as Key).to_upper()
	var pt := {"LEFT": "SETA ESQ.", "RIGHT": "SETA DIR.", "UP": "SETA CIMA", "DOWN": "SETA BAIXO", "SPACE": "ESPAÇO"}
	return pt.get(n, n)


func reset_keys() -> void:
	key_map.clear()
	# recria os eventos padrão do teclado
	var defaults := {
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D], "move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S], "jump": [KEY_Z, KEY_SPACE, KEY_K], "dash": [KEY_X, KEY_SHIFT, KEY_J],
		"retry": [KEY_R],
	}
	for action in defaults:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		for k in defaults[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k as Key
			InputMap.action_add_event(action, e)
