extends Node

signal theme_changed
signal game_over
signal life_lost
signal level_completed
signal coin_collected
signal score_changed
signal player_died

const STARTING_LIVES = 3

# How long the GAME OVER screen stays up before the run restarts.
const GAME_OVER_SCREEN_SEC: float = 3.0

# Prolonger la durée de l'affichage des vies restantes pour que le son joue jusqu'à la fin.
const LIFE_LOST_SCREEN_SEC: float = 3.0

# Point values from the NES original.
const POINTS_COIN = 200
const POINTS_POWERUP = 1000
const POINTS_FIREBALL_KILL = 200
# Time left is converted to points at the end of a stage.
const POINTS_PER_TIME_UNIT = 50
# Every 100 coins grants an extra life, as in the original.
const COINS_PER_EXTRA_LIFE = 100

var lives: int = STARTING_LIVES
var coins: int = 0
var score: int = 0

enum StageTheme {
	OVERWORLD,
	UNDERGROUND,
}

const _THEMES = {
	StageTheme.OVERWORLD: preload("res://themes/overworld.tres"),
	StageTheme.UNDERGROUND: preload("res://themes/underground.tres"),
}

# No underground track yet -- _play_theme_music() just stays silent for a
# theme with no entry here, so this is safe to leave partial.
const _THEME_MUSIC = {
	StageTheme.OVERWORLD: preload("res://assets/sounds/Super Mario Bros Overworld Theme.mp3"),
}

var theme: StageTheme = StageTheme.OVERWORLD:
	set(value):
		theme = value
		var data = _THEMES[value] as ThemeData
		_get_tile_map().tile_set.get_source(0).texture = data.tile_set_texture
		RenderingServer.set_default_clear_color(data.background_color)
		_play_theme_music()
		theme_changed.emit(value)

@onready var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready():
	add_child(_music_player)


func start_theme_music():
	_play_theme_music()


func _play_theme_music():
	var stream = _THEME_MUSIC.get(theme)

	_music_player.stream = stream

	if stream:
		_music_player.play()


func stop_music():
	_music_player.stop()


func lose_life():
	lives -= 1

	# Mostly a no-op by the time this runs: die() already cut the music the
	# instant Mario died. Still needed for the timer-runs-out case, which
	# calls lose_life() directly without ever going through die().
	stop_music()

	if lives <= 0:
		game_over.emit()
		# Let the HUD hold its GAME OVER screen for a moment: restart_game()
		# reloads the stage, which rebuilds the HUD and would wipe the message
		# in the same frame it appeared.
		# restart_game() clears the score itself, hence no reset here.
		await get_tree().create_timer(GAME_OVER_SCREEN_SEC).timeout
		restart_game()
		return

	# Same reason as the game over screen: the reload rebuilds the HUD, so the
	# interstitial has to be given its moment before that happens.
	life_lost.emit(lives)
	await get_tree().create_timer(LIFE_LOST_SCREEN_SEC).timeout

	get_tree().reload_current_scene()
	_play_theme_music()


func restart_game():
	lives = STARTING_LIVES
	coins = 0
	score = 0
	score_changed.emit()
	coin_collected.emit()
	get_tree().reload_current_scene()
	_play_theme_music()


func level_complete():
	stop_music()
	level_completed.emit()


func add_score(amount: int):
	score += amount
	score_changed.emit()


func add_life():
	lives += 1


func collect_coin():
	coins += 1
	add_score(POINTS_COIN)

	if coins >= COINS_PER_EXTRA_LIFE:
		coins -= COINS_PER_EXTRA_LIFE
		add_life()

	coin_collected.emit()


func _get_tile_map() -> TileMap:
	return get_node("/root/Main/Stage/TileMap")
