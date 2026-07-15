extends PopupMenu

func _on_manipulator_gizmo_orthographic_requested(axis: int, inverted: bool) -> void:
	var id
	if axis == %ManipulatorGizmo.axes.X:
		id = 1 if inverted else 2
	elif axis == %ManipulatorGizmo.axes.Z:
		id = 4 if inverted else 3
	elif axis == %ManipulatorGizmo.axes.Y:
		id = 6 if inverted else 5
	title = get_item_text(id)

func set_to_perspective():
	title = get_item_text(0)
