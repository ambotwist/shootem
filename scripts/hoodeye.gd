extends CharacterBody2D

@export var SPEED: float = 25.0
@export var max_hurt: float = 0.5
@export var GRAVITY: float = 980.0  # Gravity force
@export var ground_check_distance: float = 20.0  # Distance to check for ground
@export var wall_check_distance: float = 16.0   # Distance to check for walls

@onready var sprites: Sprite2D = $Sprites
@onready var body_animation: AnimatedSprite2D = $Sprites/BodyAnimation
@onready var eye_animation: AnimatedSprite2D = $Sprites/EyeAnimation

var _hurt: float = 0.0
var direction: int = -1  # -1 for left, 1 for right
var is_on_ground: bool = false
var direction_change_cooldown: float = 0.0
var last_position: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add to enemies group for tracking
	add_to_group("enemies")
	
	# Make sure sprite has the material and ensure it's unique to this instance
	if sprites:
		if sprites.material:
			# Create a unique duplicate of the shader material
			sprites.material = sprites.material.duplicate()
			sprites.material.set_shader_parameter("brightness", 0.0)
	
	last_position = global_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Update cooldown
	if direction_change_cooldown > 0:
		direction_change_cooldown -= delta
	
	# Apply gravity if not on ground
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
		is_on_ground = true
	
	# Move horizontally
	velocity.x = direction * SPEED
	
	# Store position before moving
	var old_position = global_position
	
	# Apply movement
	move_and_slide()
	
	# Check if we hit a wall (didn't move as expected) or use raycast
	var moved_distance = abs(global_position.x - old_position.x)
	var expected_distance = abs(SPEED * delta)
	
	if direction_change_cooldown <= 0:
		var should_turn = false
		var turn_reason = ""
		
		# Check for walls using collision detection or raycast
		if moved_distance < expected_distance * 0.5:
			should_turn = true
			turn_reason = "collision detection - didn't move expected distance"
		elif check_wall_ahead():
			should_turn = true  
			turn_reason = "raycast detected wall ahead"
		# Only check cliff if we're not already turning due to wall
		elif is_on_ground and not check_ground_ahead():
			should_turn = true
			turn_reason = "avoiding cliff - no ground ahead"
		
		if should_turn:
			direction *= -1  # Turn around
			direction_change_cooldown = 1.0  # Longer cooldown to prevent jittery behavior
			print("Hoodeye turning around (", turn_reason, "). New direction: ", direction, " at position: ", global_position)
	
	# Update sprite direction - flip horizontally based on movement direction
	body_animation.flip_h = direction > 0
	eye_animation.flip_h = direction > 0
	
	# Update last position
	last_position = global_position
	
	# Destroy if moved too far off screen to clean up (scroll-based)
	var scroll_pos = get_scroll_position()
	if position.x < scroll_pos.x - 400:  # 400 pixels behind scroll position
		print("Hoodeye: Self-cleanup at ", position, " (scroll pos: ", scroll_pos, ")")
		queue_free()

func check_wall_ahead() -> bool:
	# Cast a ray forward to check for walls
	var space_state = get_world_2d().direct_space_state
	var from = global_position
	var to = global_position + Vector2(direction * wall_check_distance, 0)
	
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]  # Don't collide with self
	query.collision_mask = 1  # Assuming walls are on collision layer 1
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func check_ground_ahead() -> bool:
	# Cast a ray downward from a point ahead to check for ground
	var space_state = get_world_2d().direct_space_state
	var from = global_position + Vector2(direction * wall_check_distance, 0)
	var to = from + Vector2(0, ground_check_distance)
	
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]  # Don't collide with self
	query.collision_mask = 1  # Assuming ground is on collision layer 1
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func hurt(amount: float) -> void:
	if visible && sprites && sprites.material:
		_hurt = max(_hurt + amount, 0)
		sprites.material.set_shader_parameter("brightness", _hurt / max_hurt)
		if _hurt > max_hurt:
			# Notify game about enemy death
			var game = get_node("/root/Game")
			if game && game.has_method("enemy_died"):
				game.enemy_died()
			queue_free()

# Called when the node is removed from the scene
func _exit_tree() -> void:
	# Ensure we notify the game if we're destroyed for any reason
	if _hurt <= max_hurt:  # If we weren't already fully destroyed by hurt()
		var game = get_node("/root/Game")
		if game && game.has_method("enemy_died"):
			game.enemy_died()

func get_scroll_position() -> Vector2:
	# Try to get scroll position from level manager
	var level_manager = get_node_or_null("/root/Game/LevelManager")
	if level_manager and level_manager.has_method("get_scroll_position"):
		return level_manager.get_scroll_position()
	
	# Fallback: try to get camera position
	var camera = get_viewport().get_camera_2d()
	if camera:
		return camera.global_position
	
	# Ultimate fallback
	return Vector2.ZERO
