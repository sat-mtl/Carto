extends PanelContainer

var camera_num: int:
	set(num):
		camera_num = num
		%CameraNum.text = str(num)

var orbbec_devices: OrbbecDevices
var camera

# still necessary for transform changes.
var point_cloud

var gizmo_icon := preload("res://assets/gizmo_icon.svg").duplicate()

var fps_gradient = Gradient.new()

var all_fps = ["30", "25", "15", "5"]

var current_orbbec_ip_idx := 0
var current_orbbec_resolution_idx := 1
var current_orbbec_fps_idx := 0
var current_device_type_idx := 0
var current_hesai_port := 0

# the default hesai ip is the current ip.
var current_hesai_ip := "192.168.1.201"

var active_state := true:
	set(state):
		active_state = state
		camera.active = active_state
		%ActiveSwitch.set_pressed_no_signal(state)

static var eye_open_texture := preload("res://assets/eye_open.svg")
static var eye_closed_texture := preload("res://assets/eye_closed.svg")

func set_display_button_no_signal(state):
	%DisplayButton.set_pressed_no_signal(state)
	if state:
		%DisplayButton.icon = eye_open_texture
	else:
		%DisplayButton.icon = eye_closed_texture

var displayed := true:
	set(state):
		displayed = state
		set_display_button_no_signal(state)

func _on_displayed_change(state):
	set_display_button_no_signal(state)

var soloed := false:
	set(state):
		soloed = state
		%SoloButton.set_pressed_no_signal(state)

func _on_soloed_changed(state):
	%SoloButton.set_pressed_no_signal(state)

var stylebox = preload("res://themes/camera_settings_panel_stylebox.stylebox").duplicate()

var highlight_stylebox = preload("res://themes/camera_settings_panel_stylebox.stylebox").duplicate()

func _ready() -> void:
	%GizmoSelectButton.icon = gizmo_icon
	%ColorPickerButton.color = color
	highlight_stylebox.bg_color = Color(1,1,1,0)
	# calls the set function of the color because if the color was set before ready,
	# some elements were not properly loaded and need to be re-set
	color = color
	fps_gradient.remove_point(0)
	fps_gradient.add_point(0.0, Color(1,0,0))
	fps_gradient.add_point(0.5, Color(1,1,0,))
	fps_gradient.add_point(1.0, Color(0,1,0,))
	for fps in all_fps:
		%OrbbecFPSOptionButton.add_item(fps)
		%OrbbecFPSOptionButton.select(0)
	%ThinningSlider.set_value_no_signal(camera.thinning)
	add_theme_stylebox_override("panel", highlight_stylebox)
	%BackgroundPanelContainer.add_theme_stylebox_override("panel", stylebox)
	update_controls_for_device()

func _on_pointcloud_connecting():
	%OrbbecIPOptionButton.disabled = true
	%OrbbecFPSOptionButton.disabled = true
	%OrbbecResolutionOptionButton.disabled = true
	%HesaiIPLineEdit.editable = false
	%HesaiPortSpinBox.editable = false
	%DeviceOptionButton.disabled = true
	%ActiveSwitch.disabled = true
	%ConnectButton.disabled = true
	%DeviceOptionButton.disabled = true

func _on_pointcloud_end_connecting():
	%OrbbecIPOptionButton.disabled = false
	%OrbbecFPSOptionButton.disabled = false
	%OrbbecResolutionOptionButton.disabled = false
	%HesaiIPLineEdit.editable = true
	%HesaiPortSpinBox.editable = true
	%DeviceOptionButton.disabled = false
	%ActiveSwitch.disabled = false
	%ConnectButton.disabled = false
	%DeviceOptionButton.disabled = false

func _on_timer_timeout() -> void:
	if camera.connecting:
		# animation la plus boboche du monde
		if %FPSLabel.text == "Connecting !":
			%FPSLabel.text = "Connecting !!"
		elif %FPSLabel.text == "Connecting !!":
			%FPSLabel.text = "Connecting !!!"
		else:
			%FPSLabel.text = "Connecting !"
		%FPSLabel.add_theme_color_override("font_color", fps_gradient.sample(0.5))
	else:
		var target_fps := 0.0
		if camera.current_device_type == camera.device_types.ORBBEC :
			target_fps = int(get_current_orbbec_fps())
		elif camera.current_device_type == camera.device_types.HESAI:
			# the hesai 40P lidars we have tested have a max framerate of 20fps.
			# TODO: find a way to get the real framerate of the lidar (doesn't look esay, even
			# (the sdk resorts to calculating the delta between a frame's first and last UDP
			# packet)
			target_fps = 20.0
		%FPSLabel.text = "%.1f/%s FPS" % [camera.current_fps, int(target_fps)]
		%FPSLabel.add_theme_color_override("font_color", fps_gradient.sample(camera.current_fps/target_fps))

