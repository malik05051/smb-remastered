extends Node

signal theme_changed
signal game_over
signal level_completed

const STARTING_LIVES = 3

var lives: int = STARTING_LIVES

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
	else:
		get_tree().reload_current_scene()


func level_complete():
	level_completed.emit()


func _get_tile_map() -> TileMap:
	return get_node("/root/Main/Stage/TileMap")
