extends Node3D

signal transform_changed(transform)
var init_position_set := false
var camera_num: int:
	set(num):
		camera_num = num
		if not init_position_set:
			set_init_position(num)
			init_position_set = true

var material = StandardMaterial3D.new()
var pmesh := PointMesh.new()
var camera
var text_mesh = TextMesh.new()
var text_material = StandardMaterial3D.new()

const camera_default_y = 2.0
const camera_spawn_offset = 1.0

func set_init_position(num:int):
	if num == 1:
		dont_stack_next_transform_change = true
		transform.origin = Vector3(0, camera_default_y, 0)
		return
	# Make an evenly spaced square grid out of camera instanciation
	var side_size: int = ceil(sqrt(num))
	var square_size = ceil(sqrt(num))**2
	var square_idx = square_size - (num-1)
	var z_idx = side_size - 1
	var x_idx = side_size - 1
	if square_idx < side_size:
		x_idx = side_size - square_idx - 1
	elif square_idx > side_size:
		z_idx = square_idx - side_size - 1
	dont_stack_next_transform_change = true
	transform.origin = Vector3(x_idx * camera_spawn_offset, camera_default_y, z_idx * camera_spawn_offset)

func _ready() -> void:
	text_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	text_material.albedo_color = Color.WHITE
	text_mesh.material = text_material
	# hack transparency to make sure text is always rendered over point clouds.
	text_mesh.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	text_material.render_priority = 4
	text_mesh.depth = 0
	text_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	%CameraNameMeshInstance3D.mesh = text_mesh
	print(%MultiMeshInstance3D.layers)

func _on_name_change(n: String):
	text_mesh.text = n

func init_multimesh_instance(multimesh:MultiMesh):
	%MultiMeshInstance3D.multimesh = multimesh
	%MultiMeshInstance3D.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=color
	material.use_point_size = true
	material.point_size=1
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmesh.material=material
	%MultiMeshInstance3D.multimesh.mesh=pmesh

func _set_centroid_position(pos:Vector3):
	var old_global_pos = %CentroidPivot.global_position
	%CentroidPivot.position = pos
	%CameraSprite3D.position = pos
	# ensures the centroid indicator always is at the centroid position.
	# warning : event though the centroid indicator is not shown, its position is
	# used to compute the heading of the camera icon.
	if pos == Vector3.ZERO:
		%CentroidIndicator.position = centroid
	else:
		%CentroidIndicator.position = -pos
	should_draw = true
	dont_stack_next_transform_change = true
	position += old_global_pos - %CentroidPivot.global_position

func set_centroid_pivot_position(cent:Vector3, old_centroid:Vector3):
	var old_pos = %CentroidPivot.position
	#copy current state of centroid_toggled
	var is_toggled:bool = centroid_toggled
	UndoManager.add_to_stack(
		"set centroid cam " + str(camera_num),
		func():
			centroid_toggled = is_toggled
			if cent != Vector3.ZERO:
				centroid = cent
			_set_centroid_position(-cent)
			camera.set_centroid_state_in_ui_node(centroid_toggled)
			,
		func():
			centroid_toggled = not is_toggled
			camera.set_centroid_state_in_ui_node(centroid_toggled)
			_set_centroid_position(old_pos)
			centroid = old_centroid)

var displayed: bool = true

func update_display_state(soloed_devices:Array):
	## determines if the points should be displayed depending on the array
	## of cameras which are currently soloed and the current display state
	## of this camera.
	if len(soloed_devices) > 0:
		if soloed_devices.find(camera_num) > -1:
			%MultiMeshInstance3D.visible = displayed
		else:
			%MultiMeshInstance3D.visible = false
	else:
		%MultiMeshInstance3D.visible = displayed

func _on_displayed_change(state):
	displayed = state

var highlight_color:Color
var color: Color:
	set(col):
		color = col
		material.albedo_color = col
		highlight_color = col.lightened(0.7)
		var col_no_alpha = Color(col)
		col_no_alpha.a = 1
		%CameraSprite3D.modulate = col_no_alpha

func _on_color_change(changed_color):
	color = changed_color

var point_size: float:
	set(pt_size):
		point_size = pt_size
		material.point_size = pt_size

func _on_point_size_change(pt_size):
	self.point_size = pt_size

