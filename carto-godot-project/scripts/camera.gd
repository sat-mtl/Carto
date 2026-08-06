## This represents the characterist
extends Node

enum device_types {DEBUG=0, ORBBEC=1, HESAI=2}
func device_str_to_enum(device_str:String):
	device_str = device_str.to_lower()
	match device_str:
		"orbbec":
			return device_types.ORBBEC
		"hesai":
			return device_types.HESAI
		_:
			return device_types.DEBUG

func enum_to_device_str(device_enum) -> String:
	match device_enum:
		device_types.ORBBEC:
			return "Orbbec"
		device_types.HESAI:
			return "Hesai"
		_:
			return "Debug"

var current_device_type = device_types.ORBBEC:
	set(type):
		stop_device()
		current_device_type = type
		# reset the centroid state between different devices.
		has_centroid = false
		# auto "start" the debug device.
		if current_device_type == device_types.DEBUG:
			start_debug_device()
var orbbec_device = OrbbecPointCloudGPU.new()
var hesai_device = HesaiPointCloudGPU.new()
var output_data: PackedByteArray
var has_new_output_data = false
var device_stopped = false
var should_draw = true
var multimesh := MultiMesh.new()
var active = true
## true if the user hasn't changed the name yet (still Camera X)
var has_default_name = true
var camera_name: String

signal soloed_change(state)
var soloed: bool = false:
	set(is_it):
		soloed = is_it
		soloed_change.emit(soloed)
		CameraManager.update_solo(soloed, device_num)

signal displayed_change(state)
var displayed: bool = true:
	set(is_it):
		displayed = is_it
		displayed_change.emit(displayed)
		# since the display state of a device's point cloud depends on the solo
		# state of all of the other cameras, we need to pass through the
		# CameraManager to determine wether the point cloud needs to be displayed.
		CameraManager.update_point_visibility(device_num)

static var debug_points := PackedVector3Array()
static var transform_buffer: PackedFloat32Array
static var max_transform_points = 1024*1024
const floats_per_raw_point = 12

static func setup_debug_pt_cloud(size, spread):
	debug_points = PackedVector3Array()
	for i in range(size):
		for j in range(size):
			for k in range(size):
				var x = i/float(size) * spread * (1 + randf()/10)
				var y = j/float(size) * spread * (1 + randf()/10)
				var z = k/float(size) * spread * (1 + randf()/10)
				var vec = Vector3(x,y,z)
				debug_points.append(vec)

static func _static_init():
	setup_debug_pt_cloud(100,3.5)
	var basis :=  Basis()
	transform_buffer.resize(max_transform_points*floats_per_raw_point)
	for i in range(max_transform_points):
		transform_buffer[i * floats_per_raw_point] = basis[0][0];
		transform_buffer[i * floats_per_raw_point + 1] = basis[1][0];
		transform_buffer[i * floats_per_raw_point + 2] = basis[2][0];
		transform_buffer[i * floats_per_raw_point + 3] = 0;
		transform_buffer[i * floats_per_raw_point + 4] = basis[0][1];
		transform_buffer[i * floats_per_raw_point + 5] = basis[1][1];
		transform_buffer[i * floats_per_raw_point + 6] = basis[2][1];
		transform_buffer[i * floats_per_raw_point + 7] = 0;
		transform_buffer[i * floats_per_raw_point + 8] = basis[0][2];
		transform_buffer[i * floats_per_raw_point + 9] = basis[1][2];
		transform_buffer[i * floats_per_raw_point + 10] = basis[2][2];
		transform_buffer[i * floats_per_raw_point + 11] = 0;

signal color_changed(color)
var color: Color:
	set(col):
		color = col
		color_changed.emit(col)

signal point_size_changed(pt_size)
var point_size: float:
	set(pt_size):
		point_size = pt_size
		point_size_changed.emit(pt_size)

func get_camera_color(idx):
	var color_num = idx - 1
	## returns a unique camera color for the camera number.
	## should return somewhat distinguishable colors until +- 30 cameras.
	## will return saturated white at some point.
	var lightness_add:float = floor(color_num/10.0)/12.5
	var hue:float = color_num / 10.0
	var col = Color.from_ok_hsl(hue, 1.0, 0.6 + lightness_add)
	col.a = 0.34
	return col

