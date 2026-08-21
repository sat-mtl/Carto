extends Node
# this global node manages all the compute pipelines, from point cloud
# acquisition, filtering, (compaction later maybe) to all steps of tracking.

# this buffer contains all the points after cropping, thinning and any other kind
# of filters well think of in the future. It needs to be as long as 1024*1024*3 floats
# times the max device id created (even if you create 25 devices and delete all on them
# except one. the function to get the network point is called with a delay and the memory
# location of points needs to be stable between calls.
var filtered_points_buffer: RID
const floats_per_filtered_point := 3
# this uniform contains filtered_points_buffer. It is also the sole uniform in
# common between the filter stage and the tracking stage. It needs to be shared
# and not just passed by buffer_device_address because otherwise godot's resource
# tracking algorithm is not going to see the dependency and can reorder the call
# which will result in crashes.
var filtered_points_uniform: RDUniform


func _init():
	pass

## this needs to be called everytime a new device is added.
## TODO: maybe prevent a compute shader call when this happens to make
## sure nothing breaks.
func reallocate_filtered_points_buffer():
	ComputeShaderUtils.rendering_device.free_rid(filtered_points_buffer)
	var size = CameraManager.get_total_max_points() * floats_per_filtered_point
	ComputeShaderUtils.create_buffer_with_device_address(size, )
