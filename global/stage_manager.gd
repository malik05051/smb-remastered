extends Node

signal theme_changed
signal game_over
signal level_completed
signal coin_collected
signal score_changed

const STARTING_LIVES = 3

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

var theme: StageTheme = StageTheme.OVERWORLD:
	set(value):
		theme = value
		var data = _THEMES[value] as ThemeData
		_get_tile_map().tile_set.get_source(0).texture = data.tile_set_texture
		RenderingServer.set_default_clear_color(data.background_color)
		theme_changed.emit(value)


func lose_life():
	lives -= 1

	# Le score repart de zero a chaque vie perdue, pas seulement au game over.
	score = 0
	score_changed.emit()

	if lives <= 0:
		game_over.emit()
		# Nothing used to act on game_over, so running out of lives left the
		# game sitting there with a dead Mario and no way to carry on.
		_restart_game()
	else:
		get_tree().reload_current_scene()


func _restart_game():
	lives = STARTING_LIVES
	coins = 0
	score = 0
	score_changed.emit()
	coin_collected.emit()
	get_tree().reload_current_scene()


func level_complete():
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
