class_name Goomba
extends CharacterBody2D

const SPEED: float = 30.0
const DESPAWN_TIME_SEC: float = 1.0

# Hit by a fireball: on the NES the enemy flips over and tumbles off the
# screen instead of being flattened.
const FLING_UP_SPEED = -260.0
const FLING_SIDE_SPEED = 70.0
const FLING_LIFETIME_SEC = 3.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var fling_sound: AudioStreamPlayer = $FlingSound

@export var is_facing_left: bool = true

var is_alive: bool = true
var _flung: bool = false

const _THEMES = {
	StageManager.StageTheme.OVERWORLD: preload("res://enemies/goomba_frames_overworld.tres"),
	StageManager.StageTheme.UNDERGROUND: preload("res://enemies/goomba_frames_underground.tres"),
}


func _ready():
	LevelBounds.despawn_when_outside(self, LevelBounds.of(self))
	_set_theme(StageManager.theme)
	StageManager.connect("theme_changed", _set_theme)


func _physics_process(delta):
	if _flung:
		# No collision left, so integrate by hand and let it fall through the
		# level geometry.
		velocity.y = min(Physics.MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)
		global_position += velocity * delta
		return

	# get_last_slide_collision() only reports the *last* contact of the previous
	# move, which on the ground is usually the floor -- so walking into a wall
	# often went unnoticed and the Goomba pushed against it forever. is_on_wall()
	# looks at every contact instead.
	if is_on_wall():
		var normal = get_wall_normal()
		if normal.x:
			is_facing_left = normal.x < 0

	if is_alive:
		velocity.x = -SPEED if is_facing_left else SPEED
	else:
		velocity.x = 0.0

	velocity.y = min(Physics.MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)

	move_and_slide()


func fling(direction: float):
	if _flung:
		return

	_flung = true
	is_alive = false
	fling_sound.play()

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
	sprite.flip_v = true
	velocity = Vector2(FLING_SIDE_SPEED * direction, FLING_UP_SPEED)
	get_tree().create_timer(FLING_LIFETIME_SEC).connect("timeout", queue_free)


func stomp():
	sprite.play("stomp")
	is_alive = false

	get_tree().create_timer(DESPAWN_TIME_SEC).connect("timeout", queue_free)


func _set_theme(theme: StageManager.StageTheme):
	sprite.frames = _THEMES[theme]
	sprite.play(sprite.animation)


func _on_hitbox_area_entered(area: Area2D):
	var body = area.get_parent()

	# Only other enemies turn a Goomba around. Bumping into Mario used to flip
	# it too, which made a Goomba stood next to him jitter on the spot instead
	# of walking -- and on the NES it just walks straight into him.
	if body is Player:
		return

	is_facing_left = not is_facing_left


func _on_death_timer_timeout():
	queue_free()
