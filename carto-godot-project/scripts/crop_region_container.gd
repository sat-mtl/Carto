extends Node3D

class Border:
	extends Node3D

	static var border_material = StandardMaterial3D.new()
	static var handle_highlight_material = StandardMaterial3D.new()
	const border_width = 0.015
	const handle_width = 0.046
	const handle_length_ratio = 8.0
	const handle_collision_scaling = 3.6
	var mesh_instance = CSGMesh3D.new()
	var mesh = BoxMesh.new()
	var handles = [CSGMesh3D.new(), CSGMesh3D.new(), CSGMesh3D.new()]
	var handles_mesh = [BoxMesh.new(), BoxMesh.new(), BoxMesh.new()]
	var handles_collision_shape = [BoxShape3D.new(), BoxShape3D.new(), BoxShape3D.new()]
	var handles_area_3D = [Area3D.new(), Area3D.new(), Area3D.new()]
	var cgs_combiner = CSGCombiner3D.new()

	func _init():
		border_material.albedo_color = Color(0.1,0.1,0.1)
		handle_highlight_material.albedo_color = Color(0.4,0.4,0.4)
		border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		handle_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for i in range(3):
			handles_mesh[i].size = Vector3.ONE * handle_width
			handles_mesh[i].material = border_material
			handles[i].mesh = handles_mesh[i]
			handles_collision_shape[i].size = Vector3.ONE * handle_width * handle_collision_scaling
			var handle_collision_shape = CollisionShape3D.new()
			handle_collision_shape.shape = handles_collision_shape[i]
			handles_area_3D[i].add_child(handle_collision_shape)
			handles_area_3D[i].input_capture_on_drag = true
			cgs_combiner.add_child(handles_area_3D[i])
		mesh.size = Vector3.ONE * border_width
		mesh.material = border_material
		mesh_instance.mesh = mesh
		cgs_combiner.operation = CSGShape3D.OPERATION_UNION

	func get_handle_colliders():
		return handles_collision_shape

	func _ready() -> void:
		for j in range(3):
			cgs_combiner.add_child(handles[j])
		cgs_combiner.add_child(mesh_instance)
		add_child(cgs_combiner)

	func add_to_handle_pos(index, pos):
		handles[index].position += pos
		handles_area_3D[index].position += pos

	func add_to_pos(pos: Vector3):
		mesh_instance.position += pos
		for i in range(3):
			add_to_handle_pos(i,pos)

	func add_to_pos_x(pos_x: float):
		add_to_pos(Vector3(pos_x, 0, 0))
	func add_to_pos_y(pos_y: float):
		add_to_pos(Vector3(0, pos_y, 0))
	func add_to_pos_z(pos_z: float):
		add_to_pos(Vector3(0, 0, pos_z))

	func highlight_handles():
		for i in range(3):
			handles_mesh[i].material = handle_highlight_material

	func unhighlight_handles():
		for i in range(3):
			handles_mesh[i].material = border_material

	func set_handle_size_x(handle_idx, size):
		handles[handle_idx].mesh.size.x = size
		handles_collision_shape[handle_idx].size.x = size
	func set_handle_size_y(handle_idx, size):
		handles[handle_idx].mesh.size.y = size
		handles_collision_shape[handle_idx].size.y = size
	func set_handle_size_z(handle_idx, size):
		handles[handle_idx].mesh.size.z = size
		handles_collision_shape[handle_idx].size.z = size
	func connect_handles_signal(signal_name, callable):
		for i in range(3):
			handles_area_3D[i].connect(signal_name, callable)
var borders := []

func _on_handle_mouse_entered():
	if %Gizmo3D.editing or %Gizmo3D.hovering:
		return
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	for border in borders:
		border.highlight_handles()

func _on_handle_mouse_exited():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	for border in borders:
		border.unhighlight_handles()

signal crop_region_request_gizmo

var clicked_on_handle = false

func _on_handle_input_event(_cam: Node, _event: InputEvent, _event_position:Vector3, _normal:Vector3, _shape_idx:int):
	if Input.is_action_just_pressed("left_click") and not (%Gizmo3D.editing or %Gizmo3D.hovering):
		clicked_on_handle = true
	if clicked_on_handle and Input.is_action_just_released("left_click"):
		crop_region_request_gizmo.emit()
		clicked_on_handle = false

