class_name Coin
extends Area2D

# A coin sitting in the level, collected by touching it. Blocks spawn the
# separate coin particle instead; this is the free-standing pickup.


func _on_body_entered(body: Node):
	if not body is Player:
		return

	StageManager.collect_coin()
	queue_free()
