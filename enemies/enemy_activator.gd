class_name EnemyActivator
extends Node

# Keeps an enemy dormant until Mario gets close, then wakes it for good.
#
# This deliberately does NOT key off what the window happens to show. The NES
# screen was 256px wide, so an enemy woke when the scroll brought it within
# roughly half a screen ahead of Mario. If the game window is wider than that
# (it usually is on a 16:9 display), keying off visibility would wake enemies
# far too early -- the first Goomba of 1-1 would set off at level load and walk
# into Mario's spawn point while the player is still standing still.

const WAKE_AHEAD_PX = 144.0

var _target: Node2D


func _ready():
	_target = get_parent()
	# An explicit flag rather than set_physics_process(): the global Physics
	# autoload toggles physics processing on every node under the stage when
	# Mario transforms, which would silently wake every dormant enemy.
	_target.is_dormant = true


func _physics_process(_delta):
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	if _target.global_position.x - player.global_position.x <= WAKE_AHEAD_PX:
		_target.is_dormant = false
		# Once awake it stays awake; this node has nothing left to do.
		queue_free()
