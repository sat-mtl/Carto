extends Node

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

func create_buffer_with_device_address(rd:RenderingDevice, buffer_size:int, buffer_bytes:PackedByteArray) -> RID:
	if not rd.has_feature(RenderingDevice.Features.SUPPORTS_BUFFER_DEVICE_ADDRESS):
		ToastManager.show_toast("Your GPU doesn't support getting device address. Tracking mode will not work", "warning")
		return rd.storage_buffer_create(buffer_size, buffer_bytes)
	else:
		return rd.storage_buffer_create(buffer_size, buffer_bytes, 0, RenderingDevice.BUFFER_CREATION_DEVICE_ADDRESS_BIT)

# creates the necessary gpu resources needed to pass a byte buffer to a compute
# shader. returns an array of [RDUniform, RID to a storage buffer].
# You really need to call rd.free_rid(the_array_returned_by_this_function[1])
# in order to free the resources on the GPU.
func make_buffer_uniform(rd:RenderingDevice, data_bytes:PackedByteArray, binding):
	var data_storage_buffer := ComputeShaderUtils.create_buffer_with_device_address(rd, data_bytes.size(), data_bytes)
	var data_uniform := RDUniform.new()
	data_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	data_uniform.binding = binding
	data_uniform.add_id(data_storage_buffer)
	return [data_uniform, data_storage_buffer]

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