var thinning: float = 0.0
var transform := Transform3D()
var last_transform: Transform3D

func _on_display_transform_changed(tform: Transform3D):
	transform = tform

# max 1024x1024 points.
var max_points := 1_048_576

func _enter_tree() -> void:
	setup_points_for_compute_shader()
	init_compute_shader_buffers()

func _exit_tree() -> void:
	free_compute_shader_buffers()

func log_warn(lg):
	ToastManager.show_toast(enum_to_device_str(current_device_type) + " " + camera_name + ": " + lg, "warning")

func log_error(lg:String):
	ToastManager.show_toast(enum_to_device_str(current_device_type) + " " + camera_name + ": " + lg, "error")

func log_success(lg:String):
	LogManager.add_to_log(enum_to_device_str(current_device_type) + " " + camera_name + ": " + lg, LogManager.log_level.SUCCESS)

func _on_device_warning_log(lg:String):
	call_deferred("log_warn", lg)

func _on_device_error_log(lg:String):
	call_deferred("log_error", lg)

func _on_device_success_log(lg:String):
	call_deferred("log_success", lg)

var device_num
var ui_node
var display_node
func connect_device_log_signals(device_node):
	device_node.warning_log.connect(_on_device_warning_log)
	device_node.error_log.connect(_on_device_error_log)
	device_node.success_log.connect(_on_device_success_log)

func _init(ui:Node, display:Node, num:int) -> void:
	device_num = num
	ui_node = ui
	display_node = display
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	color_changed.connect(display_node._on_color_change)
	color_changed.connect(ui._on_color_change)
	point_size_changed.connect(display_node._on_point_size_change)
	point_size_changed.connect(ui._on_point_size_change)
	soloed_change.connect(ui._on_soloed_changed)
	centroid_changed.connect(display_node._on_centroid_change)
	centroid_changed.connect(ui._on_centroid_change)
	displayed_change.connect(display_node._on_displayed_change)
	displayed_change.connect(ui._on_displayed_change)
	name_changed.connect(ui._on_name_change)
	name_changed.connect(display_node._on_name_change)
	display_node.transform_changed.connect(_on_display_transform_changed)
	display_node.init_multimesh_instance(multimesh)
	orbbec_device.set_rendering_device(rd)
	connect_device_log_signals(orbbec_device)
	orbbec_device.point_cloud_frame.connect(_on_device_point_frame)
	hesai_device.set_rendering_device(rd)
	connect_device_log_signals(hesai_device)
	hesai_device.point_cloud_frame.connect(_on_device_point_frame)
	setup_points_for_compute_shader()
	set_camera_name("Camera " + str(num), true)
	color = get_camera_color(num)

signal name_changed

## tells the camera to stay highlighted
var gizmo_selected := false:
	set(selected):
		gizmo_selected = selected
		if selected:
			highlight()
		else:
			unhighlight()

func highlight():
	display_node.highlight()
	ui_node.highlight()

func unhighlight():
	# does the check here so that a children can call unhighlight() as a request to
	# unhighlight and then this gets the last say.
	if not gizmo_selected:
		display_node.unhighlight()
		ui_node.unhighlight()

func set_camera_name(cam_name:String, is_default:=false):
	camera_name = cam_name
	has_default_name = is_default
	name_changed.emit(camera_name)

func get_stream_formats():
	return orbbec_device.get_device_stream_formats()

# compute shader section
var rd = RenderingServer.get_rendering_device()

