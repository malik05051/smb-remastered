class_name FireFlower
extends StaticBody2D

@onready var sprite: Node2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape

var spawner: Node = null


func _ready():
	if spawner is QuestionBlock:
		setup_block_animation()


func setup_block_animation():
	sprite.visible = false
	collision_shape.disabled = true

	await spawner.hit_finished

	var _z_index = sprite.z_index
	sprite.z_index = -1
	sprite.visible = true
	sprite.position = Vector2.DOWN * 16

	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "position", Vector2.ZERO, 1)

	await tween.finished

	sprite.z_index = _z_index
	collision_shape.disabled = false
