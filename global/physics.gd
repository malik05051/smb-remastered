extends Node

const GRAVITY = 1300.0
const MAX_FALL_SPEED = 270.0
const JUMP_SPEED = -240.0

const DEFAULT_TICKS_PER_SECOND = 60

func _process(_delta):
	var refresh_rate = round(DisplayServer.screen_get_refresh_rate())
	var ticks = int(refresh_rate) if refresh_rate > 0 else DEFAULT_TICKS_PER_SECOND

	# Only assign when it actually changes. Writing physics_ticks_per_second
	# every single frame resets the physics step accumulator, which shows up as
	# small recurring hitches.
	if Engine.physics_ticks_per_second != ticks:
		Engine.physics_ticks_per_second = ticks


func disable():
	_toggle_children_physics(_get_level(), false)
	get_node("/root/Logger").append("Physics disabled")


func enable():
	_toggle_children_physics(_get_level(), true)
	get_node("/root/Logger").append("Physics enabled")


func _get_level() -> Node:
	return get_node("/root/Main/Stage")


func _toggle_children_physics(node: Node, value: bool):
	for child in node.get_children():
		child.set_physics_process(value)

		if child is AnimatedSprite2D:
			if value:
				child.play()
			else:
				child.stop()

		_toggle_children_physics(child, value)
