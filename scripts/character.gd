extends CharacterBody2D


@export var SPEED: int = 200.0


func _physics_process(delta: float) -> void:
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
	global_position.x = clamp(global_position.x, left_edge, right_edge)
	global_position.y = clamp(global_position.y, top_edge, bottom_edge)
