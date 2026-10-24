class_name JsPromise
extends RefCounted

## What a flatmate's method hands back: settles when the step is done.
## `await` in a script waits on `settled`.

signal settled

var done: bool = false
var value: Variant = null


func resolve(result: Variant = null) -> void:
	if done:
		return
	done = true
	value = result
	settled.emit()


static func resolved(result: Variant = null) -> JsPromise:
	var promise := JsPromise.new()
	promise.resolve(result)
	return promise
