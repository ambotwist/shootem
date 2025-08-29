extends Node2D

@export var spawn_timer_duration: float = 3.0
@export var max_enemies: int = 15
# Spawn positions
@export var top_position: Vector2 = Vector2(222, -69)
@export var bottom_position: Vector2 = Vector2(222, 107)
# Level node path
@export_node_path var level_path

var spawn_timer: Timer
var spawn_on_top: bool = true
var level_manager: Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:	
	# Get reference to level manager
	if level_path:
		level_manager = get_node(level_path)
	
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
	# Calculate spawn position based on camera/scroll position
	var spawn_x_offset = 100  # Spawn ahead of camera view
	var spawn_x = 0
	
	if level_manager:
		spawn_x = level_manager.get_scroll_position().x + spawn_x_offset
	else:
		# If no level manager, use a default position
		spawn_x = top_position.x
		
	
