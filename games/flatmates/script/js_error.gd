class_name JsError
extends RefCounted

## A thrown JavaScript error, e.g. "TypeError: clive.strum is not a function".
## Whatever is running stops, the way an uncaught error stops a real script,
## and the console shows the message in red.

var message: String = ""


static func make(kind: String, text: String) -> JsError:
	var error := JsError.new()
	error.message = "%s: %s" % [kind, text]
	return error
