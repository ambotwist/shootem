extends Node2D

# Enemy scenes to spawn
@export var enemy_scenes: Array[PackedScene] = []
# Probability of spawning an enemy at a valid spawn point (0-1)
@export var spawn_probability: float = 0.3
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
	pass

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
	
	# Cache the tilemap used_cells data to avoid repeated calls
	if not layer in tilemap_cache:
		tilemap_cache[layer] = {}
		
		# Try to find ground tiles
		var cells = layer.get_used_cells()
		print("MobSpawner: Checking layer ", layer.name, " with ", cells.size(), " cells")
		
		for cell_coord in cells:
			var tile_data = layer.get_cell_tile_data(cell_coord)
			if tile_data:
				# Check if the tile is marked as "ground" terrain
				var ground_value = tile_data.get_custom_data("ground")
				if ground_value == true:
					print("MobSpawner: Found ground tile at cell ", cell_coord)
					
					# Check if the tile above is empty (no collision)
					var above_cell = Vector2i(cell_coord.x, cell_coord.y - 1)
					var above_data = layer.get_cell_tile_data(above_cell)
					
					if above_data == null or not above_data.has_collision():
						# Convert cell to local position within the layer
						var local_pos = layer.map_to_local(cell_coord)
						print("MobSpawner: Local pos: ", local_pos, " Chunk pos: ", chunk_position)
						
						# Calculate the final world position - chunk position + local tile position
						var world_pos = chunk_position + local_pos
						
						# Apply vertical offset of +12 tiles (192 pixels) to move enemies DOWN to ground level
						world_pos.y += 166  # +12 tiles * 16 pixels per tile (positive Y = down)
						
						print("MobSpawner: Final spawn point: ", world_pos)
						# Store this valid spawn point
						spawn_points.append(world_pos)
	
	print("MobSpawner: Total spawn points: ", spawn_points.size())
	return spawn_points

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
	
	# Check for enemies that are too far off-screen
	for enemy in active_enemies.duplicate():
		if is_instance_valid(enemy) and enemy.position.x < -300:
			enemy.queue_free()
			active_enemies.erase(enemy)
