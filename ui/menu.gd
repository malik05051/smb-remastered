extends Control

const MAIN_SCENE = "res://main.tscn"

@onready var _play_button: Button = $PlayButton


func _ready():
	_play_button.grab_focus()
	_play_button.pressed.connect(_start_game)


func _start_game():
	StageManager.start_theme_music()
	get_tree().change_scene_to_file(MAIN_SCENE)
