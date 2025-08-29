extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var _is_disabled: bool


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_is_disabled = false
	
	# Connect animation finished signal
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func consume():
	if !_is_disabled:
		sprite.play("consume")
		_is_disabled = true

func regen():
	if _is_disabled:
		sprite.play("default")
		_is_disabled = false

func _on_animation_finished():
	# When consume animation finishes, switch to empty state
	if sprite.animation == "consume":
		sprite.play("empty")
