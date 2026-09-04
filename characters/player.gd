extends CharacterBody2D

class_name Player

# Physics

# Formulae to convert the original game's sub-sub-sub pixels per frame units to
# pixels per second:

# Speed: x * (15 / 1024)
# Acceleration: x * (225 / 256)

const MIN_SPEED = 4.453125
const MAX_SPEED = 153.75
const MAX_WALK_SPEED = 93.75
const MAX_FALL_SPEED = 270.0
const MAX_FALL_SPEED_CAP = 240.0
const MIN_SLOW_DOWN_SPEED = 33.75

const WALK_ACCELERATION = 133.59375
const RUN_ACCELERATION = 200.390625
const WALK_FRICTION = 182.8125
const SKID_FRICTION = 365.625

# Jump physics vary based on horizontal speed thresholds
const JUMP_SPEED = [-240.0, -240.0, -300.0]
const LONG_JUMP_GRAVITY = [450.0, 421.875, 562.5]
const GRAVITY = [1575.0, 1350.0, 2025.0]

const SPEED_THRESHOLDS = [60, 138.75]

const STOMP_SPEED = 240.0
const STOMP_SPEED_CAP = -60.0

# The original allows at most two of Mario's fireballs on screen at a time.
const MAX_FIREBALLS = 2

const fireball_scene = preload("res://items/fireball.tscn")

const COOLDOWN_TIME_SEC = 3.0

# Points for stomping enemies without touching the ground in between, as in the
# original. Past the end of the list every further stomp awards an extra life.
const STOMP_POINTS = [100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000]

const DEATH_HOP_SPEED = -200.0
const DEATH_GRAVITY = 700.0
const DEATH_DELAY_SEC = 2.5

# Nodes
@onready var camera = get_node_or_null("Camera")

# Input
var is_facing_left = false
var is_running = false
var is_jumping = false
var is_falling = false
var is_skiding = false
var is_crouching = false

var _old_velocity = Vector2.ZERO

var input_axis = Vector2.ZERO
var speed_scale = 0.0

var min_speed = MIN_SPEED	
var max_speed = MAX_WALK_SPEED
var acceleration = WALK_ACCELERATION

var speed_threshold: int = 0

enum State { SMALL, BIG, FIRE }

var state = State.SMALL:
	set(value):
		if state != value:
			state = value
			
			match state:
				State.SMALL:
					transition_sprite.animation = "shrink"
				State.BIG, State.FIRE:
					transition_sprite.animation = "grow"
			
			transition_sprite.flip_h = sprite.flip_h
			animation_player.play("transition")
			
			Physics.disable()

var has_cooldown = false
var is_dead = false
var is_finishing = false
var _has_landed = false
var _stomp_combo = 0

var collected_item_ref: Node = null

# Nodes
@onready var sprite = $SmallSprite

@onready var small_sprite: AnimatedSprite2D = $SmallSprite
@onready var big_sprite: AnimatedSprite2D = $BigSprite
@onready var fire_sprite: AnimatedSprite2D = $FireSprite
@onready var transition_sprite: AnimatedSprite2D = $TransitionSprite

@onready var hitbox: Area2D = $Hitbox
@onready var small_hitbox_shape: CollisionShape2D = $Hitbox/Small
@onready var big_hitbox_shape: CollisionShape2D = $Hitbox/Big

@onready var small_collision_shape: CollisionPolygon2D = $SmallCollisionShape
@onready var big_collision_shape: CollisionPolygon2D = $BigCollisionShape

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var pitfall_sound: AudioStreamPlayer = $PitfallSound

func _ready():
	_update_tree()

func _process(_delta):
	if is_dead or is_finishing:
		return

	process_input()
	process_animation()

func _physics_process(delta):
	if is_dead:
		velocity.y += DEATH_GRAVITY * delta
		position += velocity * delta
		return

	if is_on_floor():
		_has_landed = true
		_stomp_combo = 0

	if _has_landed and camera and global_position.y > camera.limit_bottom:
		pitfall_sound.play()
		die()
		return

	process_jump(delta)
	process_walk(delta)
	process_bounds_collision()

	_old_velocity = velocity

	move_and_slide()
	handle_last_collision()

