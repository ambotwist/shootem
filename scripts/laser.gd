extends Node2D

@export var beam_length: float = 2000.0
@export var collision_mask: int = 1  # Set to match the collision layer of objects to detect

@onready var beam: Line2D = $Beam
@onready var glow: Line2D = $Glow
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _is_active: bool

func _ready() -> void:
	visible = false
	_is_active = false
	# Default length for initialization
	_set_length(0)

func _process(delta: float) -> void:
	if _is_active:
		update_beam()


func update_beam() -> void:
	# Get mouse position in world coordinates
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	var distance_to_mouse = global_position.distance_to(mouse_pos)
	
	# Use raycast to check for collisions
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direction * beam_length)
	query.collision_mask = collision_mask
	query.collide_with_areas = true  # Enable collision with Area2D nodes
	query.collide_with_bodies = true  # Keep collision with physics bodies enabled
	var result = space_state.intersect_ray(query)
	
	if result:
		# If we hit something, calculate distance to collision point
		var collision_point = result["position"]
		var distance_to_collision = global_position.distance_to(collision_point)
		
		# Check if mouse is beyond the collision point
		if distance_to_mouse > distance_to_collision:
			# Mouse is beyond collision, stop at collision point
			_set_length(distance_to_collision)
		else:
			# Mouse is before collision, stop at mouse position
			_set_length(min(distance_to_mouse, beam_length))
	else:
		# No collision detected, stop at mouse position or max length
		_set_length(min(distance_to_mouse, beam_length))

func _set_length(length: float) -> void:
	beam.points[1].x = length
	glow.points[1].x = length
	
func activate():
	if !_is_active:
		_is_active = true
		visible = true
		animation_player.play("start_beam")

func deactivate():
	if _is_active:
		_is_active = false
		animation_player.play("stop_beam")

func _on_animation_player_animation_finished(anim_name:StringName) -> void:
	if anim_name == "stop_beam":
		visible = false
