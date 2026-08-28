extends CanvasLayer

const STARTING_TIME: int = 300

@onready var _timer_label: Label = $Control/HBoxContainer/Timer
@onready var _countdown: Timer = $Countdown

var time_left: int = STARTING_TIME


func _ready():
	_update_label()
	_countdown.timeout.connect(_on_countdown_timeout)


func _on_countdown_timeout():
	time_left = max(0, time_left - 1)
	_update_label()

	if time_left == 0:
		StageManager.lose_life()


func _update_label():
	_timer_label.text = "Time\n%4d" % time_left
