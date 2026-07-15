extends Node

func are_aligned_with_up_vector(pos:Vector3, target:Vector3):
	return Vector3.UP.cross(target - pos).is_equal_approx(Vector3.ZERO)

func safe_look_at(obj: Node3D, target: Vector3):
	if not obj.global_position.is_equal_approx(target) and not are_aligned_with_up_vector(obj.global_position, target):
		obj.look_at(target, Vector3.UP)
	else:
		if obj.rotation.x > 0:
			obj.rotation.x = PI/2.0
		else:
			obj.rotation.x = -PI/2.0
