extends Node2D

# Enemy scenes to spawn
@export var enemy_scenes: Array[PackedScene] = []
# Probability of spawning an enemy at a valid spawn point (0-1)
@export var spawn_probability: float = 0.05
# Minimum distance between spawned enemies
@export var min_enemy_distance: float = 64.0
# Reference to the chunk queue
@export var chunk_queue_path: NodePath

# Internal references
var chunk_queue
var tilemap_cache = {}
var active_enemies = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get reference to the chunk queue
	if chunk_queue_path:
		chunk_queue = get_node(chunk_queue_path)
		chunk_queue.connect("chunk_passed", _on_chunk_passed)
	else:
		push_error("MobSpawner: No chunk queue specified!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Clean up enemies every few frames to prevent buildup
	if Engine.get_process_frames() % 60 == 0:  # Every 60 frames (about once per second at 60fps)
		clean_up_enemies()

func _on_chunk_passed() -> void:
	# Clean up enemies that are no longer visible
	clean_up_enemies()

func spawn_enemies_on_chunk(chunk: Node2D) -> void:
	# Skip if no enemy scenes are configured
	if enemy_scenes.size() == 0:
		push_warning("MobSpawner: No enemy scenes configured!")
		return
		
	# Find all valid spawn points on this chunk
	var spawn_points = find_spawn_points(chunk)
	
	# No valid spawn points found
	if spawn_points.size() == 0:
		return
		
	# Sort spawn points from left to right
	spawn_points.sort_custom(func(a, b): return a.x < b.x)
	
	# Choose some spawn points based on probability and minimum distance
	var chosen_points = choose_spawn_points(spawn_points)
	
	# Spawn enemies at chosen points
	for point in chosen_points:
		spawn_enemy(point)

# Find ground tiles in a tilemap layer
func find_ground_tiles_in_tilemap(layer: TileMapLayer, chunk_position: Vector2) -> Array:
	var spawn_points = []
	
	# Don't use caching - process each chunk fresh to avoid stale data
	print("MobSpawner: Processing chunk at ", chunk_position, " - layer: ", layer.name)
	
	# Try to find ground tiles
	var cells = layer.get_used_cells()
	print("MobSpawner: Checking layer ", layer.name, " with ", cells.size(), " cells")
	
	if cells.size() == 0:
		print("MobSpawner: No cells found in layer")
		return spawn_points
	
	# Group ground tiles by Y coordinate to ensure we only check horizontal platforms
	var ground_tiles_by_row = {}
	for cell_coord in cells:
		var tile_data = layer.get_cell_tile_data(cell_coord)
		if tile_data:
			# Check if the tile is marked as "ground" terrain
			var ground_value = tile_data.get_custom_data("ground")
			if ground_value == true:
				var row_y = cell_coord.y
				# Create array for this Y coordinate if it doesn't exist
				if not row_y in ground_tiles_by_row:
					ground_tiles_by_row[row_y] = []
				# Add X coordinate to this row (all tiles in this array have the same Y)
				ground_tiles_by_row[row_y].append(cell_coord.x)
				print("MobSpawner: Found ground tile at (", cell_coord.x, ", ", cell_coord.y, ")")
	
	print("MobSpawner: Found ", ground_tiles_by_row.size(), " rows with ground tiles")
	
	# Process each horizontal row separately (all tiles in each row have the same Y coordinate)
	for row_y in ground_tiles_by_row:
		var x_coordinates_in_row = ground_tiles_by_row[row_y]
		x_coordinates_in_row.sort()  # Sort X coordinates for this row
		
		print("MobSpawner: Row Y=", row_y, " has ", x_coordinates_in_row.size(), " ground tiles at X coordinates: ", x_coordinates_in_row)
		
		# Find consecutive sequences of at least 4 tiles in this horizontal row
		var platforms_in_row = find_consecutive_sequences(x_coordinates_in_row, 4)
		
		print("MobSpawner: Found ", platforms_in_row.size(), " valid platforms in row Y=", row_y)
		
		for platform in platforms_in_row:
			var platform_width = platform.end - platform.start + 1
			print("MobSpawner: Processing platform at Y=", row_y, " from X=", platform.start, " to X=", platform.end, " (", platform_width, " tiles wide)")
			
			# Verify this platform is actually 4+ tiles wide
			if platform_width < 4:
				print("MobSpawner: ERROR - Platform too narrow! Width: ", platform_width)
				continue
			
			# Create spawn points for this platform (skip first and last tile to avoid edges)
			# Only spawn in the middle tiles: if platform is 4 wide (0,1,2,3), spawn at tiles 1,2
			for x in range(platform.start + 1, platform.end):
				var cell_coord = Vector2i(x, row_y)  # Use the row_y to ensure same Y coordinate
				
				# Check if the tile above is empty (no collision)
				var above_cell = Vector2i(x, row_y - 1)
				var above_data = layer.get_cell_tile_data(above_cell)
				
				if above_data == null or not above_data.has_collision():
					# Convert cell to local position within the layer
					var local_pos = layer.map_to_local(cell_coord)
					print("MobSpawner: Cell (", x, ", ", row_y, ") -> Local pos: ", local_pos)
					
					# Calculate the final world position - chunk position + local tile position
					var world_pos = chunk_position + local_pos
					
					# Position enemies ABOVE the ground tile
					# The local_pos.y is typically negative for tiles above origin, so we need to 
					# position the enemy above the tile surface, not below it
					# Move up by approximately one tile height to sit on top
					world_pos.y -= 16  # Move up by tile height to sit on surface
					
					print("MobSpawner: Final spawn point: ", world_pos, " (platform Y=", row_y, ", X=", x, ", width=", platform_width, ")")
					# Store this valid spawn point
					spawn_points.append(world_pos)
				else:
					print("MobSpawner: Skipping spawn at (", x, ", ", row_y, ") - tile above has collision")
	
	print("MobSpawner: Total spawn points found: ", spawn_points.size())
	return spawn_points

# Helper function to find consecutive sequences of at least min_length
func find_consecutive_sequences(sorted_coords: Array, min_length: int) -> Array:
	var sequences = []
	print("MobSpawner: Looking for consecutive sequences of at least ", min_length, " in: ", sorted_coords)
	
	if sorted_coords.size() < min_length:
		print("MobSpawner: Not enough coordinates (", sorted_coords.size(), ") for minimum length ", min_length)
		return sequences
	
	var current_start = sorted_coords[0]
	var current_end = sorted_coords[0]
	
	for i in range(1, sorted_coords.size()):
		if sorted_coords[i] == current_end + 1:
			# Continue the sequence
			current_end = sorted_coords[i]
			print("MobSpawner: Extending sequence to ", current_start, "-", current_end)
		else:
			# Sequence broken, check if current sequence is long enough
			var sequence_length = current_end - current_start + 1
			print("MobSpawner: Sequence broken. Current sequence: ", current_start, "-", current_end, " (length: ", sequence_length, ")")
			
			if sequence_length >= min_length:
				print("MobSpawner: Adding valid sequence: ", current_start, "-", current_end)
				sequences.append({"start": current_start, "end": current_end})
			else:
				print("MobSpawner: Sequence too short, skipping")
			
			# Start a new sequence
			current_start = sorted_coords[i]
			current_end = sorted_coords[i]
			print("MobSpawner: Starting new sequence at ", current_start)
	
	# Don't forget the last sequence
	var final_length = current_end - current_start + 1
	print("MobSpawner: Final sequence: ", current_start, "-", current_end, " (length: ", final_length, ")")
	
	if final_length >= min_length:
		print("MobSpawner: Adding final valid sequence: ", current_start, "-", current_end)
		sequences.append({"start": current_start, "end": current_end})
	else:
		print("MobSpawner: Final sequence too short, skipping")
	
	print("MobSpawner: Found ", sequences.size(), " valid sequences: ", sequences)
	return sequences

# Find valid spawn points on ground tiles in a chunk
func find_spawn_points(chunk: Node2D) -> Array:
	var spawn_points = []
	
	# Search for TileMapLayers in the chunk
	for layer_node in chunk.get_children():
		for child in layer_node.get_children():
			if child is TileMapLayer:
				# Process this tilemap layer to find ground tiles
				var points = find_ground_tiles_in_tilemap(child, chunk.position)
				if points.size() > 0:
					spawn_points.append_array(points)
	
	return spawn_points

# Choose spawn points based on probability and minimum distance
func choose_spawn_points(spawn_points: Array) -> Array:
	var chosen = []
	var last_point = null
	
	for point in spawn_points:
		# Check if we're far enough from the last spawn point
		if last_point == null or point.distance_to(last_point) >= min_enemy_distance:
			# Apply spawn probability
			if randf() <= spawn_probability:
				chosen.append(point)
				last_point = point
	
	return chosen

# Spawn an enemy at the given point
func spawn_enemy(point: Vector2) -> void:
	# Choose a random enemy scene
	var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
	
	# Instance the enemy
	var enemy = enemy_scene.instantiate()
	
	# Set position and add to scene
	enemy.position = point
	print("MobSpawner: Spawned enemy at ", point)
	add_child(enemy)
	
	# Track active enemies
	active_enemies.append(enemy)
	
	# Connect to enemy's tree_exiting signal to remove from active_enemies
	enemy.connect("tree_exiting", func(): 
		active_enemies.erase(enemy)
	)

# Clean up enemies that are no longer visible
func clean_up_enemies() -> void:
	# Remove enemies that are already being freed
	active_enemies = active_enemies.filter(func(enemy): return is_instance_valid(enemy))
	
	# Get current scroll position from level manager
	var scroll_position = get_scroll_position()
	
	# Clean up enemies that are too far behind the scroll position
	var cleanup_distance = 400  # Remove enemies 400 pixels behind scroll position
	var cleanup_threshold = scroll_position.x - cleanup_distance
	
	var removed_count = 0
	for enemy in active_enemies.duplicate():
		if is_instance_valid(enemy) and enemy.position.x < cleanup_threshold:
			print("MobSpawner: Cleaning up enemy at ", enemy.position, " (behind threshold ", cleanup_threshold, ")")
			enemy.queue_free()
			active_enemies.erase(enemy)
			removed_count += 1
	
	if removed_count > 0:
		print("MobSpawner: Cleaned up ", removed_count, " enemies. Active enemies: ", active_enemies.size())

# Get scroll position from level manager
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

# Clean up all enemies (for game over scenarios)
func clean_up_all_enemies() -> void:
	print("MobSpawner: Cleaning up ALL enemies (", active_enemies.size(), " total)")
	for enemy in active_enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
