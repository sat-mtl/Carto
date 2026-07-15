extends MeshInstance3D
var filter_shape
var filter_mode
var filter_active := true
var unselected_color: Color
var selected_color: Color

func update_controls():
	%CropScaleX.set_value_no_signal(scale[0])
	%CropScaleY.set_value_no_signal(scale[1])
	%CropScaleZ.set_value_no_signal(scale[2])

	%CropTranslateX.set_value_no_signal(position[0])
	%CropTranslateY.set_value_no_signal(position[1])
	%CropTranslateZ.set_value_no_signal(position[2])

	%CropRotateX.set_value_no_signal(rad_to_deg(rotation[0]))
	%CropRotateY.set_value_no_signal(rad_to_deg(rotation[1]))
	%CropRotateZ.set_value_no_signal(rad_to_deg(rotation[2]))

func update_cameras():
	## update side, front and top camera's positions
	# front camera
	%FrontCamera.size = max(scale[0], scale[1])
	%FrontCamera.position = position
	%FrontCamera.position[2] = (max(scale[0], scale[1])) + position[2]
	%FrontCamera.set_viewport_ratio(scale[0], scale[1])
	# side camera
	%SideCamera.size = max(scale[1], scale[2])
	%SideCamera.position = position
	%SideCamera.position[0] = (max(scale[1], scale[2])) + position[0]
	%SideCamera.set_viewport_ratio(scale[2], scale[1])
	# top camera
	%TopCamera.size = max(scale[0], scale[2])
	%TopCamera.position = position
	%TopCamera.position[1] = (max(scale[0], scale[2])) + position[1]
	%TopCamera.set_viewport_ratio(scale[0], scale[2])

func _ready() -> void:
	unselected_color = mesh.material.albedo_color
	selected_color = Color(mesh.material.albedo_color)
	selected_color.a *=3
	filter_shape = %FilterAreas.filter_shapes.BOX
	filter_mode = %FilterAreas.filter_modes.INCLUSION
	update_cameras()
	update_controls()

func highlight():
	mesh.material.albedo_color = selected_color

func unhighlight():
	mesh.material.albedo_color = unselected_color

var last_transform = transform
var dont_stack_next_transform_change = false

signal transform_changed

func _process(_delta):

	## update the control's values when the transform changes.
	if transform != last_transform:
		if not dont_stack_next_transform_change:
			# applie translation compensation before saving the transform state in
			# the undp-redo so that undo has the correctly translated transform
			apply_scaling_translation_compensation(last_transform.basis.get_scale())
			UndoManager.add_property_change_to_stack(
				"crop_region transform change",
				transform,
				last_transform,
				func(val):
					self.dont_stack_next_transform_change = true
					self.transform = val,
				func(_val): pass,
				false
			)
		else:
			dont_stack_next_transform_change = false
		transform_changed.emit(transform)
		update_controls()
		update_cameras()
		CameraManager.request_redraw()
	last_transform = transform

signal gizmo_requested

func _on_translate_x_value_changed(value: float) -> void:
	position[0] = value
	gizmo_requested.emit()

func _on_translate_y_value_changed(value: float) -> void:
	position[1] = value
	gizmo_requested.emit()

func _on_translate_z_value_changed(value: float) -> void:
	position[2] = value
	gizmo_requested.emit()

## Minimum scale of the crop region. Keeping this a bit higher than 0 prevents
## an annoying behaviour with the gizmo.
var minimum_scaling = 0.2

func apply_scaling_translation_compensation(last_scale) -> void:
	## This applies a translation by half the scaling delta to make it scaling
	## only adds range in the positive side of the axes instead of symetrically on
	## both sides.
	for i in range(3):
		if transform.basis.get_scale()[i] < minimum_scaling:
			scale[i] = minimum_scaling
		var half_delta = (transform.basis.get_scale()[i] - last_scale[i])/2
		position[i] += half_delta

func _on_scale_x_value_changed(value: float) -> void:
	scale[0] = value
	gizmo_requested.emit()

func _on_scale_y_value_changed(value: float) -> void:
	scale[1] = value
	gizmo_requested.emit()

func _on_scale_z_value_changed(value: float) -> void:
	scale[2] = value
	gizmo_requested.emit()

func _on_rotate_x_value_changed(value: float) -> void:
	rotation[0] = deg_to_rad(value)

func _on_rotate_y_value_changed(value: float) -> void:
	rotation[1] = deg_to_rad(value)

func _on_rotate_z_value_changed(value: float) -> void:
	rotation[2] = deg_to_rad(value)
