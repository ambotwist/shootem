extends CharacterBody2D


@export var SPEED: float = 200.0
@export var marginX: int = 8
@export var marginY: int = 16

@onready var attack_pivot: = $AttackPivot
@onready var laser = $AttackPivot/Laser


func _process(delta: float):
	if Input.is_action_just_pressed("fire"):
		laser.activate()
	if Input.is_action_just_released("fire"):
		laser.deactivate()


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
