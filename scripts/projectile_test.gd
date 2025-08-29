extends Node2D

func _ready():
	# Print collision layers for debugging
	print("====== COLLISION LAYER DEBUG =======")
	var scene_root = get_tree().get_root().get_children()
	for node in scene_root:
		_print_collision_info(node, 0)
	print("===================================")

# Recursive function to print collision information
func _print_collision_info(node, indent_level):
	var indent = "  ".repeat(indent_level)
	
	# Check if node has collision properties
	if node is PhysicsBody2D or node is TileMap or node is Area2D:
		print(indent + node.name + " (" + node.get_class() + "):")
		
		if "collision_layer" in node:
			print(indent + "  Layer: " + str(node.collision_layer) + " - Binary: " + _int_to_binary(node.collision_layer))
		
		if "collision_mask" in node:
			print(indent + "  Mask: " + str(node.collision_mask) + " - Binary: " + _int_to_binary(node.collision_mask))
	
	# Recursively check all children
	for child in node.get_children():
		_print_collision_info(child, indent_level + 1)

# Helper function to convert integer to binary string for better visualization
func _int_to_binary(value):
	var binary = ""
	for i in range(20):  # Show up to 20 bits (Godot uses 32 but first 20 are enough)
		if value & (1 << i):
			binary = "1" + binary
		else:
			binary = "0" + binary
		
		if i % 4 == 3 and i < 19:  # Add space every 4 bits for readability
			binary = " " + binary
			
	return binary 