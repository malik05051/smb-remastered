extends CanvasLayer

# The NES original gives 400 time units in most stages (1-1 included), and one
# unit lasts 0.4s (24 frames at 60Hz NTSC) rather than a real second.
const STARTING_TIME: int = 400

# How fast the end-of-stage time->points tally ticks.
const TIME_BONUS_TICK_SEC: float = 0.02

@onready var _timer_label: Label = $Control/HBoxContainer/Timer
@onready var _countdown: Timer = $Countdown
@onready var _message_label: Label = $Control/Message
@onready var _coins_label: Label = $Control/HBoxContainer/Coins
@onready var _score_label: Label = $Control/HBoxContainer/Score

var time_left: int = STARTING_TIME


func _ready():
	_update_label()
	_update_coins_label()
	_update_score_label()
	_countdown.timeout.connect(_on_countdown_timeout)
	StageManager.level_completed.connect(_on_level_completed)
	StageManager.coin_collected.connect(_update_coins_label)
	StageManager.score_changed.connect(_update_score_label)


func _on_countdown_timeout():
	time_left = max(0, time_left - 1)
	_update_label()

	if time_left == 0:
		StageManager.lose_life()


func _on_level_completed():
	_countdown.stop()
	_message_label.visible = true
	_convert_time_to_score()


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
