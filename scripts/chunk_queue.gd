extends Node2D

# The currently active chunks in the level
var active_chunks = []
# Width of each chunk in pixels
@export var chunk_width: int = 320  # 20 tiles × 16 pixels
# How many chunks to keep active at once
@export var keep_chunks: int = 3
# Signal when a chunk has been completely passed
signal chunk_passed

# Add a chunk to the active queue
func add_chunk(chunk: Node2D) -> void:
	active_chunks.append(chunk)
	add_child(chunk)
	
# Remove oldest chunk
func remove_oldest_chunk() -> void:
	if active_chunks.size() > 0:
		var oldest_chunk = active_chunks.pop_front()
		remove_child(oldest_chunk)
		oldest_chunk.queue_free()
		emit_signal("chunk_passed")
		
# Check if we need to generate more chunks based on camera position
func check_for_new_chunks(camera_position: Vector2) -> bool:
	if active_chunks.size() == 0:
		return true
		
	# Get the position of the last chunk
	var last_chunk = active_chunks.back()
	var last_chunk_end_x = last_chunk.position.x + chunk_width
	
	# If camera is getting close to the end of the last chunk, request a new one
	# Let's say within 1.5 chunks of the end
	var threshold = last_chunk_end_x - (chunk_width * 1.5)
	return camera_position.x > threshold
	
# Check if the oldest chunk is now off-screen and can be removed
func check_for_chunk_removal(camera_position: Vector2) -> void:
	if active_chunks.size() <= keep_chunks:
		return
		
	var oldest_chunk = active_chunks.front()
	var oldest_chunk_end_x = oldest_chunk.position.x + chunk_width
	
	# If the camera has moved past this chunk, remove it
	if camera_position.x > oldest_chunk_end_x:
		remove_oldest_chunk()

# For compatibility with chunk_spawner - not actually used
func start_scrolling() -> void:
	pass

# For compatibility with chunk_spawner - not actually used
func stop_scrolling() -> void:
	pass 
