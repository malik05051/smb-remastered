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

# Hit by a fireball: on the NES the enemy flips over and tumbles off the
# screen instead of being flattened.
const FLING_UP_SPEED = -260.0
const FLING_SIDE_SPEED = 70.0
const FLING_LIFETIME_SEC = 3.0

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var fling_sound: AudioStreamPlayer = $FlingSound

@export var is_facing_left: bool = true

# The player treats any enemy with is_alive == false as inert, so a shell has
# to stay "alive" for Mario to be able to kick it.
var is_alive: bool = true

var koopa_state: KoopaState = KoopaState.WALKING

var _revive_timer := 0.0
var _flung: bool = false


func _ready():
	LevelBounds.despawn_when_outside(self, LevelBounds.of(self))


func _physics_process(delta):
	if _flung:
		# No collision left, so integrate by hand and let it fall through the
		# level geometry.
		velocity.y = min(Physics.MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)
		global_position += velocity * delta
		return

	# See goomba.gd: the last slide collision is normally the floor, so walls
	# went unnoticed and the Koopa (or a sliding shell) stalled against them.
	if is_on_wall():
		var normal = get_wall_normal()
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


func fling(direction: float):
	if _flung:
		return

	_flung = true
	is_alive = false
	fling_sound.play()
	# A flung shell must not stay kickable on its way out.
	koopa_state = KoopaState.WALKING

	# Nothing may stop it on the way out: the visibility enabler would freeze
	# it the moment it leaves the screen, and its collision shape would catch
	# it on the very ground it is meant to fall through.
	var enabler = get_node_or_null("VisibilityEnabler")
	if enabler:
		enabler.queue_free()

	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	$CollisionShape.set_deferred("disabled", true)
	$Hitbox.set_deferred("monitoring", false)
	visual.scale.y = -1.0
	velocity = Vector2(FLING_SIDE_SPEED * direction, FLING_UP_SPEED)
	get_tree().create_timer(FLING_LIFETIME_SEC).connect("timeout", queue_free)


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

	# Mario never turns an enemy around on the NES; only other enemies do.
	if body is Player:
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
