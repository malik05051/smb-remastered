class_name Fireball
extends CharacterBody2D

# Fire Mario's projectile: travels horizontally, hops off the ground and bursts
# on the first wall or enemy it meets, as in the NES original.

const SPEED = 180.0
const BOUNCE_SPEED = -240.0
const GRAVITY = 1350.0
const MAX_FALL_SPEED = 270.0
const SPIN_SPEED = 12.0

# Safety net so a fireball that somehow never hits anything cannot leak.
const LIFETIME_SEC = 8.0

@onready var visual: Node2D = $Visual

var direction := 1.0


func launch(from_position: Vector2, facing_left: bool):
	global_position = from_position
	direction = -1.0 if facing_left else 1.0


func _ready():
	get_tree().create_timer(LIFETIME_SEC).timeout.connect(_burst)


func _physics_process(delta):
	velocity.x = SPEED * direction
	velocity.y = minf(MAX_FALL_SPEED, velocity.y + GRAVITY * delta)

	move_and_slide()

	visual.rotation += SPIN_SPEED * delta * direction

	# Hops along the floor rather than rolling to a stop.
	if is_on_floor():
		velocity.y = BOUNCE_SPEED

	# A wall (or ceiling) ends the fireball.
	if is_on_wall():
		_burst()


func _on_hitbox_area_entered(area: Area2D):
	var body = area.get_parent()

	if not body.is_in_group("enemies"):
		return

	if "is_alive" in body and not body.is_alive:
		return

	if body.has_method("stomp"):
		body.stomp()

	StageManager.add_score(StageManager.POINTS_FIREBALL_KILL)
	_burst()


func _burst():
	if is_queued_for_deletion():
		return

	queue_free()
