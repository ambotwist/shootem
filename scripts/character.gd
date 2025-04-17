extends CharacterBody2D


@export var SPEED: float = 200.0
@export var regen_time: float = 0.3
@export var cooldown_time: float = 1.5
var marginX: int = 8
var marginY: int = 12

@onready var attack_pivot: = $AttackPivot
@onready var laser = $AttackPivot/Laser
@onready var orb1 = $Orbs/Orb1
@onready var orb2 = $Orbs/Orb2
@onready var orb3 = $Orbs/Orb3
@onready var orbsTimer : Timer = $Orbs/OrbsTimer
@onready var regenTimer : Timer = $Orbs/RegenTimer
@onready var cooldownTimer : Timer = $Orbs/CooldownTimer

# Track which orbs need regeneration
var orb1_needs_regen = false
var orb2_needs_regen = false
var orb3_needs_regen = false
var is_regenerating = false
var is_firing = false  # Track if we're currently in the firing process

func _ready():
	orbsTimer.paused = true
	
	# Setup regeneration timer
	regenTimer.wait_time = regen_time
	regenTimer.one_shot = true
	
	# Setup cooldown timer
	cooldownTimer.wait_time = cooldown_time
	cooldownTimer.one_shot = true
	
	
func _process(delta: float):
	if Input.is_action_pressed("fire") and not is_firing and not is_regenerating:
		_process_orbs()


func _process_orbs():
	if !orb1._is_disabled && orbsTimer.paused:
		shoot_laser(orb1)
	elif !orb2._is_disabled && orbsTimer.paused:
		shoot_laser(orb2)
	elif !orb3._is_disabled && orbsTimer.paused:
		shoot_laser(orb3)


func shoot_laser(orb):
	is_firing = true
	attack_pivot.global_position = orb.global_position
	orbsTimer.paused = false
	orbsTimer.start(0.2)
	laser.activate()
	orb.consume()
	
	# Mark orb for regeneration
	if orb == orb1:
		orb1_needs_regen = true
	elif orb == orb2:
		orb2_needs_regen = true
	elif orb == orb3:
		orb3_needs_regen = true
	
	# Always restart the cooldown timer when an orb is consumed
	cooldownTimer.stop()
	cooldownTimer.start()
	
	await orbsTimer.timeout
	laser.deactivate()
	orbsTimer.paused = true
	is_firing = false  # Allow firing the next orb if available


func _on_cooldown_timer_timeout():
	# Start regenerating orbs if any need regeneration
	if (orb1_needs_regen || orb2_needs_regen || orb3_needs_regen) and not is_regenerating:
		is_regenerating = true
		regenTimer.start()


func _on_regen_timer_timeout() -> void:
	# Regenerate orbs in specific order: orb3, orb2, orb1
	if orb3_needs_regen:
		orb3.regen()
		orb3_needs_regen = false
		
		# Continue regeneration if more orbs need it
		if orb2_needs_regen || orb1_needs_regen:
			regenTimer.start()
		else:
			is_regenerating = false
			
	elif orb2_needs_regen:
		orb2.regen()
		orb2_needs_regen = false
		
		# Continue regeneration if more orbs need it
		if orb1_needs_regen:
			regenTimer.start()
		else:
			is_regenerating = false
			
	elif orb1_needs_regen:
		orb1.regen()
		orb1_needs_regen = false
		is_regenerating = false

func _physics_process(delta: float) -> void:

	# Movement
	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)

	move_and_slide()
	clamp_to_visible_area()

	# Attack Pivot
	attack_pivot.look_at(get_global_mouse_position())


func clamp_to_visible_area():
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return
		
	var viewport_rect = get_viewport_rect()
	var sprite_size = Vector2(32, 32)  # Adjust based on your character's sprite size
	
	# Calculate screen boundaries in global coordinates
	var camera_position = camera.global_position
	var camera_zoom = camera.zoom
	var screen_size = viewport_rect.size / camera_zoom
	
	var left_edge = camera_position.x - screen_size.x/2 + sprite_size.x/2
	var right_edge = camera_position.x + screen_size.x/2 - sprite_size.x/2
	var top_edge = camera_position.y - screen_size.y/2 + sprite_size.y/2
	var bottom_edge = camera_position.y + screen_size.y/2 - sprite_size.y/2
	
	# Clamp the character position
	global_position.x = clamp(global_position.x, left_edge + marginX, right_edge - marginX)
	global_position.y = clamp(global_position.y, top_edge + marginY, bottom_edge - marginY)
