extends TabContainer


var last_check:= 0.0
func _process(_delta: float) -> void:
	last_check += _delta
	if last_check < 0.1:
		return
	last_check = 0.0
	if get_global_rect().has_point(get_viewport().get_mouse_position()):
		%FreeCamera.disable_zoom = true
	else:
		%FreeCamera.disable_zoom = false
		pass
