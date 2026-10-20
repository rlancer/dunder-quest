extends Node

func _ready() -> void:
	var node := Parallax2D.new()
	for prop in node.get_property_list():
		var name := str(prop["name"])
		if name.begins_with("scroll") or name.begins_with("repeat") or name.begins_with("follow") or name.begins_with("ignore") or name.begins_with("auto") or name == "z_index" or name == "texture_filter":
			print("PROP ", name, " = ", node.get(name))
	get_tree().quit(0)
