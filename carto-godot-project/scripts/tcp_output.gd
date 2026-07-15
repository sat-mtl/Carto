extends Node

var combined_point_cloud: PackedByteArray
var last_num_cam := 0
func _process(_delta: float):
	# if we have a different number of cams than the frame before, we should resend.
	var should_send = last_num_cam != CameraManager.num_cameras
	last_num_cam = CameraManager.num_cameras
	for camera in CameraManager.nodes:
		# if any point_cloud has new data, send the whole merged point cloud
		if camera["camera"].has_new_output_data:
			should_send = true
			break
	combined_point_cloud.clear()
	if should_send:
		for camera in CameraManager.nodes:
			combined_point_cloud.append_array(camera["camera"].output_data)
			camera["camera"].has_new_output_data = false
		for network_destination in %NetworkDestinations.get_children():
			if network_destination.is_active:
				network_destination.push_frame(combined_point_cloud)
