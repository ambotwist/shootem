extends Node2D

@export var SPEED: float = 25.0
@export var max_hurt: float = 0.5

@onready var sprites: Sprite2D = $Sprites

var _hurt: float = 0.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add to enemies group for tracking
	add_to_group("enemies")
	
	# Make sure sprite has the material and ensure it's unique to this instance
	if sprites:
		if sprites.material:
			# Create a unique duplicate of the shader material
			sprites.material = sprites.material.duplicate()
			sprites.material.set_shader_parameter("brightness", 0.0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x -= SPEED * delta
	
	# Destroy if moved too far off screen to clean up
	if position.x < -300:
		queue_free()


func hurt(amount: float) -> void:
	if visible && sprites && sprites.material:
		_hurt = max(_hurt + amount, 0)
		sprites.material.set_shader_parameter("brightness", _hurt / max_hurt)
		if _hurt > max_hurt:
			# Notify game about enemy death
			var game = get_node("/root/Game")
			if game && game.has_method("enemy_died"):
				game.enemy_died()
			queue_free()


# Called when the node is removed from the scene
func _exit_tree() -> void:
	# Ensure we notify the game if we're destroyed for any reason
	if _hurt <= max_hurt:  # If we weren't already fully destroyed by hurt()
		var game = get_node("/root/Game")
		if game && game.has_method("enemy_died"):
			game.enemy_died()