func sort_ips(packed_ips):
	var ips: Array = Array(packed_ips)
	ips.sort_custom(func(a, b):
		var a_octets = a.split(".")
		var b_octets = b.split(".")

		# Compare each of the 4 octets numerically
		for i in range(4):
			var a_val = int(a_octets[i])
			var b_val = int(b_octets[i])
			if a_val != b_val:
				return a_val < b_val
		return false
	)
	return PackedStringArray(ips)

func get_current_device_type():
	var device_str = %DeviceOptionButton.get_item_text(%DeviceOptionButton.get_selected_id())
	return camera.device_str_to_enum(device_str)

func get_current_orbbec_ip():
	return %OrbbecIPOptionButton.get_item_text(%OrbbecIPOptionButton.get_selected_id())

func get_current_orbbec_fps():
	return %OrbbecFPSOptionButton.get_item_text(%OrbbecFPSOptionButton.get_selected_id())

func get_current_orbbec_resolution():
	return %OrbbecResolutionOptionButton.get_item_text(%OrbbecResolutionOptionButton.get_selected_id())

func set_orbbec_resolution_dropdown(resolutions):
	%OrbbecResolutionOptionButton.clear()
	for res in resolutions:
		%OrbbecResolutionOptionButton.add_item(res.split(" ")[0])
	# right now, index 1 is our default 512x512
	%OrbbecResolutionOptionButton.select(1)

func get_current_hesai_ip():
	return %HesaiIPLineEdit.text

## this function takes a list of available ips (ips that are not assigned to any cameras),
## adds the "None" option and the camera's currently selected IP to it
## and sets the options of the OrbbecIPOptionButton.
func update_orbbec_ip_dropdown(ips):
	var current_ip = get_current_orbbec_ip()
	if current_ip != "None":
		ips.append(current_ip)

	ips = sort_ips(ips)
	var idx = ips.find(current_ip) + 1

	%OrbbecIPOptionButton.clear()
	%OrbbecIPOptionButton.add_item("None")
	for ip in ips:
		%OrbbecIPOptionButton.add_item(ip)

	%OrbbecIPOptionButton.select(idx)

func start_orbbec_device():
	var ip = get_current_orbbec_ip()
	var resolution = get_resolution_from_text(get_current_orbbec_resolution())
	var fps = int(get_current_orbbec_fps())
	# index 0 is no device.
	if ip == "None" or active_state == false:
		camera.stop_device()
	else:
		camera.start_orbbec_device(ip, resolution[0], resolution[1], fps)

func start_hesai_device():
	if active_state == false or %HesaiPortSpinBox.value < 1024:
		camera.stop_device()
	else:
		camera.start_hesai_device(get_current_hesai_ip(), current_hesai_port)

func start_device():
	match camera.current_device_type:
		camera.device_types.ORBBEC:
			start_orbbec_device()
		camera.device_types.HESAI:
			start_hesai_device()

func find_index_of_item(ip: String, option_button) -> int:
	var idx := -1
	for i in range(option_button.item_count):
		if option_button.get_item_text(i) == ip:
			return i
	return idx

func set_hesai_ip(ip: String):
	%HesaiIPLineEdit.validate_no_signal(ip)
	current_hesai_ip = ip
	set_hesai_webui_url(ip)

func set_hesai_port(port: int):
	current_hesai_port = port
	%HesaiPortSpinBox.set_value_no_signal(port)

func select_orbbec_ip(ip: String):
	var idx = find_index_of_item(ip, %OrbbecIPOptionButton)
	if idx == -1:
		ToastManager.show_toast(camera.camera_name + " : " + "ip " + ip + " not found", "warning")
	else:
		%OrbbecIPOptionButton.select(idx)
		current_orbbec_ip_idx = idx

func select_orbbec_fps(fps: String):
	var idx = find_index_of_item(fps, %OrbbecFPSOptionButton)
	if idx == -1:
		ToastManager.show_toast(camera.camera_name + " : " + fps + "fps" + " not found", "warning")
	else:
		%OrbbecFPSOptionButton.select(idx)
		current_orbbec_ip_idx = idx

func select_orbbec_resolution(resolution: String):
	var idx = find_index_of_item(resolution, %OrbbecResolutionOptionButton)
	if idx == -1:
		print(resolution, " not found")
		ToastManager.show_toast(camera.camera_name + " : " + resolution + " not found", "warning")
	else:
		%OrbbecResolutionOptionButton.select(idx)
		current_orbbec_ip_idx = idx