func _ready() -> void:
	for i in range(12):
		var border = Border.new()
		borders.append(border)
		add_child(border)
		border.connect_handles_signal("mouse_entered", _on_handle_mouse_entered)
		border.connect_handles_signal("mouse_exited", _on_handle_mouse_exited)
		border.connect_handles_signal("input_event", _on_handle_input_event)
	update_borders(%CropRegion.transform)

func update_borders(tform:Transform3D):
	for i in range(12):
		var border = borders[i]
		border.position = tform.origin
		border.rotation = tform.basis.orthonormalized().get_euler()
		border.mesh_instance.position = Vector3.ZERO
		for j in range(3):
			border.handles[j].position = Vector3.ZERO
			border.handles_area_3D[j].position = Vector3.ZERO
		if i < 4:
			# compensate for border width only on the end
			border.mesh_instance.mesh.size.x = tform.basis.x.length() + border.border_width
			for j in range(3):
				var handle_l = tform.basis.x.length() / border.handle_length_ratio + border.handle_width
				var balanced_idx = j-1
				border.set_handle_size_x(j, tform.basis.x.length() / border.handle_length_ratio + (border.handle_width * abs(balanced_idx)) )
				var offset = balanced_idx * (tform.basis.x.length() / 2) - (balanced_idx * handle_l / 2.0)
				border.add_to_handle_pos(j, Vector3(offset, 0, 0))
		elif i < 8:
			border.mesh_instance.mesh.size.y = tform.basis.y.length()
			for j in range(3):
				border.set_handle_size_y(j, tform.basis.y.length() / border.handle_length_ratio)
				var balanced_idx = j-1
				var offset = balanced_idx * (tform.basis.y.length() / 2) - (balanced_idx * tform.basis.y.length() / (border.handle_length_ratio * 2.0))
				border.add_to_handle_pos(j, Vector3(0, offset, 0))
		else:
			border.mesh_instance.mesh.size.z = tform.basis.z.length()
			for j in range(3):
				border.set_handle_size_z(j, tform.basis.z.length() / border.handle_length_ratio)
				var balanced_idx = j-1
				var offset = balanced_idx * (tform.basis.z.length() / 2) - (balanced_idx * tform.basis.z.length() / (border.handle_length_ratio * 2.0))
				border.add_to_handle_pos(j, Vector3(0, 0, offset))

	# can't be bothered to find the loop form of this, srry
	borders[0].add_to_pos_y(tform.basis.y.length()/2)
	borders[0].add_to_pos_z(tform.basis.z.length()/2)
	borders[1].add_to_pos_y(tform.basis.y.length()/2)
	borders[1].add_to_pos_z(-tform.basis.z.length()/2)
	borders[2].add_to_pos_y(-tform.basis.y.length()/2)
	borders[2].add_to_pos_z(tform.basis.z.length()/2)
	borders[3].add_to_pos_y(-tform.basis.y.length()/2)
	borders[3].add_to_pos_z(-tform.basis.z.length()/2)

	borders[4].add_to_pos_x(tform.basis.x.length()/2)
	borders[4].add_to_pos_z(tform.basis.z.length()/2)
	borders[5].add_to_pos_x(tform.basis.x.length()/2)
	borders[5].add_to_pos_z(-tform.basis.z.length()/2)
	borders[6].add_to_pos_x(-tform.basis.x.length()/2)
	borders[6].add_to_pos_z(tform.basis.z.length()/2)
	borders[7].add_to_pos_x(-tform.basis.x.length()/2)
	borders[7].add_to_pos_z(-tform.basis.z.length()/2)

	borders[8].add_to_pos_y(tform.basis.y.length()/2)
	borders[8].add_to_pos_x(tform.basis.x.length()/2)
	borders[9].add_to_pos_y(tform.basis.y.length()/2)
	borders[9].add_to_pos_x(-tform.basis.x.length()/2)
	borders[10].add_to_pos_y(-tform.basis.y.length()/2)
	borders[10].add_to_pos_x(tform.basis.x.length()/2)
	borders[11].add_to_pos_y(-tform.basis.y.length()/2)
	borders[11].add_to_pos_x(-tform.basis.x.length()/2)

func _on_crop_region_transform_changed(tform: Transform3D) -> void:
	update_borders(tform)
