extends Node2D

# Constants
const CHUNK_WIDTH = 20 * 16  # 20 tiles * 16 pixels per tile
const CHUNK_HEIGHT = 7 * 16  # 7 tiles * 16 pixels per tile

# Configuration
@export var initial_chunks: int = 3
@export var chunk_prefix: Array[String] = ["Z1_D0_", "Z1_D1_"]

# References
@export_node_path var chunk_queue_path
var chunk_queue

# Bottom chunk groups
var bottom_chunks = ["Z1_D0", "Z1_D1"]
# Top chunk groups by connection type
var top_chunks = {
	"standard": ["Z1_B0", "Z1_B1"],  # Standard chunks (no special connections)
	"left": ["Z1_L0", "Z1_L1"],      # Left-connecting chunks
	"right": ["Z1_R0", "Z1_R1"],     # Right-connecting chunks 
	"both": ["Z1_B0", "Z1_B1"]       # Both sides connecting chunks
}

# Chunk width in pixels
@export var chunk_width: int = 320 # 20 tiles × 16 pixels
# Chunk height in pixels
@export var chunk_height: int = 112 # 7 tiles × 16 pixels
# Starting area size (in pixels)
@export var starting_area_width: float = 112 +160 # 7 tiles × 16 pixels
# Vertical position of chunks (y position)
@export var chunk_y_position: float = 0
# Enable debug output
@export var debug_mode: bool = false

# Store reference to chunk parts for use in spawning
var bottom_chunk_parts = {}
var top_chunk_parts = {}
# Position for next chunk
var next_chunk_position = Vector2.ZERO

# Keep track of the last top chunk type for proper connections
var last_top_chunk_type = ""

func _ready() -> void:
	# Initialize random generator
	randomize()
	
	# Get reference to the chunk queue
	if chunk_queue_path:
		chunk_queue = get_node(chunk_queue_path)
	else:
		# Try to find it in the parent
		var parent = get_parent()
		var potential_queue = parent.get_node_or_null("ChunkQueue")
		if potential_queue:
			chunk_queue = potential_queue
		else:
			push_error("No chunk queue found! Make sure to assign chunk_queue_path or add a ChunkQueue node as a sibling.")
			return
			
	# Identify and organize available chunk parts
	_find_chunk_parts()
	
	# Log available chunks
	if debug_mode:
		print("--- Available chunks ---")
		print("Bottom chunks: ", bottom_chunk_parts.keys())
		print("Top chunks: ", top_chunk_parts.keys())
		
		# Report missing chunks
		for connection_type in top_chunks:
			for chunk_type in top_chunks[connection_type]:
				if not chunk_type in top_chunk_parts or top_chunk_parts[chunk_type].size() == 0:
					push_warning("Missing top chunk type: " + chunk_type)
	
	# Set the initial chunk position to account for the starting area
	# Only adjust the x position, keep y at the specified value
	next_chunk_position = Vector2(starting_area_width, chunk_y_position)
	
	# Generate initial chunks
	generate_initial_chunks(3)

# Find all available chunk parts
func _find_chunk_parts() -> void:
	# Hide template chunks
	for node in $Under.get_children():
		if node.get_parent() == $Under:
			node.visible = false
	
	for node in $Above.get_children():
		if node.get_parent() == $Above:
			node.visible = false
			
	# For each bottom chunk type
	for chunk_type in bottom_chunks:
		var parts = []
		
		# Look for the chunk groups under the 'Under' node
		for child in $Under.get_children():
			if child.name.begins_with(chunk_type):
				# Find TileMapLayers in this group
				var layers = []
				for layer_child in child.get_children():
					if layer_child is TileMapLayer and not layer_child.tile_map_data.is_empty():
						layers.append(layer_child)
				
				if layers.size() > 0:
					# Add this as an available part
					parts.append({
						"group": child,
						"layers": layers
					})
		
		if parts.size() > 0:
			bottom_chunk_parts[chunk_type] = parts
		else:
			push_error("No bottom chunk parts found for " + chunk_type)
	
	# Process all top chunk types
	var all_top_chunks = []
	for connection_type in top_chunks:
		all_top_chunks.append_array(top_chunks[connection_type])
	
	# For each top chunk type
	for chunk_type in all_top_chunks:
		var parts = []
		
		# Look for the chunk groups under the 'Above' node
		for child in $Above.get_children():
			if child.name.begins_with(chunk_type):
				# Find TileMapLayers in this group
				var layers = []
				for layer_child in child.get_children():
					if layer_child is TileMapLayer and not layer_child.tile_map_data.is_empty():
						layers.append(layer_child)
				
				if layers.size() > 0:
					# Add this as an available part
					parts.append({
						"group": child,
						"layers": layers
					})
		
		if parts.size() > 0:
			top_chunk_parts[chunk_type] = parts
		
		# Log if no parts found for this chunk type
		if debug_mode and parts.size() == 0:
			push_warning("No valid tilemap layers found for: " + chunk_type)

