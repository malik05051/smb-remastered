class_name LevelBounds
extends Object

# Where the playable area ends, so that enemies can be removed once they leave
# it. On the NES an enemy that walks off the left edge or drops into a pit is
# simply deleted; here nothing did that, so they kept simulating forever --
# drifting past the camera's left limit in plain sight, or falling for
# thousands of pixels.


# The stage's Zone marks the level, and the camera clamps its view to exactly
# that rect (see camera.gd), so "outside this rect" and "outside the visible
# world" are the same thing.
static func of(node: Node2D) -> Rect2:
	for zone in node.get_tree().get_nodes_in_group("zones"):
		var shape := zone.get_child(0) as CollisionShape2D

		if shape == null or not shape.shape is RectangleShape2D:
			continue

		var size: Vector2 = shape.shape.size

		return Rect2(shape.global_position - size / 2.0, size)

	return Rect2()


# An enemy has left the level for good once it is off screen AND outside the
# bounds: the camera cannot scroll past them, so anything out there walked off
# the left edge or fell down a pit.
#
# This has to be driven by the enabler's screen_exited signal rather than
# checked in _physics_process, because that same enabler sets the enemy's
# process_mode to DISABLED as it leaves the screen -- roughly 8px out, before
# it ever reaches the bounds. A per-frame check is switched off just before it
# would fire, which left the enemy frozen and invisible one tile off screen
# instead of deleted.
static func despawn_when_outside(enemy: Node2D, bounds: Rect2):
	var enabler := enemy.get_node_or_null("VisibilityEnabler") as VisibleOnScreenEnabler2D

	if enabler == null or not bounds.has_area():
		return

	enabler.screen_exited.connect(
		func():
			if not bounds.has_point(enemy.global_position):
				enemy.queue_free()
	)
