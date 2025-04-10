extends Node2D

@export var spawn_timer_duration: float = 3.0
@export var max_enemies: int = 15

var spawn_timer: Timer
var hoodeye_scene: PackedScene
var spawn_on_top: bool = true
var enemy_count: int = 0

# Spawn positions
var top_position: Vector2 = Vector2(222, -69)
var bottom_position: Vector2 = Vector2(222, 107)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Load the hoodeye scene
	hoodeye_scene = preload("res://scenes/hoodeye.tscn")
	
	# Add existing hoodeyes to the enemies group
	var existing_hoodeyes = get_tree().get_nodes_in_group("enemies")
	if existing_hoodeyes.size() == 0:
		# If no enemies are in the group, find the existing ones in the scene
		var map_hoodeye = $Map/Hoodeye
		var root_hoodeye = $Hoodeye
		
		if map_hoodeye:
			map_hoodeye.add_to_group("enemies")
		
		if root_hoodeye:
			root_hoodeye.add_to_group("enemies")
	
	
	# Create the spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_timer_duration
	spawn_timer.one_shot = false
	spawn_timer.autostart = true
	add_child(spawn_timer)
	
	# Connect the timer signal
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_spawn_timer_timeout() -> void:
	# Check if we've reached the maximum number of enemies
	if enemy_count >= max_enemies:
		return
	
	# Create a new hoodeye instance
	var new_hoodeye = hoodeye_scene.instantiate()
	add_child(new_hoodeye)
	
	# Add to enemies group for tracking
	new_hoodeye.add_to_group("enemies")
	
	# Set the position based on whether we're spawning on top or bottom
	if spawn_on_top:
		new_hoodeye.position = top_position
	else:
		new_hoodeye.position = bottom_position
		new_hoodeye.z_index = 1  # Match the z-index of the bottom hoodeye
	
	# Toggle for next spawn
	spawn_on_top = !spawn_on_top
	
	# Increment enemy count
	enemy_count += 1
	

# Function to handle enemy death
func enemy_died() -> void:
	enemy_count -= 1