func process_input():
	input_axis.x = Input.get_axis("move_left", "move_right")
	input_axis.y = Input.get_axis("move_up", "move_down")

	if state == State.FIRE and Input.is_action_just_pressed("fire"):
		_shoot_fireball()

	var was_crouching = is_crouching

	if is_on_floor():
		is_running = Input.is_action_pressed("run")
		is_crouching = Input.is_action_pressed("move_down")

		if is_crouching and input_axis.x:
			is_crouching = false
			input_axis.x = 0.0
	
	if is_crouching != was_crouching:
		_update_tree()

func process_jump(delta: float):
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			is_jumping = true
			
			var speed = abs(velocity.x)

			speed_threshold = SPEED_THRESHOLDS.size()

			for i in SPEED_THRESHOLDS.size():
				if speed < SPEED_THRESHOLDS[i]:
					speed_threshold = i
					break
			
			velocity.y = JUMP_SPEED[speed_threshold]
	else:
		var gravity = GRAVITY[speed_threshold]
		
		if Input.is_action_pressed("jump") and not is_falling:
			gravity = LONG_JUMP_GRAVITY[speed_threshold]
		
		velocity.y = velocity.y + gravity * delta
		
		if velocity.y > MAX_FALL_SPEED:
			velocity.y = MAX_FALL_SPEED_CAP
	
	if velocity.y > 0:
		is_jumping = false
		is_falling = true
	elif is_on_floor():
		is_falling = false

func process_walk(delta: float):
	if input_axis.x:
		if is_on_floor():
			if velocity.x:
				is_facing_left = input_axis.x < 0.0
				is_skiding = velocity.x < 0.0 != is_facing_left
				
			if is_skiding:
				min_speed = MIN_SLOW_DOWN_SPEED
				max_speed = MAX_WALK_SPEED
				acceleration = SKID_FRICTION
			elif is_running:
				min_speed = MIN_SPEED
				max_speed = MAX_SPEED
				acceleration = RUN_ACCELERATION
			else:
				min_speed = MIN_SPEED
				max_speed = MAX_WALK_SPEED
				acceleration = WALK_ACCELERATION
		elif is_running and abs(velocity.x) > MAX_WALK_SPEED:
			max_speed = MAX_SPEED
		else:
			max_speed = MAX_WALK_SPEED
		
		var target_speed = input_axis.x * max_speed
		
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	elif is_on_floor() and velocity.x:
		if not is_skiding:
			acceleration = WALK_FRICTION
		
		if input_axis.y:
			min_speed = MIN_SLOW_DOWN_SPEED
		else:
			min_speed = MIN_SPEED
		
		if abs(velocity.x) < min_speed:
			velocity.x = 0.0
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	
	if abs(velocity.x) < MIN_SLOW_DOWN_SPEED:
		is_skiding = false
	
	speed_scale = abs(velocity.x) / MAX_SPEED

func process_bounds_collision():
	if not camera:
		return

	const HALF_TILE = 8

	var _old_position = global_position

	global_position.x = clamp(
		global_position.x,
		camera.limit_left + HALF_TILE,
		camera.limit_right - HALF_TILE
	)

	if global_position.x != _old_position.x:
		velocity.x = 0.0

func handle_last_collision():
	var collision = get_last_slide_collision()
	
	if not collision:
		return
	
	var normal = collision.get_normal() * -1.0 # normal is relative to the player

	# keep the y velocity when colliding with a corner
	if normal != round(normal):
		velocity.y = _old_velocity.y

	# head collision
	if normal == Vector2.UP:
		var collider = collision.get_collider()
		
		if collider.has_method("hit"):
			collider.hit(self)

func process_animation():
	sprite.flip_h = is_facing_left
	sprite.speed_scale = max(1.75, speed_scale * 5.0)
	
	if is_falling:
		sprite.stop()
	elif is_crouching and state:
		sprite.play("crouch")
	elif is_jumping:
		sprite.play("jump")
	elif is_skiding:
		sprite.play("skid")
	elif velocity.x:
		sprite.play("walk")
	else:
		sprite.play("idle")

	if has_cooldown:
		modulate.a = 0.0 if modulate.a else 1.0
	else:
		modulate.a = 1.0

func _update_tree():
	var is_small = not state
	var is_crouching_or_small = is_crouching or is_small

	if is_small:
		sprite = small_sprite
	elif state == State.FIRE:
		sprite = fire_sprite
	else:
		sprite = big_sprite

	small_sprite.visible = is_small
	big_sprite.visible = not is_small and state != State.FIRE
	fire_sprite.visible = not is_small and state == State.FIRE

	big_collision_shape.disabled = is_crouching_or_small
	big_hitbox_shape.disabled = is_crouching_or_small

	small_collision_shape.disabled = not is_crouching_or_small
	small_hitbox_shape.disabled = not is_crouching_or_small

