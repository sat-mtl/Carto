extends Node3D
# don't know what the real practical max amount of points would be ...
# lets say 10 millions
var max_points := 10_000_000
var transform_buffer := PackedFloat32Array()
var floats_per_raw_point := 16
var material #: RID
var pmesh #: RID
var multimesh: RID
var multimesh_instance: RID
var multimesh_initialized = false

func init_multimesh_points():
	multimesh = RenderingServer.multimesh_create()
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.use_point_size = true
	material.point_size=1
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.5)

	pmesh = PointMesh.new()
	pmesh.material = material

	RenderingServer.multimesh_allocate_data(multimesh, max_points, RenderingServer.MULTIMESH_TRANSFORM_3D, true, false, true)
	RenderingServer.multimesh_set_mesh(multimesh, pmesh.get_rid())
	multimesh_instance = RenderingServer.instance_create2(multimesh, get_world_3d().scenario)
	#RenderingServer.instance_set_ignore_culling(multimesh_instance, true)
	#RenderingServer.instance_set_transform(multimesh_instance, global_transform)
	RenderingServer.instance_set_visible(multimesh_instance, true)
	RenderingServer.multimesh_set_visible_instances(multimesh, -1)
	RenderingServer.instance_set_custom_aabb(multimesh_instance, AABB( Vector3.ONE * -25000.0, Vector3.ONE * 25000.0))
	# this magic rendering layer value is the binary value that is set in the multimeshinstance3d of a device
	RenderingServer.instance_set_layer_mask(multimesh_instance, 0b11100000000000000000)


func _ready() -> void:
	init_multimesh_points()
	var mm_buffer = RenderingServer.multimesh_get_buffer_rd_rid(multimesh)
	ComputeShaderUtils.init_multimesh_buffer(mm_buffer, max_points, Vector3.ONE*-666.0, Color(1.0,1.0,1.0))
	init_compute_shader_buffers()
	multimesh_initialized = true
	ComputePipelinesManager.tracking_node = self

var rd := ComputeShaderUtils.rendering_device
var uniform_set: RID

# buffer of device address of cropped point clouds
var point_cloud_pointers_gpu_resources: Array
# buffer of device address of an int that gives each point cloud's size
var point_cloud_sizes_gpu_resources: Array
var multimesh_buffer_gpu_resources := [RDUniform.new(), null]
var output_size_gpu_resources: Array
var output_gpu_resources: Array
var multimesh_command_buffer_gpu_resources := [RDUniform.new(), null]
var max_output_size = 1_000_000

func init_compute_shader_buffers():
	var empty_floats = PackedFloat32Array()
	# we bind a RID to the uniform later
	multimesh_buffer_gpu_resources[0].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	multimesh_buffer_gpu_resources[0].binding = 2

	empty_floats.resize(1)
	output_size_gpu_resources = ComputeShaderUtils.make_buffer_uniform(empty_floats.to_byte_array(), 3)
	empty_floats.resize(max_output_size)
	output_gpu_resources = ComputeShaderUtils.make_buffer_uniform(empty_floats.to_byte_array(), 4)

	# we create a uniform with the multimesh command buffer (for later use of indirect dispatch)
	multimesh_command_buffer_gpu_resources[0].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	multimesh_command_buffer_gpu_resources[0].binding = 5

const floats_per_points := 3
const bytes_per_float := 4
## TODO : use indirect dispatch for the multimesh. Right now we unconditionally display 10 million points...

func update_compute_shader_buffers():
	if not multimesh_initialized:
		return
	if uniform_set.is_valid():
		# we need to cleanup our uniform set, there seems to be no way to update it
		# so we need to create one every frame and if we don't free we eventually crash
		rd.free_rid(uniform_set)
	# reset the point counter to 0
	rd.buffer_update(output_size_gpu_resources[1], 0, 4, PackedInt32Array([0]).to_byte_array())
	# binds the point cloud multimesh's buffer to the compute shader so that we can write exclusions
	# directly without a CPU download and a set_buffer to redraw.
	var multimesh_buffer_RID = RenderingServer.multimesh_get_buffer_rd_rid(multimesh)
	multimesh_buffer_gpu_resources[0].clear_ids()
	multimesh_buffer_gpu_resources[0].add_id(multimesh_buffer_RID)

	var multimesh_command_buffer_RID = RenderingServer.multimesh_get_command_buffer_rd_rid(multimesh)
	multimesh_command_buffer_gpu_resources[0].clear_ids()
	multimesh_command_buffer_gpu_resources[0].add_id(multimesh_command_buffer_RID)
	#rd.buffer_update(multimesh_command_buffer_RID, 0, 4*5, PackedInt32Array([1,10000,0,0,0]).to_byte_array())
	#multimesh_command_buffer_gpu_resources[0].add_id(output_gpu_resources[1])

func add_dispatch_to_compute_list(compute_list, filtered_points_gpu_resources, filtered_sizes_gpu_resources):
	if not multimesh_initialized:
		return
	uniform_set = rd.uniform_set_create([
		filtered_points_gpu_resources[0],
		filtered_sizes_gpu_resources[0],
		multimesh_buffer_gpu_resources[0],
		output_size_gpu_resources[0],
		output_gpu_resources[0],
		multimesh_command_buffer_gpu_resources[0],
		], ComputePipelinesManager.tracking_shader, 0
	) # the last parameter (the 0) needs to match the "set" in our shader file
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# vulkan (??) does not support non-buffer uniforms for compute shaders (???)
	# so we have to use push_constant. Note: This is not a PackedInt32Array because
	# we may eventually want to introduce types that do not fit in 4 bytes in there.
	var parameters := PackedInt32Array()
	# number of point cloud buffers
	parameters.append(CameraManager.num_cameras)
	# max number of displayed points
	parameters.append(max_points)
	var parameter_bytes := parameters.to_byte_array()
	#parameter_bytes.resize(parameters.size())
	rd.compute_list_set_push_constant(compute_list, parameter_bytes, 8)
	# we need to be called for max_points because we need to clear unused points.
	var xyz_invoc = ComputeShaderUtils.get_xyz_invocations(max_points)
	# TODO: use indirect dispatch here.
	rd.compute_list_dispatch(compute_list, xyz_invoc.x, xyz_invoc.y, xyz_invoc.z)

func read_from_command_buffer():
	pass
	#print(rd.buffer_get_data(RenderingServer.multimesh_get_command_buffer_rd_rid(multimesh), 0, 5*4).to_int32_array())
	#print(rd.buffer_get_data(RenderingServer.multimesh_get_buffer_rd_rid(multimesh), 0, 16*4).to_float32_array())
