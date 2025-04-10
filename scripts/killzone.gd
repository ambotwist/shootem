extends Area2D

@onready var timer: Timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set collision layer to Layer 2 (ENEMIES)
	collision_layer = 2
	
	# Set collision mask to Layer 3 (CHARACTER) - to detect the character
	collision_mask = 4
	
	# Make sure monitoring is on
	monitoring = true
	monitorable = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body:Node2D) -> void:	
	if body.name == "Character":
		get_tree().reload_current_scene()
	


func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