var shader_file := load("res://shaders/point_cloud_filter.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)
# array of points that need to be computed for filter inclusions or exclusions
var pipeline := rd.compute_pipeline_create(shader)

# creates the necessary gpu resources needed to pass a byte buffer to a compute
# shader. returns an array of [RDUniform, RID to a storage buffer].
# You really need to call rd.free_rid(the_array_returned_by_this_function[1])
# in order to free the resources on the GPU.
func make_buffer_uniform(data_bytes:PackedByteArray, binding):
	var data_storage_buffer := rd.storage_buffer_create(data_bytes.size(), data_bytes)
	var data_uniform := RDUniform.new()
	data_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	data_uniform.binding = binding
	data_uniform.add_id(data_storage_buffer)
	return [data_uniform, data_storage_buffer]

var mock_buffer_rid: RID
var point_cloud_buffer_rid: RID
var point_cloud_buffer_gpu_resources:= [RDUniform.new(), null]
var filter_transforms_gpu_resources: Array
var filter_settings_gpu_resources: Array
var multimesh_buffer_gpu_resources:= [RDUniform.new(), null]
var valid_points_counter_gpu_resources: Array
var network_output_gpu_resources: Array
var thinning_mask_gpu_resources: Array

const max_filters_num := 100
const transforms_num_fields := 12
const filter_settings_num_fields := 2
const floats_per_points := 3
const bytes_per_float := 4

func free_compute_shader_buffers():
	rd.free_rid(filter_transforms_gpu_resources[1])
	rd.free_rid(filter_settings_gpu_resources[1])
	rd.free_rid(valid_points_counter_gpu_resources[1])
	rd.free_rid(mock_buffer_rid)
	rd.free_rid(network_output_gpu_resources[1])
	rd.free_rid(thinning_mask_gpu_resources[1])
	mock_buffer_rid = RID()

const thinning_mask_size := 100_000

# We don't dynamically resize this buffer. I think its fine if its always at the maximum
# allowable size.
const max_network_size := 1024*1024*floats_per_points*bytes_per_float

func init_compute_shader_buffers():
	var empty_floats = PackedFloat32Array()
	empty_floats.resize(max_filters_num * transforms_num_fields)
	filter_transforms_gpu_resources = make_buffer_uniform(empty_floats.to_byte_array(), 0)
	empty_floats.resize(max_filters_num * filter_settings_num_fields)
	filter_settings_gpu_resources = make_buffer_uniform(empty_floats.to_byte_array(), 1)
	empty_floats.resize(1)
	point_cloud_buffer_gpu_resources[0].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	point_cloud_buffer_gpu_resources[0].binding = 2
	# we bind a RID to the uniform later
	multimesh_buffer_gpu_resources[0].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	multimesh_buffer_gpu_resources[0].binding = 3
	valid_points_counter_gpu_resources = make_buffer_uniform(empty_floats.to_byte_array(), 4)
	empty_floats.resize(max_network_size)
	network_output_gpu_resources = make_buffer_uniform(empty_floats.to_byte_array(), 5)
	# create a thinning mask with random floats from 0 to 1.
	empty_floats.resize(thinning_mask_size)
	for i in range(thinning_mask_size):
		empty_floats[i] = randf()
	thinning_mask_gpu_resources = make_buffer_uniform(empty_floats.to_byte_array(), 6)
	upload_mock_data()

# flattens the transform and appends it to the array.
# all work is done as side effect.
func append_transform_to_float_array(tfm:Transform3D, array:PackedFloat32Array):
	array.append(tfm.basis.x.x)
	array.append(tfm.basis.x.y)
	array.append(tfm.basis.x.z)
	array.append(tfm.basis.y.x)
	array.append(tfm.basis.y.y)
	array.append(tfm.basis.y.z)
	array.append(tfm.basis.z.x)
	array.append(tfm.basis.z.y)
	array.append(tfm.basis.z.z)
	for i in range(3):
		array.append(tfm.origin[i])

func get_xyz_invocations(required_invocations:int) -> Vector3:
	# number of workgroups in X,Y,Z.
	# Algorithm adapted from https://github.com/ossia/score/blob/master/src/plugins/score-plugin-gfx/Gfx/Graph/RenderedCSFNode.cpp#L1372
	# to compute the right size for the workgroup dimensions.
	const threads_per_workgroup:= 64
	# example : if we have 65 invocations, we need 2 workgroups. (65 + 63)/64 == 2
	@warning_ignore("integer_division")
	var total_workgroups := (required_invocations + threads_per_workgroup - 1) / threads_per_workgroup;
	const max_workgroups := 65535
	var dispatch = Vector3.ZERO
	# the logic of those steps is that everytime we overflow max_workgroups on one dimension,
	if(total_workgroups > max_workgroups * max_workgroups):
		dispatch.x = max_workgroups;
		@warning_ignore("integer_division")
		var remaining := (total_workgroups + max_workgroups - 1) / max_workgroups;
		dispatch.y = min(remaining, max_workgroups);
		@warning_ignore("integer_division")
		dispatch.z = (remaining + (max_workgroups - 1)) / max_workgroups;
	elif(total_workgroups > max_workgroups):
		dispatch.x = min(total_workgroups, max_workgroups);
		@warning_ignore("integer_division")
		dispatch.y = (total_workgroups + max_workgroups - 1) / max_workgroups;
		dispatch.z = 1;
	else:
		dispatch.x = total_workgroups;
		dispatch.y = 1;
		dispatch.z = 1;
	return dispatch

func clear_network_output():
	output_data.clear()
	has_new_output_data = true

func on_data_got(dat):
	if active:
		output_data = dat
		has_new_output_data = true

func set_network_output_data():
	var num_points := rd.buffer_get_data(valid_points_counter_gpu_resources[1], 0, 4).decode_u32(0)
	var output_size := num_points * bytes_per_float * floats_per_points
	# This buffer_get_data command waits for the gpu to finish computing.
	if num_points == 0:
		clear_network_output()
		return
	# TODO: maybe try buffer_get_data_async ? it introduces latency though.
	rd.buffer_get_data_async(network_output_gpu_resources[1], on_data_got, 0, output_size)

var uniform_set: RID

func apply_compute_shader():
	if uniform_set.is_valid():
		# we need to cleanup our uniform set, there seems to be no way to update it
		# so we need to create one every frame and if we don't free we eventually crash
		rd.free_rid(uniform_set)
	if current_device_type != device_types.DEBUG and not point_cloud_buffer_rid.is_valid():
		return
	var filter_settings := PackedInt32Array()
	# the format of this buffer is [
	#     <9 float components of filter 1 basis>,
	#     <3 flot components of filter 1 origin>, ...
	# ]
	var filter_transforms := PackedFloat32Array()
	var filters := get_tree().get_nodes_in_group("filter_areas")
	for filter in filters:
		filter_settings.append(filter.filter_shape)
		if filter.filter_active:
			filter_settings.append(filter.filter_mode)
		else:
			# TODO: make the filter settings enum accessible here.
			# sets the filter mode to inactive.
			filter_settings.append(2)
		# we need to adjust the transform to match the shapes described by the SDFs to
		# godot's collision shapes.
		var filter_transform = filter.transform.scaled(Vector3.ONE*0.5)
		filter_transform.origin = filter_transform.origin*Vector3.ONE*2
		# we inverse the transformation matrix here so that we don't have to do it
		# once per point on the gpu
		append_transform_to_float_array(filter_transform.affine_inverse(), filter_transforms)
	# upload our various buffers on the gpu.
	var filter_transform_bytes = filter_transforms.to_byte_array()
	rd.buffer_update(filter_transforms_gpu_resources[1], 0, len(filter_transform_bytes), filter_transform_bytes)
	var filter_settings_bytes = filter_settings.to_byte_array()
	rd.buffer_update(filter_settings_gpu_resources[1], 0, len(filter_settings_bytes), filter_settings_bytes)
	# reset the point counter to 0
	rd.buffer_update(valid_points_counter_gpu_resources[1], 0, 4, PackedInt32Array([0]).to_byte_array())
	# binds the point cloud multimesh's buffer to the compute shader so that we can write exclusions
	# directly without a CPU download and a set_buffer to redraw.
	var multimesh_buffer_RID = RenderingServer.multimesh_get_buffer_rd_rid(multimesh)
	multimesh_buffer_gpu_resources[0].clear_ids()
	multimesh_buffer_gpu_resources[0].add_id(multimesh_buffer_RID)

	point_cloud_buffer_gpu_resources[0].clear_ids()
	if current_device_type != device_types.DEBUG:
		point_cloud_buffer_gpu_resources[0].add_id(point_cloud_buffer_rid)
	else:
		point_cloud_buffer_gpu_resources[0].add_id(mock_buffer_rid)
	uniform_set = rd.uniform_set_create([
		point_cloud_buffer_gpu_resources[0],
		filter_settings_gpu_resources[0],
		filter_transforms_gpu_resources[0],
		multimesh_buffer_gpu_resources[0],
		valid_points_counter_gpu_resources[0],
		network_output_gpu_resources[0],
		thinning_mask_gpu_resources[0],
		], shader, 0
	) # the last parameter (the 0) needs to match the "set" in our shader file
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# vulkan (??) does not support non-buffer uniforms for compute shaders (???)
	# so we have to use push_constant. Note: This is not a PackedInt32Array because
	# we may eventually want to introduce types that do not fit in 4 bytes in there.
	var parameters := PackedInt32Array()
	# number of floats in the point clouds points buffer
	parameters.append(max_points*floats_per_points)
	# number of filters the shader will process
	parameters.append(filters.size())
	# number of fields per transform in the transforms buffers (for both point cloud
	# and filter transform buffers)
	parameters.append(transforms_num_fields)
	# number of fields per filter in the filter settings buffer
	parameters.append(filter_settings_num_fields)
	# max number of points in the multimesh buffer
	parameters.append(max_points)
	# pass the current device type to be able to pre-process differently depending on the
	# source.
	parameters.append(current_device_type)
	parameters.append(thinning_mask_size)
	# I'm so sorry. (what I really want is a reinterpret_cast)
	var float_params = parameters.to_byte_array().to_float32_array()
	float_params.append(thinning)
	# Append the centroid compensated transform of this point cloud to the push constants.
	append_transform_to_float_array(get_transform_centroid_compensated(), float_params)
	# This always need to be more than 16 bytes even if you use less. It also can't
	# contain more than 128 bytes or something like that so we can't just shove
	# everything in there. It also looks like this buffer needs to have a multiple
	# of 16 bytes.
	var parameter_bytes := float_params.to_byte_array()
	# just use the whole 128 bytes, whatever.
	parameter_bytes.resize(80)
	rd.compute_list_set_push_constant(compute_list, parameter_bytes, parameter_bytes.size())
	@warning_ignore("integer_division")
	# we need to be called for max_points because we need to clear unused points.
	var xyz_invoc = get_xyz_invocations(max_points)
	rd.compute_list_dispatch(compute_list, xyz_invoc.x, xyz_invoc.y, xyz_invoc.z)
	rd.compute_list_end()
	# if we have no active network ouput, we can skip reading from the GPU which is muuuuch
	# faster than having to read from it.
	if len(get_tree().get_nodes_in_group("network_outputs").filter(func(out): return out.is_active)) > 0:
		set_network_output_data()

# end compute shader section

const fps_array_length = 30
var frame_times := Array()
var current_fps = 0:
	get():
		if len(frame_times) <= 1:
			return 0
		else:
			return len(frame_times)/(Time.get_unix_time_from_system() - frame_times[0])

func update_fps_array():
	if len(frame_times) >= fps_array_length:
		frame_times.pop_front()
	frame_times.push_back(Time.get_unix_time_from_system())

var has_centroid = false

func request_new_centroid():
	has_centroid = false

var centroid_toggled := true

func set_centroid_toggled(toggled):
	centroid_toggled = toggled
	centroid_changed.emit(centroid, centroid_toggled, true)

func set_centroid_state_in_ui_node(toggled):
	centroid_toggled = toggled
	ui_node.set_centroid_toggle(toggled)

func pre_process_hesai_bytes(hesai_bytes:PackedByteArray) -> PackedVector3Array:
	var processed_bytes := PackedVector3Array()
	for point in hesai_bytes.to_vector3_array():
		var x := -point.y
		var y := point.z
		var z := -point.x
		point.x = x
		point.y = y
		point.z = z
		processed_bytes.append(point)
	return processed_bytes

func pre_process_orbbec_bytes(orbbec_bytes:PackedByteArray) -> PackedVector3Array:
	var processed_bytes := PackedVector3Array()
	for point in orbbec_bytes.to_vector3_array():
		if point.z > 1e-6:
			point.y = -point.y
			point.x = -point.x
			processed_bytes.append(point/1000.0)
	return processed_bytes

var centroid = Vector3(0,0,0)

func calculate_centroid(pts):
	var sum: Vector3 = Vector3.ZERO
	for point:Vector3 in pts:
		sum+=point
	centroid = sum / len(pts)

signal centroid_changed

func get_transform_centroid_compensated():
	if centroid_toggled:
		return transform*(Transform3D(Basis(), -centroid))
	else:
		return transform

func _on_device_point_frame(point_cloud_buffer: RID, point_cloud_bytes: PackedByteArray) -> void:
	if device_stopped:
		# don't accept new events if we have already closed the device
		return
	if point_cloud_bytes.size() == 0:
		return
	update_fps_array()
	if !has_centroid:
		# only do something with the bytes if we need a centroid.
		var processed_points: PackedVector3Array
		if current_device_type == device_types.ORBBEC:
			processed_points = pre_process_orbbec_bytes(point_cloud_bytes)
		elif current_device_type == device_types.HESAI:
			processed_points = pre_process_hesai_bytes(point_cloud_bytes)
		calculate_centroid(processed_points)
		centroid_changed.emit(centroid, centroid_toggled, false)
		has_centroid = true
	point_cloud_buffer_rid = point_cloud_buffer
	should_draw = true

func setup_points_for_compute_shader():
	multimesh.instance_count = max_points
	multimesh.buffer = transform_buffer.slice(0, max_points*floats_per_raw_point)

var last_ip = "None"
var last_port = 0
var last_xres = null

var connecting = false

signal is_connecting
signal end_connecting

func emit(sig):
	sig.emit()

# TODO: refactor this chunk, theres a bunch of common code.
func _start_orbbec_device(ip, xres, yres, fps):
	# we need to call_deferred the signals because we are not in the same thread.
	call_deferred("emit", is_connecting)
	UndoManager.disable("Waiting for a camera to connect")
	connecting = true
	orbbec_device.set_device_from_ip(ip)
	orbbec_device.start_stream(xres, yres, fps)
	device_stopped = false
	connecting = false
	UndoManager.enable()
	call_deferred("emit", end_connecting)

func start_orbbec_device(ip, xres, yres, fps):
	max_points = xres*yres
	if multimesh.instance_count != max_points:
		setup_points_for_compute_shader()
	if (last_ip != ip or last_xres != xres) and not has_centroid:
		last_ip = ip
		last_xres = xres
		has_centroid = false
		centroid = Vector3.ZERO
	WorkerThreadPool.add_task(func():self._start_orbbec_device(ip, xres, yres, fps))

func _start_hesai_device(ip):
	call_deferred("emit", is_connecting)
	UndoManager.disable("Waiting for a camera to connect")
	connecting = true
	hesai_device.start_stream(ip)
	device_stopped = false
	connecting = false
	UndoManager.enable()
	call_deferred("emit", end_connecting)

func start_hesai_device(ip, port):
	max_points = hesai_device.get_max_points()
	if multimesh.instance_count != max_points:
		setup_points_for_compute_shader()
	if (last_ip != ip or last_port != port) and not has_centroid:
		last_ip = ip
		last_port = port
		has_centroid = false
		centroid = Vector3.ZERO
	hesai_device.correction_file_path = CameraManager.hesai_pandar_p40_correction_tmp_file.get_path_absolute()
	hesai_device.udp_port = port
	WorkerThreadPool.add_task(func():self._start_hesai_device(ip))

func start_debug_device():
	max_points = len(debug_points)
	setup_points_for_compute_shader()

func stop_device():
	# consider the device closed
	device_stopped = true
	# reset fps counter
	frame_times.resize(0)
	if current_device_type == device_types.ORBBEC:
	# close the pipeline
		orbbec_device.stop_stream()
	elif current_device_type == device_types.HESAI:
		hesai_device.stop_stream()
	multimesh.instance_count = 0
	clear_network_output()
	should_draw = true

func set_device_from_ip(ip):
	orbbec_device.set_device_from_ip(ip)

func upload_mock_data(data_bytes=null):
	if data_bytes == null:
		data_bytes = debug_points.to_byte_array()
	if not mock_buffer_rid.is_valid():
		mock_buffer_rid = rd.storage_buffer_create(data_bytes.size(), data_bytes)
	rd.buffer_update(mock_buffer_rid, 0, len(data_bytes), data_bytes)

func _process(_delta: float) -> void:
	var transformed_has_changed = transform != last_transform
	if current_device_type == device_types.DEBUG:
		var data_bytes = debug_points.to_byte_array()
		upload_mock_data(data_bytes)
		should_draw = true
		if !has_centroid:
			calculate_centroid(debug_points)
			centroid_changed.emit(centroid, centroid_toggled, false)
		has_centroid = true
	if active and (should_draw or transformed_has_changed):
		apply_compute_shader()
	last_transform = transform
	should_draw = false