func transform(to_state: State):
	state = to_state
	

func take_hit():
	if state == State.SMALL:
		die()
	else:
		transform(state - 1)
		_cooldown()

func die():
	if is_dead:
		return

	is_dead = true
	hitbox.set_deferred("monitoring", false)

	velocity = Vector2(0.0, DEATH_HOP_SPEED)

	# The death pose only exists on the small sprite's frames -- big/fire Mario
	# shrinks back down for it, same as the original game.
	big_sprite.visible = false
	fire_sprite.visible = false
	small_sprite.visible = true
	sprite = small_sprite
	sprite.play("death")

	get_tree().create_timer(DEATH_DELAY_SEC).timeout.connect(StageManager.lose_life)

func finish_level(pole_x: float, ground_y: float, slide_duration: float, walk_duration: float):
	if is_dead or is_finishing:
		return

	is_finishing = true
	hitbox.set_deferred("monitoring", false)
	Physics.disable()

	velocity = Vector2.ZERO
	is_facing_left = false
	sprite.play("idle")

	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", Vector2(pole_x, ground_y), slide_duration)
	tween.tween_property(self, "global_position:x", pole_x + 32.0, walk_duration)
	tween.tween_callback(StageManager.level_complete)

func _cooldown():
	has_cooldown = true
	get_tree().create_timer(COOLDOWN_TIME_SEC).connect("timeout", func(): has_cooldown = false)

func _on_transition_started():
	sprite.visible = false
	transition_sprite.visible = true

	if collected_item_ref:
		collected_item_ref.queue_free()
		collected_item_ref = null

func _on_transition_finished():
	var animation_name = sprite.animation

	_update_tree()
	
	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
	else:
		sprite.play("idle")

	transition_sprite.visible = false

func _on_hitbox_area_entered(area: Area2D):
	var body = area.get_parent()
	
	if body.is_in_group("enemies"):
		if not body.is_alive:
			return

		# A shell at rest is kicked by any contact, from the side or from above,
		# as on the NES. Landing on one used to fall through to the stomp branch
		# below, which only reset its revive timer and bounced Mario off it --
		# so coming down on a shell after stomping the Koopa left him bouncing
		# on the spot, unable to ever kick it.
		if body.has_method("can_be_kicked") and body.can_be_kicked():
			_kick_shell(body)
			return

		var stomp = velocity.y > 0 and hitbox.global_position.y < area.global_position.y

		if stomp:
			if body.has_method("stomp"):
				body.stomp()
				velocity.y = fmod(velocity.y, STOMP_SPEED_CAP) - STOMP_SPEED
				_award_stomp_points()
		elif not has_cooldown:
			take_hit()


func _kick_shell(shell):
	# Away from Mario; when he lands squarely on top there is no side to pick,
	# so send it the way he is facing.
	var direction = signf(shell.global_position.x - global_position.x)

	if direction == 0.0:
		direction = -1.0 if is_facing_left else 1.0

	shell.kick(direction)
	StageManager.add_score(StageManager.POINTS_FIREBALL_KILL)

	# Kicking one on the way down still gives the little hop a stomp does.
	if velocity.y > 0:
		velocity.y = fmod(velocity.y, STOMP_SPEED_CAP) - STOMP_SPEED

func _shoot_fireball():
	if get_tree().get_nodes_in_group("fireballs").size() >= MAX_FIREBALLS:
		return

	var fireball = fireball_scene.instantiate()
	add_sibling(fireball)
	fireball.launch(global_position + Vector2(-8.0 if is_facing_left else 8.0, -4.0), is_facing_left)


func _award_stomp_points():
	if _stomp_combo < STOMP_POINTS.size():
		StageManager.add_score(STOMP_POINTS[_stomp_combo])
	else:
		StageManager.add_life()

	_stomp_combo += 1


func _on_hitbox_body_entered(body: Node):
	if body.is_in_group("powerups"):
		collected_item_ref = body
		StageManager.add_score(StageManager.POINTS_POWERUP)

		if body is RedMushroom:
			transform(State.BIG)
		elif body is FireFlower:
			transform(State.BIG if state == State.SMALL else State.FIRE)

func _on_animation_player_animation_finished(_anim_name):
	Physics.enable()
