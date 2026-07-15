extends Gizmo3D

func _edit_scale(target_scale : Vector3) -> Vector3:
	# prevent negative scaling.
	var new_scale:Vector3 = target_scale + _edit.original.basis.get_scale()
	for i in range(3):
		if new_scale[i] < 0:
			var zero_scale = Vector3.ZERO
			# 0 is a pathological case.
			zero_scale[i] = (-_edit.original.basis.get_scale()[i])+0.0001
			return zero_scale
	return target_scale
