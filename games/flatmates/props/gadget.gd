class_name Gadget
extends Node2D

## Anything in a stage a script can name: `lift`, `bell`, `amps`. Its name is
## `js_name`. It fires events by name (`fired`), which addEventListener hears,
## and `js_methods` lists what a script may call on it. Gadgets draw
## themselves in the stage palette, on whole pixels.

signal fired(event: String)

## The name scripts use for it. Empty keeps it out of scripts.
@export var js_name: String = ""
## Shown over it in small type when a script can name it.
@export var show_name: bool = true

var stage: Node


func js_label() -> String:
	return js_name.capitalize().replace(" ", "")


func js_methods() -> PackedStringArray:
	return PackedStringArray()


func js_call(_method: String, _args: Array) -> Variant:
	return null


func js_get(_prop: String) -> Variant:
	return null


## The player (or a script's press()) used it while standing on it.
func use(_by: Flatmate) -> bool:
	return false


## A strum nearby.
func hear_strum(_by: Flatmate) -> void:
	pass


func emit_event(event: String) -> void:
	fired.emit(event)


func pixel_rect(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position.round(), rect.size.round()), color)


func draw_name(at: Vector2, tint: Color = Palette.CODE) -> void:
	if js_name == "" or not show_name:
		return
	var text := js_name
	var width := Palette.mono().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL).x
	var spot := (at + Vector2(-width * 0.5, 0.0)).round()
	draw_string_outline(Palette.mono(), spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, 3, Palette.INK)
	draw_string(Palette.mono(), spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, tint)