# Generate initial chunks
func generate_initial_chunks(count: int) -> void:
	for i in range(count):
		spawn_next_chunk()

# Spawn a new chunk
func spawn_next_chunk() -> void:
	var new_chunk = Node2D.new()
	new_chunk.name = "Chunk"
	
	# First, determine the top chunk type based on connection rules
	var top_chunk_info = determine_next_top_chunk()
	if top_chunk_info == null:
		push_error("Failed to determine a valid top chunk type!")
		return
		
	# Extract the top chunk type and create the layer
	var top_chunk_type = top_chunk_info.chunk_type
	var top_layer = create_top_chunk(top_chunk_type)
	if top_layer:
		top_layer.z_index = 1
		new_chunk.add_child(top_layer)
		if debug_mode:
			print("Created top chunk of type: ", top_chunk_type)
		
		# Store this as the last top chunk type for future connections
		last_top_chunk_type = top_chunk_type
	else:
		push_error("Failed to create top chunk of type: " + top_chunk_type)
		return
	
	# Next, select a compatible bottom chunk based on the top chunk
	var bottom_layer = create_compatible_bottom_chunk(top_chunk_type)
	if bottom_layer:
		new_chunk.add_child(bottom_layer)
	else:
		push_error("Failed to create compatible bottom chunk for top chunk: " + top_chunk_type)
		return
	
	# Position the chunk
	new_chunk.position = next_chunk_position
	# Only increment the x position for the next chunk, keep y the same
	next_chunk_position.x += chunk_width
	
	# Add to queue
	chunk_queue.add_chunk(new_chunk)

# Determine the type of top chunk to create next based on connection rules
func determine_next_top_chunk():
	var available_types = []
	
	# Apply connection rules based on last chunk
	if last_top_chunk_type == "":
		# No previous chunk, can choose any type
		var connection_types = ["standard", "right", "both", "left"]
		var random_type = connection_types[randi() % connection_types.size()]
		available_types = top_chunks[random_type]
		if debug_mode:
			print("No previous chunk, selected connection type: ", random_type)
	elif last_top_chunk_type.begins_with("Z1_R"):
		# Last chunk was Right-connecting
		# Must be followed by Left-connecting or Both-connecting chunk
		if randf() < 0.5 and has_available_chunks("left"):
			available_types = top_chunks["left"]
			if debug_mode:
				print("After R chunk, selected L")
		else:
			available_types = top_chunks["both"]
			if debug_mode:
				print("After R chunk, selected B")
	elif last_top_chunk_type.begins_with("Z1_L"):
		# Last chunk was Left-connecting
		# Must be followed by Right-connecting chunk
		available_types = top_chunks["right"]
		if debug_mode:
			print("After L chunk, selected R")
	elif last_top_chunk_type.begins_with("Z1_B"):
		# Last chunk was Both-connecting
		# Must be followed by Left-connecting or Both-connecting chunk
		if randf() < 0.5 and has_available_chunks("left"):
			available_types = top_chunks["left"]
			if debug_mode:
				print("After B chunk, selected L")
		else:
			available_types = top_chunks["both"]
			if debug_mode:
				print("After B chunk, selected B")
	else:
		# Default to standard chunks
		available_types = top_chunks["standard"]
		if debug_mode:
			print("Used default standard chunks")
	
	# If we have no valid types for the rules, fall back to standard
	if available_types.size() == 0 or not has_available_chunk_types(available_types):
		if debug_mode:
			print("No valid types available, falling back to standard")
		available_types = top_chunks["standard"]
	
	# Filter out types that have no available chunks
	var valid_types = []
	for chunk_type in available_types:
		if chunk_type in top_chunk_parts and top_chunk_parts[chunk_type].size() > 0:
			valid_types.append(chunk_type)
	
	# If no valid types, return null
	if valid_types.size() == 0:
		if debug_mode:
			print("No valid chunk types available")
		return null
	
	# Choose a random chunk type from valid options
	var selected_type = valid_types[randi() % valid_types.size()]
	
	# Get a random part info for this type
	var part_info = top_chunk_parts[selected_type][randi() % top_chunk_parts[selected_type].size()]
	
	# Select a random layer from this part
	var selected_layer = part_info.layers[randi() % part_info.layers.size()]
	
	# Return the selected chunk info
	return {
		"chunk_type": selected_type,
		"part_info": part_info,
		"selected_layer": selected_layer
	}

