class_name WorldMapPathDrawer
extends Node2D

func _draw() -> void:
	var map: Node2D = get_parent()
	if map != null and map.has_method(&"draw_map_elements"):
		map.draw_map_elements(self)