func select_device_type(device_type):
	var device_str :String = camera.enum_to_device_str(device_type)
	var idx = find_index_of_item(device_str, %DeviceOptionButton)
	if idx == -1:
		print(device_str, " not found")
	else:
		%DeviceOptionButton.select(idx)
		current_device_type_idx = idx
	update_controls_for_device()

signal ip_option_selected()

func _on_ip_option_button_item_selected(index: int) -> void:
	var last_idx: int = current_orbbec_ip_idx

	UndoManager.add_to_stack(
		"start_device cam " + str(camera_num),
		func():
			%OrbbecIPOptionButton.select(index)
			self.current_orbbec_ip_idx = index
			start_device()
			ip_option_selected.emit(),
		func():
			%OrbbecIPOptionButton.select(last_idx)
			self.current_orbbec_ip_idx = last_idx
			start_device()
			ip_option_selected.emit(),
			true)


signal gizmo_requested(this_node)

func _on_gizmo_select_button_pressed() -> void:
	gizmo_requested.emit(self)
	focus_gizmo_button()

func _on_thinning_slider_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_thinning cam " + str(camera_num),
		value,
		camera.thinning,
		func(val): camera.thinning = val,
		func(val): %ThinningSlider.set_value_no_signal(val)
	)

func _on_name_change(cam_name:String):
	var caret_position = %CameraNameLineEdit.caret_column
	%CameraNameLineEdit.text = cam_name
	%CameraNameLineEdit.caret_column = caret_position

func _on_camera_name_line_edit_text_changed(new_name: String) -> void:
	var old_default_name_status = camera.has_default_name
	var old_name = camera.camera_name

	UndoManager.add_to_stack(
		"name change cam " + str(camera_num),
		func():
			# when we change name, we don't have the default name anymore. even
			# if its the same thing it was before.
			camera.set_camera_name(new_name, false),
		func():
			camera.set_camera_name(new_name)
			camera.set_camera_name(old_name, old_default_name_status),
		true,
		# makes it so we don't undo redo single characters.
		UndoRedo.MergeMode.MERGE_ENDS
	)

func get_resolution_from_text(resolution_text: String) -> PackedInt32Array:
	var numbers = resolution_text.split(" ")[0].split("x")
	return [int(numbers[0]),int(numbers[1])]

## not all fps options are valid for all resolutions
## target_fps is the fps that should be selected if it is available.
func update_orbbec_fps_options(resolution_text:String, target_fps):
	var res = get_resolution_from_text(resolution_text)
	var valid_fps = all_fps.duplicate()
	if res[0] == 1024:
		# 15 and 5 are the only valid fps for 1024 resolution
		valid_fps = valid_fps.slice(2)
	%OrbbecFPSOptionButton.clear()
	for fps in valid_fps:
		%OrbbecFPSOptionButton.add_item(fps)
	if int(target_fps) > 15 and len(valid_fps) == 2:
		current_orbbec_fps_idx = 0
	else:
		current_orbbec_fps_idx = find_index_of_item(target_fps, %OrbbecFPSOptionButton)
	%OrbbecFPSOptionButton.select(current_orbbec_fps_idx)

func _on_resolution_option_button_item_selected(index: int) -> void:
	var new_res = %OrbbecResolutionOptionButton.get_item_text(index)
	var last_res = %OrbbecResolutionOptionButton.get_item_text(current_orbbec_resolution_idx)
	var last_res_idx: int = current_orbbec_resolution_idx
	var target_fps = %OrbbecFPSOptionButton.get_item_text(current_orbbec_fps_idx)

	UndoManager.add_to_stack(
		"resolution change cam " + str(camera_num),
		func():
			update_orbbec_fps_options(new_res, target_fps)
			%OrbbecResolutionOptionButton.select(index)
			self.current_orbbec_resolution_idx = index
			start_device(),
		func():
			update_orbbec_fps_options(last_res, target_fps)
			%OrbbecResolutionOptionButton.select(last_res_idx)
			self.current_orbbec_resolution_idx = last_res_idx
			start_device()
	)

func focus_gizmo_button():
	%GizmoSelectButton.grab_focus()

func _on_fps_option_button_item_selected(index: int) -> void:
	var last_idx: int = current_orbbec_fps_idx
	UndoManager.add_to_stack(
		"start_device cam " + str(camera_num),
		func():
			%OrbbecFPSOptionButton.select(index)
			self.current_orbbec_fps_idx = index
			start_device(),
		func():
			%OrbbecFPSOptionButton.select(last_idx)
			self.current_orbbec_fps_idx = last_idx
			start_device()
	)