# Create a top chunk of the specified type with the specified layer
func create_top_chunk(chunk_type: String) -> Node2D:
	# Make sure we have parts for this chunk type
	if not chunk_type in top_chunk_parts or top_chunk_parts[chunk_type].size() == 0:
		push_error("No parts available for top chunk type: " + chunk_type)
		return null
	
	# Get a random part info
	var part_info = top_chunk_parts[chunk_type][randi() % top_chunk_parts[chunk_type].size()]
	
	# Select a random TileMapLayer
	var selected_layer = part_info.layers[randi() % part_info.layers.size()]
	
	# Create a new Node2D for the chunk layer
	var layer_instance = Node2D.new()
	layer_instance.name = "TopLayer"
	
	# Duplicate the layer
	var new_layer = selected_layer.duplicate()
	new_layer.visible = true
	layer_instance.add_child(new_layer)
	
	return layer_instance

# Create a bottom chunk that's compatible with the given top chunk type
func create_compatible_bottom_chunk(top_chunk_type: String) -> Node2D:
	# Determine which bottom chunks are compatible
	var compatible_bottom_chunks = []
	
	# Apply compatibility rules:
	# - Z1_D1 should NEVER be under a top chunk with a "1" in the second identifier
	if top_chunk_type.ends_with("1"):
		# For top chunks with "1" in second identifier, only use Z1_D0
		compatible_bottom_chunks = ["Z1_D0"]
		if debug_mode:
			print("Top chunk has '1', only using Z1_D0 for bottom")
	else:
		# For other top chunks, both bottom types are valid
		compatible_bottom_chunks = bottom_chunks.duplicate()
		if debug_mode:
			print("Top chunk doesn't have '1', can use any bottom chunk")
	
	# Choose a random compatible bottom chunk type
	var chunk_type = compatible_bottom_chunks[randi() % compatible_bottom_chunks.size()]
	
	# Check if we have parts for this chunk type
	if not chunk_type in bottom_chunk_parts or bottom_chunk_parts[chunk_type].size() == 0:
		push_error("No parts available for bottom chunk type: " + chunk_type)
		return null
	
	# Get a random part info
	var part_info = bottom_chunk_parts[chunk_type][randi() % bottom_chunk_parts[chunk_type].size()]
	
	# Select a random TileMapLayer
	var selected_layer = part_info.layers[randi() % part_info.layers.size()]
	
	# Create a new Node2D for the chunk layer
	var layer_instance = Node2D.new()
	layer_instance.name = "BottomLayer"
	
	# Duplicate the layer
	var new_layer = selected_layer.duplicate()
	new_layer.visible = true
	layer_instance.add_child(new_layer)
	
	if debug_mode:
		print("Created bottom chunk of type: ", chunk_type)
	
	return layer_instance

# Check if we have chunks available for a specific connection type
func has_available_chunks(connection_type: String) -> bool:
	if not connection_type in top_chunks:
		return false
		
	for chunk_type in top_chunks[connection_type]:
		if chunk_type in top_chunk_parts and top_chunk_parts[chunk_type].size() > 0:
			return true
	
	return false

# Check if we have any available chunks of the given types
func has_available_chunk_types(chunk_types: Array) -> bool:
	for chunk_type in chunk_types:
		if chunk_type in top_chunk_parts and top_chunk_parts[chunk_type].size() > 0:
			return true
	
	return false

# Check if new chunks should be spawned
func check_for_new_chunks(camera_position: Vector2) -> void:
	if chunk_queue.check_for_new_chunks(camera_position):
		spawn_next_chunk()

# Compatibility methods
func start_scrolling() -> void:
	pass

func stop_scrolling() -> void:
	pass
