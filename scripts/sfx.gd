extends Node
## Áudio do jogo (autoload "Sfx"): efeitos e música em loop.
## Uso: Sfx.play("dash")  ·  Sfx.play("step", -10.0, 1.1)  ·  Sfx.set_music_volume(-12.0)
## Os arquivos ficam em assets/audio/ (.wav).

const SOUNDS := {
	"jump": preload("res://assets/audio/jump.wav"),
	"land": preload("res://assets/audio/land.wav"),
	"dash": preload("res://assets/audio/dash.wav"),
	"step": preload("res://assets/audio/step.wav"),
	"death": preload("res://assets/audio/death.wav"),
	"berry": preload("res://assets/audio/berry.wav"),
	"crystal": preload("res://assets/audio/crystal.wav"),
	"checkpoint": preload("res://assets/audio/checkpoint.wav"),
	"finish": preload("res://assets/audio/finish.wav"),
	"select": preload("res://assets/audio/select.wav"),
	"confirm": preload("res://assets/audio/confirm.wav"),
	"unlock": preload("res://assets/audio/unlock.wav"),
}
const TRACKS := {
	"dusty": preload("res://assets/music/dusty_horizon.ogg"),
	"last": preload("res://assets/music/last_light.ogg"),
	"ultima": preload("res://assets/music/ultima_luz.ogg"),
}
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next := 0
var _music_off_db := 0.0   # ajuste vindo das opções (0 = padrão)
var _sfx_off_db := 0.0
var _track := ""
var _fade_db := 0.0:
	set(v):
		_fade_db = v
		_update_music()
var _duck_db := 0.0        # abaixa a música em menus (pausa)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for k in TRACKS:
		TRACKS[k].loop = true
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	add_child(_music)


## Toca uma faixa em loop. Se já é a que está tocando, não reinicia.
func play_music(track: String, fade_in := 1.5) -> void:
	if not TRACKS.has(track) or (_track == track and _music.playing):
		return
	_track = track
	_music.stream = TRACKS[track]
	_music.play()
	if fade_in > 0.0:
		_fade_db = -40.0
		create_tween().tween_property(self, "_fade_db", 0.0, fade_in)


func stop_music(fade_out := 1.0) -> void:
	_track = ""
	var tw := create_tween()
	tw.tween_property(self, "_fade_db", -40.0, fade_out)
	tw.tween_callback(func() -> void:
		_music.stop()
		_fade_db = 0.0)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not SOUNDS.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = SOUNDS[sound]
	p.volume_db = volume_db + _sfx_off_db
	p.pitch_scale = pitch
	p.play()


func set_music_volume(db: float) -> void:
	_duck_db = db - (-10.0)    # -10 = normal; valores menores abaixam a música
	_update_music()


## Níveis de 0 a 10 vindos das opções (7 = volume padrão).
func set_levels(music_level: int, sfx_level: int) -> void:
	_music_off_db = _level_to_db(music_level)
	_sfx_off_db = _level_to_db(sfx_level)
	_update_music()


func _level_to_db(level: int) -> float:
	if level <= 0:
		return -80.0
	return linear_to_db(level / 7.0)


func _update_music() -> void:
	if _music:
		_music.volume_db = -10.0 + _music_off_db + _duck_db + _fade_db
