class_name Backdrop
extends RefCounted

## A room painted by tools/scenery.py: 960x540 texels shown at 480x270, two
## texels to a room pixel like the cast, through the same sharp-pixel shader.

const SHARP := preload("res://world/sharp_pixels.gdshader")


static func sprite(path: String) -> Sprite2D:
	var node := Sprite2D.new()
	node.centered = false
	if ResourceLoader.exists(path):
		node.texture = load(path) as Texture2D
		node.scale = Vector2(480, 270) / node.texture.get_size()
	var sharp := ShaderMaterial.new()
	sharp.shader = SHARP
	node.material = sharp
	return node
