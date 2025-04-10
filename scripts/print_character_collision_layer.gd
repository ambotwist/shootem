extends SceneTree

func _init():
    var character_scene = load("res://scenes/character.tscn")
    if character_scene:
        var character_instance = character_scene.instantiate()
        print("Character Collision Layer: ", character_instance.collision_layer)
        print("Character Collision Mask: ", character_instance.collision_mask)
    else:
        print("Failed to load character scene")
    quit() 