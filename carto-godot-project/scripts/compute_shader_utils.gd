extends Node
var rendering_device := RenderingServer.get_rendering_device()

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

func create_buffer_with_device_address(buffer_size:int, buffer_bytes:PackedByteArray) -> RID:
	if not rendering_device.has_feature(RenderingDevice.Features.SUPPORTS_BUFFER_DEVICE_ADDRESS):
		ToastManager.show_toast("Your GPU doesn't support getting device address. Tracking mode will not work", "warning")
		return rendering_device.storage_buffer_create(buffer_size, buffer_bytes)
	else:
		return rendering_device.storage_buffer_create(buffer_size, buffer_bytes, 0, RenderingDevice.BUFFER_CREATION_DEVICE_ADDRESS_BIT)

# creates the necessary gpu resources needed to pass a byte buffer to a compute
# shader. returns an array of [RDUniform, RID to a storage buffer].
# You really need to call rendering_device.free_rid(gpu_resource.buffer)
# in orendering_deviceer to free the resources on the GPU.
class GPUResources:
	var buffer := RID()
	var uniform := RDUniform.new()

	func _init(data_bytes:PackedByteArray, binding):
		buffer = ComputeShaderUtils.create_buffer_with_device_address(data_bytes.size(), data_bytes)
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		uniform.binding = binding
		uniform.add_id(buffer)

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

func free_rids(rids):
	for rid in rids:
		rendering_device.free_rid(rid)

func init_multimesh_buffer(multimesh_buffer_rid: RID, num_points: int, position: Vector3, color=null):
	var num_floats_per_point = 12
	if color != null:
		num_floats_per_point = 16
	else:
		# put a dummy color if we don't need it
		color = Color()
	var mm_init_shader_file := load("res://shaders/init_multimesh_buffer.glsl")
	var mm_init_shader_spirv: RDShaderSPIRV = mm_init_shader_file.get_spirv()
	var mm_init_shader := rendering_device.shader_create_from_spirv(mm_init_shader_spirv)
	var pipeline := rendering_device.compute_pipeline_create(mm_init_shader)
	# binds the point cloud multimesh's buffer to the compute shader so that we can write exclusions
	# directly without a CPU download and a set_buffer to redraw.
	var multimesh_uniform := RDUniform.new()
	multimesh_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	multimesh_uniform.binding = 0
	multimesh_uniform.add_id(multimesh_buffer_rid)

	var uniform_set = rendering_device.uniform_set_create([
		multimesh_uniform,
		], mm_init_shader, 0
	) # the last parameter (the 0) needs to match the "set" in our shader file
	var compute_list := rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# vulkan (??) does not support non-buffer uniforms for compute shaders (???)
	# so we have to use push_constant. Note: This is not a PackedInt32Array because
	# we may eventually want to introduce types that do not fit in 4 bytes in there.
	var parameters := PackedInt32Array()
	parameters.append(num_points)
	parameters.append(num_floats_per_point)
	# plz gdscript, give us a reinterpret cast
	var float_params = parameters.to_byte_array().to_float32_array()
	# number of fields per transform in the transforms buffers (for both point cloud
	# and filter transform buffers)
	float_params.append(position.x)
	float_params.append(position.y)
	float_params.append(position.z)
	# even if we don't need color, this shader needs these push constants
	float_params.append(color.r)
	float_params.append(color.g)
	float_params.append(color.b)
	float_params.append(color.a)

	var parameter_bytes := float_params.to_byte_array()
	# just use the whole 128 bytes, whatever.
	#parameter_bytes.resize(80)
	rendering_device.compute_list_set_push_constant(compute_list, parameter_bytes, parameter_bytes.size())
	# we need to be called for max_points because we need to clear unused points.
	var xyz_invoc = ComputeShaderUtils.get_xyz_invocations(num_points)
	rendering_device.compute_list_dispatch(compute_list, xyz_invoc.x, xyz_invoc.y, xyz_invoc.z)
	rendering_device.compute_list_end()
	call_deferred("free_rids", [mm_init_shader, pipeline])
