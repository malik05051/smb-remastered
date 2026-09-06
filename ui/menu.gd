extends Control

const MAIN_SCENE = "res://main.tscn"

@onready var _play_button: Button = $PlayButton
@onready var _flicker_timer: Timer = $PlayButton/FlickerTimer
@onready var _music: AudioStreamPlayer = $Music

var _flicker_colors: Array[Color] = [
	Color("e69c21"),
	Color("9c4a00"),
	Color("522100"),
]
var _flicker_index := 0

func _ready():
	_play_button.grab_focus()
	_play_button.pressed.connect(_start_game)

	_play_button.add_theme_color_override("font_color", Color.WHITE)
	_play_button.add_theme_color_override("font_focus_color", Color.WHITE)
	_play_button.add_theme_color_override("font_hover_color", Color.WHITE)

	_play_button.mouse_entered.connect(_on_hover_start)
	_play_button.mouse_exited.connect(_on_hover_end)
	_flicker_timer.timeout.connect(_on_flicker_tick)

	# The source file isn't imported as a looping stream, so loop it manually.
	_music.finished.connect(_music.play)
	_music.play()

func _on_hover_start():
	_flicker_index = 0
	_flicker_timer.start()

func _on_hover_end():
	_flicker_timer.stop()
	_play_button.add_theme_color_override("font_color", Color.WHITE)
	_play_button.add_theme_color_override("font_focus_color", Color.WHITE)
	_play_button.add_theme_color_override("font_hover_color", Color.WHITE)

func _on_flicker_tick():
	_flicker_index = (_flicker_index + 1) % _flicker_colors.size()
	var c = _flicker_colors[_flicker_index]
	_play_button.add_theme_color_override("font_color", c)
	_play_button.add_theme_color_override("font_hover_color", c)

func _start_game():
	_music.stop()
	StageManager.start_theme_music()
	get_tree().change_scene_to_file(MAIN_SCENE)
