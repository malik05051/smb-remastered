class_name Flag
extends Node2D

const SLIDE_DURATION_SEC = 0.8
const WALK_DURATION_SEC = 0.6

@onready var cloth: Node2D = $Cloth

var _touched := false


func _on_trigger_body_entered(body: Node):
	if _touched or not body is Player:
		return

	_touched = true

	var cloth_tween = get_tree().create_tween()
	cloth_tween.tween_property(cloth, "position:y", 0.0, SLIDE_DURATION_SEC)

	body.finish_level(global_position.x, global_position.y, SLIDE_DURATION_SEC, WALK_DURATION_SEC)
