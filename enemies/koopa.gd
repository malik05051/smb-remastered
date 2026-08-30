class_name Koopa
extends CharacterBody2D

# Koopa Troopa: walks like a Goomba, but stomping it leaves a shell instead of
# killing it. The shell can then be kicked and slides along killing whatever it
# meets, as in the NES original.

enum KoopaState { WALKING, SHELL, SLIDING }

const WALK_SPEED = 25.0
const SHELL_SPEED = 160.0

# How long a kicked-free shell sits before the Koopa climbs back into it.
const REVIVE_SEC = 6.0

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite

@export var is_facing_left: bool = true

# The player treats any enemy with is_alive == false as inert, so a shell has
# to stay "alive" for Mario to be able to kick it.
var is_alive: bool = true

var koopa_state: KoopaState = KoopaState.WALKING

var _revive_timer := 0.0


func _physics_process(delta):
	var collision = get_last_slide_collision()

	if collision:
		var normal = collision.get_normal()
		if normal.x:
			is_facing_left = normal.x < 0

	match koopa_state:
		KoopaState.WALKING:
			velocity.x = -WALK_SPEED if is_facing_left else WALK_SPEED
		KoopaState.SHELL:
			velocity.x = 0.0
			_revive_timer -= delta
			if _revive_timer <= 0.0:
				_wake_up()
		KoopaState.SLIDING:
			velocity.x = -SHELL_SPEED if is_facing_left else SHELL_SPEED

	velocity.y = min(Physics.MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)

	# The art is drawn facing left, so mirror it when heading the other way.
	visual.scale.x = 1.0 if is_facing_left else -1.0

	move_and_slide()


# Called by the player when jumped on.
func stomp():
	match koopa_state:
		KoopaState.WALKING:
			_enter_shell()
		KoopaState.SLIDING:
			# Landing on a moving shell brings it to a halt.
			_enter_shell()
		KoopaState.SHELL:
			_revive_timer = REVIVE_SEC


func can_be_kicked() -> bool:
	return koopa_state == KoopaState.SHELL


func kick(direction: float):
	koopa_state = KoopaState.SLIDING
	is_facing_left = direction < 0.0


func _enter_shell():
	koopa_state = KoopaState.SHELL
	_revive_timer = REVIVE_SEC
	sprite.play("shell")


func _wake_up():
	koopa_state = KoopaState.WALKING
	sprite.play("walk")


func _on_hitbox_area_entered(area: Area2D):
	var body = area.get_parent()

	if body is Player:
		if body.has_cooldown:
			return
		is_facing_left = not is_facing_left
		return

	if not body.is_in_group("enemies"):
		return

	# A sliding shell bowls other enemies over.
	if koopa_state == KoopaState.SLIDING:
		if body.has_method("stomp"):
			body.stomp()
			StageManager.add_score(StageManager.POINTS_FIREBALL_KILL)
		return

	if koopa_state == KoopaState.WALKING:
		is_facing_left = not is_facing_left
