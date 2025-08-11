extends Node2D
@onready var label: Label = $CanvasLayer/Control/MarginContainer/VBoxContainer/Label

# Initialize and connect signal for receive message from RN:
func _ready():
	if Engine.has_singleton("RNBridge"):
		var rn = Engine.get_singleton("RNBridge")
		rn.connect("event_from_rn", Callable(self, "_on_event_from_rn"))
	else:
		print("RNBridge no disponible (Android plugin no cargado).")

func _on_event_from_rn(json: String) -> void:
	print("RN → Godot:", json)
	label.text = label.text + "\n" + json


# For send message to RN:
func send_to_rn(payload: Dictionary) -> void:
	if Engine.has_singleton("RNBridge"):
		Engine.get_singleton("RNBridge").call("send_to_rn", JSON.stringify(payload))

func _on_button_pressed() -> void:
	send_to_rn({"type": "MESSAGE_FROM_GODOT"})
