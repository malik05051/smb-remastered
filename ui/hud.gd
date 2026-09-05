extends CanvasLayer

# 400 time units, as the NES original gives in most stages (1-1 included).
# One unit lasts a real second here. The NES runs them at 0.4s (24 frames at
# 60Hz NTSC), which reads as the clock racing -- roughly 2.5 units gone per
# second -- so the stage is deliberately given real seconds instead.
const STARTING_TIME: int = 400

# How fast the end-of-stage time->points tally ticks.
const TIME_BONUS_TICK_SEC: float = 0.02

# How long the "COURSE CLEAR!" screen stays up, after the time->points tally
# finishes, before the game restarts.
const COURSE_CLEAR_RESTART_DELAY_SEC: float = 2.0

@onready var _timer_label: Label = $Control/HBoxContainer/Timer
@onready var _countdown: Timer = $Countdown
@onready var _message_label: Label = $Control/Message
@onready var _coins_label: Label = $Control/HBoxContainer/Coins
@onready var _score_label: Label = $Control/HBoxContainer/Score
@onready var _blackout: ColorRect = $Blackout
@onready var _world_label: Label = $Control/HBoxContainer/World
@onready var _life_lost_sound: AudioStreamPlayer = $LifeLostSound

var time_left: int = STARTING_TIME


func _ready():
	_update_label()
	_update_coins_label()
	_update_score_label()
	_countdown.timeout.connect(_on_countdown_timeout)
	StageManager.level_completed.connect(_on_level_completed)
	StageManager.game_over.connect(_on_game_over)
	StageManager.life_lost.connect(_on_life_lost)
	StageManager.coin_collected.connect(_update_coins_label)
	StageManager.score_changed.connect(_update_score_label)


func _on_countdown_timeout():
	time_left = max(0, time_left - 1)
	_update_label()

	if time_left == 0:
		StageManager.lose_life()


func _on_level_completed():
	_countdown.stop()
	_show_message("COURSE CLEAR!")
	await _convert_time_to_score()
	await get_tree().create_timer(COURSE_CLEAR_RESTART_DELAY_SEC).timeout
	StageManager.restart_game()


# Out of lives. Black out the stage and say so: without this the run simply
# restarted, which looked exactly like an ordinary death except that the coins
# and the score had vanished.
func _on_game_over():
	_countdown.stop()
	_blackout.visible = true
	_show_message("GAME OVER")


# Between lives the NES blacks the stage out and shows which world is being
# retried and how many lives are left, so a death reads as a death rather than
# as the level abruptly starting over.
func _on_life_lost(lives_left: int):
	_countdown.stop()
	_blackout.visible = true
	_life_lost_sound.play()
	_show_message("WORLD %s\n\nMARIO \u00d7  %d" % [_world(), lives_left])


# Taken from the label rather than hardcoded, so the two can never disagree.
func _world() -> String:
	var lines = _world_label.text.split("\n")
	return lines[1] if lines.size() > 1 else lines[0]


func _show_message(text: String):
	_message_label.text = text
	_message_label.visible = true


# The original converts the time left into points at the end of a stage,
# ticking the counter down rather than awarding it all at once.
func _convert_time_to_score():
	while time_left > 0:
		time_left -= 1
		StageManager.add_score(StageManager.POINTS_PER_TIME_UNIT)
		_update_label()
		await get_tree().create_timer(TIME_BONUS_TICK_SEC).timeout


func _update_label():
	_timer_label.text = "TIME\n%03d" % time_left


func _update_coins_label():
	_coins_label.text = "\n  ×%02d" % StageManager.coins


func _update_score_label():
	_score_label.text = "MARIO\n%06d" % StageManager.score
