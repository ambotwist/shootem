extends Node2D

@export var beam_length: float = 2000.0
@export var collision_mask: int = 1  # Set to match the collision layer of objects to detect

@onready var beam: Line2D = $Beam
@onready var glow: Line2D = $Glow
@onready var animation_player_beam: AnimationPlayer = $AnimationPlayerBeam
@onready var animation_player_glow: AnimationPlayer = $AnimationPlayerGlow
@onready var raycast: RayCast2D = $RayCast2D
@onready var explosion: AnimatedSprite2D = $Explosion

var _is_active: bool
var _last_collision_point: Vector2 = Vector2.ZERO
var _is_exploding: bool = false


func _ready() -> void:
	visible = false
	_is_active = false
	# Default length for initialization
	_set_length(0)
	raycast.enabled = false
	explosion.visible = false
	
	# Set raycast to detect both areas and physics bodies
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	
	# Set the collision mask from the exported property
	raycast.collision_mask = collision_mask

	
	# Connect to the animation_finished signal
	if !explosion.animation_finished.is_connected(_on_explosion_animation_finished):
		explosion.animation_finished.connect(_on_explosion_animation_finished)


func _physics_process(delta: float) -> void:
	if _is_active:
		update_beam(delta)


func update_beam(delta: float) -> void:
	# Make sure raycast is enabled and pointing in the right direction
	raycast.enabled = true
	# Set raycast length - use the beam_length value
	raycast.target_position = Vector2(beam_length, 0)
	# Force raycast update to ensure fresh collision info
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		
		# Convert the collision point to local coordinates for the beam
		var local_collision_point = to_local(collision_point)
		var distance_to_collision = local_collision_point.x
		
		# Always set the beam to reach the collision point
		_set_length(distance_to_collision)
		
		# Show explosion at collision point
		if !_is_exploding || (_is_exploding && _last_collision_point.distance_to(collision_point) > 5.0):
			_show_explosion_at(collision_point)
			_last_collision_point = collision_point
		else:
			# Always update explosion position to match current collision point
			explosion.global_position = collision_point

		# Add hurt effect to the collider
		var collider = raycast.get_collider()
		if collider:
			# If it's a Killzone, try to get its parent (the enemy)
			if collider.name == "Killzone" && collider.get_parent() && collider.get_parent().has_method("hurt"):
				collider.get_parent().hurt(delta)
			# Otherwise check if the collider itself has the hurt method
			elif collider.has_method("hurt"):
				collider.hurt(delta)
	else:
		# No collision detected, use max beam length
		_set_length(beam_length)
		# Hide explosion when not hitting anything
		explosion.visible = false
		_is_exploding = false


func _show_explosion_at(collision_position: Vector2) -> void:
	explosion.global_position = collision_position
	explosion.visible = true
	explosion.frame = 0
	explosion.play()
	_is_exploding = true


func _on_explosion_animation_finished() -> void:
	# Start playing the animation again if still active at the same position
	if _is_active && explosion.visible:
		explosion.frame = 0
		explosion.play()


func _set_length(length: float) -> void:
	# Make sure length is never negative
	length = max(0, length)
	beam.points[1].x = length
	glow.points[1].x = length


func activate():
	if !_is_active:
		_is_active = true
		visible = true
		raycast.enabled = true
		raycast.force_raycast_update()
		animation_player_beam.play("start_beam")
		animation_player_glow.play("animations/start_glow")

func deactivate():
	if _is_active:
		_is_active = false
		raycast.enabled = false
		explosion.visible = false
		_is_exploding = false
		animation_player_beam.play("stop_beam")
		animation_player_glow.play("animations/stop_glow")


func _on_animation_player_animation_finished(anim_name:StringName) -> void:
	if anim_name == "stop_beam":
		visible = false

func _on_animation_player_glow_animation_finished(anim_name:StringName) -> void:
	if anim_name == "stop_glow":
		visible = false
