class_name Flag
extends Node2D

const SLIDE_DURATION_SEC = 0.8
const WALK_DURATION_SEC = 0.6

const POLE_HEIGHT = 128.0

# Points awarded by how high up the pole Mario grabs it, lowest band first,
# matching the original's 100 / 400 / 800 / 2000 / 5000 scale.
const HEIGHT_POINTS = [100, 400, 800, 2000, 5000]

@onready var cloth: Node2D = $Cloth

var _touched := false


func _on_trigger_body_entered(body: Node):
	if _touched or not body is Player:
		return

	_touched = true

	StageManager.add_score(_points_for_height(body.global_position.y))

	var cloth_tween = get_tree().create_tween()
	cloth_tween.tween_property(cloth, "position:y", 0.0, SLIDE_DURATION_SEC)

	body.finish_level(global_position.x, global_position.y, SLIDE_DURATION_SEC, WALK_DURATION_SEC)


func _points_for_height(grab_y: float) -> int:
	# 0.0 at the foot of the pole, 1.0 at the very top.
	var height_ratio = clampf((global_position.y - grab_y) / POLE_HEIGHT, 0.0, 1.0)
	var band = int(height_ratio * HEIGHT_POINTS.size())

	return HEIGHT_POINTS[mini(band, HEIGHT_POINTS.size() - 1)]
