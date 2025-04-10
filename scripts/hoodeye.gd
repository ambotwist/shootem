extends Node2D

@export var SPEED: float = 25.0
@export var max_hurt: float = 1.0
@export var hurt_cooldown_speed: float = 0.3

@onready var sprites: Sprite2D = $Sprites

var _hurt: float = 0.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Make sure sprite has the material and ensure it's unique to this instance
	if sprites:
		if sprites.material:
			# Create a unique duplicate of the shader material
			sprites.material = sprites.material.duplicate()
			sprites.material.set_shader_parameter("brightness", 0.0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x -= SPEED * delta
	if _hurt > 0:
		hurt(-hurt_cooldown_speed * delta)


func hurt(amount: float) -> void:
	if visible && sprites && sprites.material:
		_hurt = max(_hurt + amount, 0)
		sprites.material.set_shader_parameter("brightness", _hurt / max_hurt)
		if _hurt > max_hurt:
			queue_free()
