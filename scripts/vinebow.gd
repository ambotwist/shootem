extends Node2D

@export var thorn_count: int = 3
@export var projectile_speed: float = 400.0
@export var projectile_distance: float = 100.0
@export var damage: float = 1.0  # Damage amount per hit
@export var spread_angle: float = 30.0  # Total spread angle in degrees

@onready var bow_ap: AnimatedSprite2D = $BowAS
# Preload the Thorn scene for instantiation
const THORN_SCENE = preload("res://scenes/thorn.tscn")

var is_active = false  # Track if projectile is currently active
var is_firing = false  # Track if we're in the firing sequence
var active_thorns = []  # Track all active thorn instances

func _ready() -> void:
	bow_ap.visible = false

func _process(delta: float) -> void:
	pass

func shoot_thorns():
	if is_firing:
		return  # Prevent multiple concurrent firings
		
	is_firing = true
	active_thorns.clear()
	
	# Start bow animation
	bow_ap.visible = true
	bow_ap.play("draw")
	await bow_ap.animation_finished
	
	# Get the base transform
	var firing_transform = global_transform
	
	# Calculate angle step based on thorn count
	var angle_step = spread_angle / max(thorn_count - 1, 1)
	var start_angle = -spread_angle / 2
	
	# Fire thorns in an arc
	for i in range(thorn_count):
		var thorn_angle = 0.0
		
		# Calculate angle for this thorn (one in the middle goes straight)
		if thorn_count > 1:
			thorn_angle = start_angle + (i * angle_step)
		
		# Instantiate a thorn
		var thorn_instance = THORN_SCENE.instantiate()
		get_tree().root.add_child(thorn_instance)
		
		# Set position and apply the angle offset
		thorn_instance.global_transform = firing_transform
		thorn_instance.rotate(deg_to_rad(thorn_angle))
		
		# Get references to the key nodes
		var projectile_sprite = thorn_instance.get_node("ProjectileAS")
		var projectile_area = thorn_instance.get_node("ProjectileAS/Area2D")
		
		# Setup the thorn instance
		projectile_sprite.play("thorn_fire")
		
		# Connect collision signals
		if projectile_area:
			projectile_area.area_entered.connect(
				func(area): _handle_collision(area, thorn_instance, damage)
			)
			projectile_area.body_entered.connect(
				func(body): _handle_body_collision(body, thorn_instance, damage)
			)
		
		# Track this thorn
		active_thorns.append(thorn_instance)
		
		# Create tween for projectile movement
		var tween = create_tween()
		tween.tween_property(
			thorn_instance, 
			"position", 
			thorn_instance.position + Vector2(projectile_distance, 0).rotated(thorn_instance.rotation), 
			projectile_distance / projectile_speed
		)
		
		# Handle tween completion
		tween.finished.connect(
			func(): _on_thorn_movement_complete(thorn_instance)
		)
	
	is_active = true
	
	# After all animations complete, hide bow
	await get_tree().create_timer(projectile_distance / projectile_speed + 0.3).timeout
	bow_ap.visible = false
	is_firing = false

# Called when an individual thorn completes its movement
func _on_thorn_movement_complete(thorn_instance):
	if is_instance_valid(thorn_instance):
		var projectile_sprite = thorn_instance.get_node("ProjectileAS")
		if projectile_sprite:
			# Play end animation
			projectile_sprite.play("thorn_end")
			# Wait for animation to finish, then remove this thorn
			await projectile_sprite.animation_finished
			thorn_instance.queue_free()
			# Remove from active thorns list
			active_thorns.erase(thorn_instance)

# Handle collision with areas
func _handle_collision(area: Area2D, thorn_instance: Node2D, damage_amount: float) -> void:
	if !is_active or !is_instance_valid(thorn_instance):
		return
		
	# Check if we hit an enemy's killzone
	if area.name == "Killzone" && area.get_parent() && area.get_parent().has_method("hurt"):
		area.get_parent().hurt(damage_amount)
	# Alternatively check if the area itself can be hurt
	elif area.has_method("hurt"):
		area.hurt(damage_amount)

# Handle collision with bodies
func _handle_body_collision(body: Node2D, thorn_instance: Node2D, damage_amount: float) -> void:
	if !is_active or !is_instance_valid(thorn_instance):
		return
		
	# Check if we hit an enemy directly
	if body.has_method("hurt"):
		body.hurt(damage_amount)

# These methods are left for backward compatibility but won't be used
func _on_projectile_area_entered(area: Area2D) -> void:
	pass

func _on_projectile_body_entered(body: Node2D) -> void:
	pass
	
