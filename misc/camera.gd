extends Camera2D

var _bounds_origin = Vector2()
var _bounds_size = Vector2()


func _ready():
	get_tree().get_root().connect("size_changed", _update_zoom)


func set_bounds(bounds: CollisionShape2D):
	_bounds_origin = bounds.global_position
	_bounds_size = bounds.shape.extents * 2

	limit_left = int(_bounds_origin.x - _bounds_size.x / 2)
	limit_right = int(_bounds_origin.x + _bounds_size.x / 2)
	limit_top = int(_bounds_origin.y - _bounds_size.y / 2)
	limit_bottom = int(_bounds_origin.y + _bounds_size.y / 2)

	_update_zoom()


func _update_zoom():
	# size_changed is connected in _ready(), but the bounds only arrive once the
	# player enters a Zone a few frames later. Resizing the window before that
	# divides by a zero-sized bounds and yields an infinite zoom, which blanks
	# the entire world while the HUD keeps drawing (it is a CanvasLayer) -- so
	# the game looks like it disappeared. Wait until the bounds are real.
	if _bounds_size.x <= 0.0 or _bounds_size.y <= 0.0:
		return

	var viewport_rect = get_viewport_rect()
	var zoom_factor = max(
		viewport_rect.size.x / _bounds_size.x, viewport_rect.size.y / _bounds_size.y
	)

	zoom = Vector2(zoom_factor, zoom_factor)
