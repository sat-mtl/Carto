extends MultiMeshInstance3D
# don't know what the real practical max amount of points would be ...
# lets say 10 millions
var max_points := 10_000_000
# RenderingServer.multimesh_get_buffer_rd_rid(multimesh)
var transform_buffer := PackedFloat32Array()
var floats_per_raw_point := 16
var material = StandardMaterial3D.new()
var pmesh := PointMesh.new()

var multimesh_initialized = false

func init_multimesh_points():
	# initialize an empty point buffer with color. See https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-multimesh-set-buffer
	transform_buffer.resize(max_points*floats_per_raw_point)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = max_points
	multimesh.buffer = transform_buffer.slice(0, max_points*floats_per_raw_point)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.use_point_size = true
	material.point_size=1
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.5)
	pmesh.material=material
	multimesh.mesh=pmesh

func _init() -> void:
	init_multimesh_points()
	var mm_buffer = RenderingServer.multimesh_get_buffer_rd_rid(multimesh)
	ComputeShaderUtils.init_multimesh_buffer(mm_buffer, max_points, Vector3.ONE*-666.0, Color(1.0,1.0,1.0))
	init_compute_shader_buffers()
	multimesh_initialized = true

var rd := ComputeShaderUtils.rendering_device
var uniform_set: RID

# buffer of device address of cropped point clouds
var point_cloud_pointers_gpu_resources: Array
# buffer of device address of an int that gives each point cloud's size
var point_cloud_sizes_gpu_resources: Array
var multimesh_buffer_gpu_resources := [RDUniform.new(), null]
var output_size_gpu_resources: Array
var output_gpu_resources: Array
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

var shader_file := load("res://shaders/dummy_tracking_shader.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)
var pipeline := rd.compute_pipeline_create(shader)

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

func add_dispatch_to_compute_list(compute_list, filtered_points_gpu_resources, filtered_sizes_gpu_resources):
	if not multimesh_initialized:
		return
	var point_buffers_and_sizes = CameraManager.get_filtered_buffers_and_sizes()
	var num_point_clouds := len(point_buffers_and_sizes["points"])
	uniform_set = rd.uniform_set_create([
		filtered_points_gpu_resources[0],
		filtered_sizes_gpu_resources[0],
		multimesh_buffer_gpu_resources[0],
		output_size_gpu_resources[0],
		output_gpu_resources[0],
		], shader, 0
	) # the last parameter (the 0) needs to match the "set" in our shader file
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# vulkan (??) does not support non-buffer uniforms for compute shaders (???)
	# so we have to use push_constant. Note: This is not a PackedInt32Array because
	# we may eventually want to introduce types that do not fit in 4 bytes in there.
	var parameters := PackedInt32Array()
	# number of point cloud buffers
	parameters.append(num_point_clouds)
	# max number of displayed points
	parameters.append(max_points)
	var parameter_bytes := parameters.to_byte_array()
	#parameter_bytes.resize(parameters.size())
	rd.compute_list_set_push_constant(compute_list, parameter_bytes, 8)
	# we need to be called for max_points because we need to clear unused points.
	var xyz_invoc = ComputeShaderUtils.get_xyz_invocations(max_points)
	rd.compute_list_dispatch(compute_list, xyz_invoc.x, xyz_invoc.y, xyz_invoc.z)
	rd.compute_list_end()