func _on_active_switch_toggled(toggled_on: bool) -> void:
	UndoManager.add_to_stack(
		"toggle active on" + str(camera_num),
		func():
			active_state = toggled_on
			start_device(),
		func():
			active_state = not toggled_on
			start_device()
	)

func _on_refresh_button_pressed() -> void:
	camera.stop_device()
	start_device()

var highlight_color:Color

func set_ui_elements_colors(col:Color):
	var color_fixed_alpha = Color(col)
	color_fixed_alpha.a = 1
	stylebox.bg_color = color_fixed_alpha
	# sets the color of the gizmo icon
	%GizmoSelectButton.icon.color_map = {Color(0,0,0): col}

var color: Color:
	set(col):
		color = col
		highlight_color = col.lightened(0.35)
		%ColorPickerButton.color = color
		set_ui_elements_colors(color)

var point_size: float = 1.0:
	set(pt_size):
		point_size = pt_size
		%PointSizeSlider.set_value_no_signal(point_size)

func set_color(col, stack_undo=true):
	var color_setter = func(colo):
		self.camera.color = colo
		self.color = colo
	if stack_undo:
		UndoManager.add_property_change_to_stack(
		"change_color cam " + str(camera_num),
		col,
		color,
		color_setter,
		func(val): %ColorPickerButton.color=val
	)
	else:
		color_setter.call(col)
		%ColorPickerButton.color = col

func _on_color_change(col):
	self.color = col

func _on_point_size_change(pt_size):
	self.point_size = pt_size

func _process(_delta):
	# update the rotation pivot radio buttons. The other alternative would be to make
	# the point cloud aware of the calibration options but I don't want to
	# do that.
	set_centroid_toggle(camera.centroid_toggled)

# all the functions touching the camera's transform are implicitly
# undo-redo-able because the point cloud itself manages changes to its transform
# property.
func _on_translate_x_value_changed(value: float) -> void:
	point_cloud.position[0] = value
	gizmo_requested.emit(self)

func _on_translate_y_value_changed(value: float) -> void:
	point_cloud.position[1] = value
	gizmo_requested.emit(self)

func _on_translate_z_value_changed(value: float) -> void:
	point_cloud.position[2] = value
	gizmo_requested.emit(self)

func _on_reset_translation_button_pressed() -> void:
	point_cloud.position = Vector3(0,0,0)
	%TranslateX.set_value_no_signal(0)
	%TranslateY.set_value_no_signal(0)
	%TranslateZ.set_value_no_signal(0)
	%ResetTranslationButton.visible = false

func _on_reset_rotation_button_pressed() -> void:
	point_cloud.rotation = Vector3(0,0,0)
	%RotateX.set_value_no_signal(0)
	%RotateY.set_value_no_signal(0)
	%RotateZ.set_value_no_signal(0)
	%ResetRotationButton.visible = false

func _on_color_picker_button_color_changed(col: Color) -> void:
	set_color(col)

func _on_rotate_x_value_changed(value: float) -> void:
	point_cloud.rotation[0] = deg_to_rad(value)
	gizmo_requested.emit(self)

func _on_rotate_y_value_changed(value: float) -> void:
	point_cloud.rotation[1] = deg_to_rad(value)
	gizmo_requested.emit(self)

func _on_rotate_z_value_changed(value: float) -> void:
	point_cloud.rotation[2] = deg_to_rad(value)
	gizmo_requested.emit(self)

func set_controls_to_transform(transform: Transform3D):
	set_controls_to_rot_pos(transform.basis.get_euler(), transform.origin)

func set_controls_to_rot_pos(rot, pos):
	%TranslateX.set_value_no_signal(pos[0])
	%TranslateY.set_value_no_signal(pos[1])
	%TranslateZ.set_value_no_signal(pos[2])
	%RotateX.set_value_no_signal(rad_to_deg(rot[0]))
	%RotateY.set_value_no_signal(rad_to_deg(rot[1]))
	%RotateZ.set_value_no_signal(rad_to_deg(rot[2]))

func _on_pt_cloud_transform_change(tform: Transform3D):
	%ResetTranslationButton.visible = tform.origin != Vector3.ZERO
	%ResetRotationButton.visible = tform.basis.get_euler() != Vector3.ZERO
	var rot = tform.basis.get_euler()
	set_controls_to_rot_pos(rot, tform.origin)

func set_centroid_toggle(toggled):
	if toggled:
		%PivotToCentroidButton.set_pressed_no_signal(true)
		%PivotToCameraButton.set_pressed_no_signal(false)
	else:
		%PivotToCameraButton.set_pressed_no_signal(true)
		%PivotToCentroidButton.set_pressed_no_signal(false)

