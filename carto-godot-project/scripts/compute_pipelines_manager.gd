extends Node
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
	ComputeShaderUtils.rendering_device.free_rid(filtered_points_gpu_resources[1])
	var size = CameraManager.get_total_max_points() * floats_per_filtered_point
	var empty_floats = PackedFloat32Array()
	empty_floats.resize(size)
	ComputeShaderUtils.create_buffer_with_device_address(size, empty_floats.to_byte_array())

var rd = ComputeShaderUtils.rendering_device

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
	# then we ask every device to add their dispatch to the compute list
	# we pass them the filtered point buffer so they can declare it in their
	# uniform set.
	for cam in CameraManager.nodes:
		cam["camera"].add_dispatch_to_compute_list(compute_list, filtered_points_gpu_resources, filtered_sizes_gpu_resources)

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
	if tracking_node:
		tracking_node.add_dispatch_to_compute_list(compute_list, filtered_points_gpu_resources, filtered_sizes_gpu_resources)
	rd.compute_list_end()
