extends Node

var rd = ComputeShaderUtils.rendering_device
# this global node manages all the compute pipelines, from point cloud
# acquisition, filtering, (compaction later maybe) to all steps of tracking.

# this variable contains a buffer and a unifor. the buffer contains all the points after cropping, thinning and any other kind
# of filters well think of in the future. It needs to be as long as 1024*1024*3 floats
# times the max device id created (even if you create 25 devices and delete all on them
# except one. the function to get the network point is called with a delay and the memory
# location of points needs to be stable between calls.

# the uniform contains filtered_points_buffer. It is also the sole uniform in
# common between the filter stage and the tracking stage. It needs to be shared
# and not just passed by buffer_device_address because otherwise godot's resource
# tracking algorithm is not going to see the dependency and can reorder the call
# which will result in crashes.
var filtered_points_gpu_resources: Array
const floats_per_filtered_point := 3
var tracking_node = null
# contains current valid sizes for every camera in points. This is preallocated
# to max_cam_num because a 100 uint buffer is not that big anyways.
var filtered_sizes_gpu_resources: Array
var filter_shader_file := load("res://shaders/point_cloud_filter.glsl")
var filter_shader_spirv: RDShaderSPIRV = filter_shader_file.get_spirv()
var filter_shader := rd.shader_create_from_spirv(filter_shader_spirv)
var filter_pipeline := rd.compute_pipeline_create(filter_shader)

var tracking_shader_file := load("res://shaders/dummy_tracking_shader.glsl")
var tracking_shader_spirv: RDShaderSPIRV = tracking_shader_file.get_spirv()
var tracking_shader := rd.shader_create_from_spirv(tracking_shader_spirv)
var tracking_pipeline := rd.compute_pipeline_create(tracking_shader)

func _init():
	var empty_floats = PackedFloat32Array()
	empty_floats.resize(1024*1024*3)
	# make a buffer big enough to accomodate one device
	filtered_points_gpu_resources = ComputeShaderUtils.make_buffer_uniform(empty_floats.to_byte_array(), 0)
	empty_floats.resize(CameraManager.max_cam_num)
	filtered_sizes_gpu_resources = ComputeShaderUtils.make_buffer_uniform(empty_floats.to_byte_array(), 1)
## this needs to be called everytime a new device is added.
## TODO: maybe prevent a compute shader call when this happens to make
## sure nothing breaks.
func reallocate_filtered_points_buffer():
	var size = CameraManager.get_total_max_points() * floats_per_filtered_point
	var empty_floats = PackedFloat32Array()
	empty_floats.resize(size)
	var bytes = empty_floats.to_byte_array()
	filtered_points_gpu_resources[1] = ComputeShaderUtils.create_buffer_with_device_address(bytes.size(), bytes)
	ComputeShaderUtils.rendering_device.free_rid(filtered_points_gpu_resources[1])

func build_and_call_compute_shaders():
	if CameraManager.num_cameras == 0:
		return
	# updating buffers is illegal when a compute list is open so we first ask
	# every device to update their stuff
	for cam in CameraManager.nodes:
		cam["camera"].update_compute_shader_buffers()
	if tracking_node:
		tracking_node.update_compute_shader_buffers()
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, filter_pipeline)
	# then we ask every device to add their dispatch to the compute list
	# we pass them the filtered point buffers so they can declare it in their
	# uniform set.
	for cam in CameraManager.nodes:
		cam["camera"].add_dispatch_to_compute_list(compute_list, filtered_points_gpu_resources, filtered_sizes_gpu_resources)
		cam["camera"].should_draw = false
	# barrier + tracking step
	## TODO: use indirect dispatch for this step since we know how many points
	## are going to be processed and we don't have to process all the hypothetical
	## ones
	# add a barrier to make sure that the filter shaders are all run before the
	# tracking shader. Note: add barrier only does compute_list_end() compute_list_begin()
	# and the RenderingServer is responsible to track dependencies between compute lists.
	# If no dependencies are detected, the RenderingServer may reorder stuff. This is
	# why we need a common uniform between the filter compute shaders and the tracking compute shader.
	rd.compute_list_add_barrier(compute_list)
	rd.compute_list_bind_compute_pipeline(compute_list, tracking_pipeline)
	if tracking_node:
		tracking_node.add_dispatch_to_compute_list(compute_list, filtered_points_gpu_resources, filtered_sizes_gpu_resources)
	rd.compute_list_end()
	# if we have no active network ouput, we can skip reading from the GPU which is muuuuch
	# faster than having to read from it.
	if len(get_tree().get_nodes_in_group("network_outputs").filter(func(out): return out.is_active)) > 0:
		# TODO: not sure how this will work out now that we dispatch multiple compute lists.
		for cam in CameraManager.nodes:
			cam["camera"].set_network_output_data()
	var sizes := rd.buffer_get_data(filtered_sizes_gpu_resources[1], 0, 8).to_int32_array()
	print(sizes)

var process = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_B:
		ToastManager.show_toast(str(not process), "info")
		process = not process

func _process(_delta: float) -> void:
	if process:
		build_and_call_compute_shaders()
