extends Node2D

# References to other nodes
@export_node_path var chunk_spawner_path
@export_node_path var chunk_queue_path
@export_node_path var player_path
@export_node_path var camera_path

# Speed of automatic scrolling
@export var scroll_speed: float = 100.0  # pixels per second
@export var min_scroll_speed: float = 100.0
@export var max_scroll_speed: float = 300.0
@export var speed_increase_rate: float = 0.0  # Increase by 5 units per second

# Actual position of the virtual camera (for scrolling)
var scroll_position: Vector2 = Vector2.ZERO
var is_scrolling: bool = false

# References to actual nodes
var chunk_spawner: Node2D
var chunk_queue: Node2D
var player: Node2D
var camera: Camera2D

func _ready() -> void:
	# Get references to nodes
	chunk_spawner = get_node(chunk_spawner_path)
	chunk_queue = get_node(chunk_queue_path)
	
	if player_path:
		player = get_node(player_path)
		
	if camera_path:
		camera = get_node(camera_path)
	else:
		# If no camera specified, try to find one
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			camera = cameras[0]
	
	# Connect signals
	chunk_queue.chunk_passed.connect(_on_chunk_passed)
	
	# Start the level
	start_level()

func _process(delta: float) -> void:
	if is_scrolling:
		# Update scroll position
		scroll_position.x += scroll_speed * delta
		
		# Gradually increase the scroll speed over time
		scroll_speed = min(scroll_speed + speed_increase_rate * delta, max_scroll_speed)
		
		# Update camera position
		if camera:
			camera.global_position.x = scroll_position.x
		
		# Check if player has fallen too far behind
		if player and player.global_position.x < scroll_position.x - 250:  
			_on_player_left_behind()
		
		# Check if we need to generate new chunks or remove old ones
		chunk_spawner.check_for_new_chunks(scroll_position)
		chunk_queue.check_for_chunk_removal(scroll_position)

func start_level() -> void:
	# Reset the scroll position
	scroll_position = Vector2.ZERO
	
	# Reset scroll speed
	scroll_speed = min_scroll_speed
	
	# Start scrolling
	is_scrolling = true

func stop_level() -> void:
	is_scrolling = false

func _on_chunk_passed() -> void:
	# This is called when a chunk is completely passed and removed
	# Could be used for score or other gameplay mechanics
	pass

func _on_player_left_behind() -> void:
	# Handle when player falls behind the scroll
	# This usually means game over
	stop_level()
	# Emit a signal or call a game over function
	print("Player left behind - game over!")
	
func get_scroll_position() -> Vector2:
	return scroll_position 