func _on_centroid_change(_cent, toggled_on, _undoable):
	set_centroid_toggle(toggled_on)

func _on_centroid_button_pressed() -> void:
	camera.set_centroid_toggled(true)
	camera.request_new_centroid()

func _on_centroid_toggle_toggled(toggled_on: bool) -> void:
	camera.set_centroid_toggled(toggled_on)

func highlight():
	#set_ui_elements_colors(highlight_color)
	highlight_stylebox.bg_color.a = 1.0
	pass

func unhighlight():
	set_ui_elements_colors(color)
	highlight_stylebox.bg_color.a = 0.0
	pass

func _on_gizmo_select_button_mouse_entered() -> void:
	camera.highlight()

func _on_gizmo_select_button_mouse_exited() -> void:
	camera.unhighlight()

func update_controls_for_device():
	%FPSLabel.visible = true
	%OrbbecFPSLine.visible = false
	%OrbbecIPLine.visible = false
	%OrbbecResolutionLine.visible = false
	%HesaiIPLine.visible = false
	%HesaiWebUILine.visible = false
	%HesaiPortLine.visible = false
	match get_current_device_type():
		camera.device_types.ORBBEC:
			%OrbbecFPSLine.visible = true
			%OrbbecIPLine.visible = true
			%OrbbecResolutionLine.visible = true
		camera.device_types.HESAI:
			%HesaiIPLine.visible = true
			%HesaiPortLine.visible = true
			%HesaiWebUILine.visible = true
		_:
			# debug case
			%FPSLabel.visible = false

## this functions decides wether or not a device should be autostarted
func auto_start_device():
	match get_current_device_type():
		camera.device_types.ORBBEC:
			if get_current_orbbec_ip() != "None":
				start_device()
		camera.device_types.HESAI:
			if get_current_hesai_ip() != "":
				start_device()

func _on_device_option_button_item_selected(index: int) -> void:
	var last_idx = current_device_type_idx
	var old_device_type = camera.current_device_type
	var selected_type = camera.device_str_to_enum(%DeviceOptionButton.get_item_text(index))
	UndoManager.add_to_stack(
		"device type change cam " + str(camera_num),
		func():
			# when we change name, we don't have the default name anymore. even
			# if its the same thing it was before.
			camera.current_device_type = selected_type
			current_device_type_idx = index
			%DeviceOptionButton.select(index)
			update_controls_for_device()
			auto_start_device(),
		func():
			camera.current_device_type = old_device_type
			current_device_type_idx = last_idx
			%DeviceOptionButton.select(last_idx)
			update_controls_for_device()
			auto_start_device()
	)

signal delete_button_pressed

func _on_delete_button_pressed() -> void:
	delete_button_pressed.emit(camera_num)

func _on_pivot_to_centroid_button_toggled(toggled_on: bool) -> void:
	camera.set_centroid_toggled(toggled_on)

func set_hesai_webui_url(ip):
	if ip != "None":
		%HesaiWebUIButton.uri = "http://"+ip+"/setting.html"
		%HesaiWebUIButton.disabled = false
	else:
		%HesaiWebUIButton.disabled = true

func _on_hesai_ip_line_edit_valid_change(ip: String) -> void:
	var last_ip := current_hesai_ip
	UndoManager.add_to_stack(
		"start_device cam " + str(camera_num),
		func():
			set_hesai_ip(ip)
			start_device(),
		func():
			set_hesai_ip(last_ip)
			start_device()
	)

func _on_hesai_port_spin_box_value_changed(port: float) -> void:
	var last_port := current_hesai_port
	UndoManager.add_to_stack(
		"start_device cam " + str(camera_num),
		func():
			@warning_ignore("narrowing_conversion")
			set_hesai_port(port)
			start_device(),
		func():
			set_hesai_port(last_port)
			start_device()
	)

func _on_point_size_slider_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_point_size cam " + str(camera_num),
		value,
		point_size,
		func(val): camera.point_size = val,
		func(val): %PointSizeSlider.set_value_no_signal(val)
	)


func _on_display_button_toggled(toggled_on: bool) -> void:
	var old_val = displayed
	UndoManager.add_to_stack(
		"display cam " + str(camera_num),
		func():
			camera.displayed = toggled_on,
		func():
			camera.displayed = old_val
	)


func _on_solo_button_toggled(toggled_on: bool) -> void:
	var old_val = soloed
	UndoManager.add_to_stack(
		"display cam " + str(camera_num),
		func():
			camera.soloed = toggled_on,
		func():
			camera.soloed = old_val
	)