func _on_centroid_change(cent, toggled_on, undoable):
	toggle_centroid(cent, toggled_on, undoable)

var centroid_toggled = true
var centroid:= Vector3.ZERO
func toggle_centroid(cent, toggled_on, undoable=true):
	centroid_toggled = toggled_on
	if not toggled_on:
		set_centroid_pivot_position(Vector3.ZERO, centroid)
	else:
		if undoable:
			set_centroid_pivot_position(cent, centroid)
		else:
			centroid = cent
			centroid_toggled = toggled_on
			_set_centroid_position(-centroid)

var should_draw = true
var last_transform: Transform3D = transform

# set this to true to make _process ignore the next transform change for
# undoing purposes.
var dont_stack_next_transform_change := false

func _process(_delta):

	var cam = get_viewport().get_camera_3d()

	%CameraNameMeshInstance3D.position = %CameraSprite3D.position
	%CameraNameMeshInstance3D.position += %CameraNameMeshInstance3D.basis*Vector3.RIGHT * 0.2
	%CameraNameMeshInstance3D.rotation = %CameraSprite3D.rotation

	%CameraNameMeshInstance3D.look_at(cam.global_position,cam.basis * Vector3.UP, true)

	%CameraSprite3D.look_at(cam.global_position, cam.basis * Vector3.UP)
	var rotz = %CameraSprite3D.rotation.z
	var cam_vector = %CameraSprite3D.global_position - cam.global_position

	var camera_plane_normal = (cam.basis * Vector3.FORWARD).normalized()
	var pivot_centroid_offset
	if %CentroidPivot.position == Vector3.ZERO:
		pivot_centroid_offset = (%CentroidIndicator.global_position)
	else:
		pivot_centroid_offset = (global_position+centroid+%CentroidPivot.position)
	var dist_from_sprite_to_cam = camera_plane_normal.dot(cam_vector)
	var projected_sprite_pos = %CameraSprite3D.global_position - dist_from_sprite_to_cam * camera_plane_normal
	var centroid_cam_vector = pivot_centroid_offset - cam.global_position
	var dist_from_centroid_to_cam = camera_plane_normal.dot(centroid_cam_vector)
	var projected_centroid_pos = pivot_centroid_offset - dist_from_centroid_to_cam * camera_plane_normal

	var from_sprite_to_cent = (projected_centroid_pos - projected_sprite_pos).normalized()
	var right_vector = cam.basis * Vector3.RIGHT

	# I had a solution that did not account for angles > 180deg
	# and chatGPT came up with the cross product into dot product thing.
	# I have some intuition of why it works but I could not explain it.
	var cross = right_vector.cross(from_sprite_to_cent)
	var angle = atan2(camera_plane_normal.dot(cross), right_vector.dot(from_sprite_to_cent))

	# add previously saved rotz to compensate for the look_at z angle shift
	%CameraSprite3D.rotation.z = rotz + angle + PI

	var transformed_has_changed = transform != last_transform
	if transformed_has_changed:
		transform_changed.emit(transform)
		if not dont_stack_next_transform_change:
			var undo_redo_name = "point_cloud " + str(camera_num) + " transform change"
			if CameraManager.group_edit_ongoing:
				undo_redo_name = "point_cloud group transform change"
				CameraManager.stack_group_transform(last_transform, transform, self)
			else:
				UndoManager.add_property_change_to_stack(
					undo_redo_name,
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
	last_transform = transform

var gizmo_selected := false:
	set(selected):
		camera.gizmo_selected = selected

func highlight():
	material.albedo_color = highlight_color
	material.render_priority = 2
	var col_no_alpha = Color(highlight_color)
	col_no_alpha.a = 1
	%CameraSprite3D.modulate = col_no_alpha
	%CameraNameMeshInstance3D.visible = true

func unhighlight():
	material.albedo_color = color
	material.render_priority = 1
	var col_no_alpha = Color(color)
	col_no_alpha.a = 1
	%CameraSprite3D.modulate = col_no_alpha
	%CameraNameMeshInstance3D.visible = false

func _on_camera_sprite_static_body_3d_mouse_entered() -> void:
	camera.highlight()

func _on_camera_sprite_static_body_3d_mouse_exited() -> void:
	camera.unhighlight()
