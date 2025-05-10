extends Area2D

@onready var timer: Timer = $Timer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body:Node2D) -> void:	
	if body.name == "Character":
		get_tree().reload_current_scene()
	


func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
