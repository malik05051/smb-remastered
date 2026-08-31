class_name LevelBounds
extends Object

# Where the playable area ends, so that enemies can be removed once they leave
# it. On the NES an enemy that walks off the left edge or drops into a pit is
# simply deleted; here nothing did that, so they kept simulating forever --
# drifting past the camera's left limit in plain sight, or falling for
# thousands of pixels.

# How far past the edge an enemy has to get before it is removed. Roughly one
# tile, which is enough for a 16px sprite to be fully hidden.
const MARGIN: float = 16.0


# The stage's Zone marks the visible bounds of the level; grow it slightly so
# things vanish just outside the frame rather than popping out of view.
static func of(node: Node2D) -> Rect2:
	for zone in node.get_tree().get_nodes_in_group("zones"):
		var shape := zone.get_child(0) as CollisionShape2D

		if shape == null or not shape.shape is RectangleShape2D:
			continue

		var size: Vector2 = shape.shape.size

		return Rect2(shape.global_position - size / 2.0, size).grow(MARGIN)

	return Rect2()
