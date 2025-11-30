extends Control

signal pressed

func _gui_input(event):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("pressed")
