extends Node

signal theme_changed
signal game_over
signal life_lost
signal level_completed
signal coin_collected
signal score_changed

const STARTING_LIVES = 3

# How long the GAME OVER screen stays up before the run restarts.
const GAME_OVER_SCREEN_SEC: float = 3.0

# How long the "WORLD 1-1 / MARIO x N" screen stays up between lives.
const LIFE_LOST_SCREEN_SEC: float = 2.0

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

	if lives <= 0:
		game_over.emit()
		# Let the HUD hold its GAME OVER screen for a moment: _restart_game()
		# reloads the stage, which rebuilds the HUD and would wipe the message
		# in the same frame it appeared.
		# _restart_game() clears the score itself, hence no reset here.
		await get_tree().create_timer(GAME_OVER_SCREEN_SEC).timeout
		_restart_game()
		return

	# Losing a life clears the score, not just running out of them. This is a
	# deliberate departure from the NES, which keeps it until a full restart.
	score = 0
	score_changed.emit()

	# Same reason as the game over screen: the reload rebuilds the HUD, so the
	# interstitial has to be given its moment before that happens.
	life_lost.emit(lives)
	await get_tree().create_timer(LIFE_LOST_SCREEN_SEC).timeout

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
