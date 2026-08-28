extends DynamicNodeManager
var orbbec_devices := OrbbecDevices.new()
var camera_scene := preload("res://scripts/camera.gd")
var camera_setting_scene := preload("res://scenes/ui_components/camera_settings.tscn")
var point_cloud_scene := preload("res://scenes/point_cloud.tscn")
var gizmo
const max_cam_num := 2

## main carto node. Used to connect signals. Could be eliminated with a bit
## more signals and indirection but not sure its worth it.
var carto_node

## containers, used to add the various nodes inside the tree
var camera_container
var camera_settings_container
var point_cloud_container

func get_num_from_node(node):
	return node["camera_settings"].camera_num

const linger_frames = 10
# make group editing status
var group_edit_linger_countdown = 0

var group_edit_ongoing:bool :
	get():
		var multiediting = gizmo._editing and gizmo.get_selected_count() > 1
		# make group editing status linger for some frames to prevent group editing
		# detection drop out when a mouse is quickly moved.
		if multiediting:
			group_edit_linger_countdown = linger_frames
		return (group_edit_linger_countdown > 0) or multiediting

var num_cameras: int:
	get():
		return len(nodes)

# We need to keep this FileAccess alive so that the tmp file exists as long
# as the program runs.
var hesai_pandar_p40_correction_tmp_file:FileAccess
var done = false
func _init() -> void:
	orbbec_devices.refresh_device_list()
	# when the exe is exported, the csv correction files in res://device_configurations
	# are compressed in an archive. To make them accessible to the GDExtensions,
	# we need to put the content in a tmp file.
	hesai_pandar_p40_correction_tmp_file = FileAccess.create_temp(FileAccess.ModeFlags.WRITE_READ,"pandar40p_correction","csv")
	var content = FileAccess.open("res://device_configurations/Pandar40P_correction.csv",FileAccess.READ).get_as_text()
	hesai_pandar_p40_correction_tmp_file.store_string(content)
	# need to flush or else the file will be empty.
	hesai_pandar_p40_correction_tmp_file.flush()

## resets the camera manager to the initial state. helpful when loading savefiles
func reset():
	while num_cameras > 0:
		remove_camera()
	transform_changes_to_stack = Array()
	group_edit_linger_countdown = 0
	soloed_devices = []

var transform_changes_to_stack: Array

## manages undo-redo for grouped camera transforms
func stack_group_transform(old_transform, new_transform, camera_node):
	transform_changes_to_stack.append(old_transform)
	transform_changes_to_stack.append(new_transform)
	transform_changes_to_stack.append(camera_node)

func get_total_max_points():
	var total := 0
	for cam in nodes:
		total += cam["camera"].get_total_max_points()
	return total

func _process(_delta: float) -> void:
	group_edit_linger_countdown = max(group_edit_linger_countdown-1, 0)
	if transform_changes_to_stack.size() > 0:
		var transform_changes = transform_changes_to_stack.duplicate()
		UndoManager.add_to_stack(
			"point cloud group transform change",
			func():
				@warning_ignore("integer_division")
				for i in range(transform_changes.size()/3):
					var new_transform = transform_changes[(i*3)+1]
					var node = transform_changes[(i*3)+2]
					node.dont_stack_next_transform_change = true
					node.transform = new_transform,
			func():
				@warning_ignore("integer_division")
				for i in range(transform_changes.size()/3):
					var old_transform = transform_changes[(i*3)]
					var node = transform_changes[(i*3)+2]
					node.dont_stack_next_transform_change = true
					node.transform = old_transform,
			false,
			UndoRedo.MERGE_ENDS)
		transform_changes_to_stack = []

var soloed_devices := []
func update_solo(state, device_num):
	var device_idx_in_soloed_device := soloed_devices.find(device_num)
	if state and device_idx_in_soloed_device == -1:
		soloed_devices.append(device_num)
	elif not state and device_idx_in_soloed_device != -1:
		soloed_devices.remove_at(device_idx_in_soloed_device)
	# tell all the camerasd
	for cam in nodes:
		cam["point_cloud"].update_display_state(soloed_devices)

func update_point_visibility(device_num):
	var cam = get_node_from_num(device_num)
	cam["point_cloud"].update_display_state(soloed_devices)

func initialize_camera_nodes():
	var cam_idx = get_lowest_available_id()
	if cam_idx == -1:
		ToastManager.show_toast("max camera limit of 1024 attained", "error")
		return null
	var idx:int = cam_idx
	orbbec_devices.get_devices_ips()
	orbbec_devices.get_devices_ips()
	var camera_settings = camera_setting_scene.instantiate()
	var pt_cloud = point_cloud_scene.instantiate()
	var camera = camera_scene.new(camera_settings, pt_cloud, idx)
	camera.is_connecting.connect(camera_settings._on_pointcloud_connecting)
	camera.end_connecting.connect(camera_settings._on_pointcloud_end_connecting)
	camera_settings.point_cloud = pt_cloud
	camera_settings.camera = camera
	camera_settings.camera_num = idx
	camera_settings.orbbec_devices = orbbec_devices
	camera_settings.ip_option_selected.connect(update_orbbec_ip_lists)
	camera_settings.set_orbbec_resolution_dropdown(camera.get_stream_formats())
	pt_cloud.transform_changed.connect(camera_settings._on_pt_cloud_transform_change)
	pt_cloud.camera_num = idx
	pt_cloud.camera = camera
	var cam_nodes = {
		"camera_settings": camera_settings,
		"point_cloud":pt_cloud,
		"camera":camera
	}
	cam_nodes["camera_settings"].gizmo_requested.connect(carto_node._gizmo_select_pressed)
	cam_nodes["camera_settings"].delete_button_pressed.connect(carto_node._on_camera_delete_requested)
	return cam_nodes

func remove_from_ui(camera_nodes):
	camera_settings_container.remove_child(camera_nodes["camera_settings"])
	point_cloud_container.remove_child(camera_nodes["point_cloud"])
	camera_container.remove_child(camera_nodes["camera"])

func remove_camera(camera_num=null):
	if num_cameras == 0:
		return
	if camera_num == null:
		camera_num = nodes[-1]["camera_settings"].camera_num

	var camera_nodes = get_node_from_num(camera_num)
	update_solo(false, camera_num)
	for cam in nodes:
		update_point_visibility(cam["camera"].device_num)

	# clear the gizmo selection to make sure there is no selected nodes that are not in the tree.
	carto_node.clear_gizmo_selection()
	remove_from_ui(camera_nodes)
	var removed_cam = remove(camera_num)
	if removed_cam != null:
		removed_cam["camera"].stop_device()
		update_orbbec_ip_lists()

func add_to_ui(camera_nodes, idx):
	camera_settings_container.add_child(camera_nodes["camera_settings"])
	point_cloud_container.add_child(camera_nodes["point_cloud"])
	camera_container.add_child(camera_nodes["camera"])
	if idx != num_cameras:
		camera_settings_container.move_child(camera_nodes["camera_settings"], idx)
		camera_container.move_child(camera_nodes["camera"], idx)
		point_cloud_container.move_child(camera_nodes["point_cloud"], idx)

func add_camera(camera_nodes, idx=null):
	if idx == null:
		idx = num_cameras
	add_to_ui(camera_nodes, idx)
	add(camera_nodes, idx)
	# tries to restart the camera if the add_camera was called from a redo.
	camera_nodes["camera_settings"].start_device()
	update_orbbec_ip_lists()
	update_solo(camera_nodes["camera"].soloed, camera_nodes["camera"].device_num)
	for cam in nodes:
		update_point_visibility(cam["camera"].device_num)
	ComputePipelinesManager.reallocate_filtered_points_buffer()


func request_redraw():
	for cam in nodes:
		cam["camera"].should_draw = true

func update_orbbec_ip_lists():
	orbbec_devices.refresh_device_list()
	var ips: PackedStringArray = orbbec_devices.get_devices_ips()
	for cam in nodes:
		var ip = cam["camera_settings"].get_current_orbbec_ip()
		if ip != "None":
			ips.erase(ip)
	for cam in nodes:
		# update_ip_dropdown modifies its parameter so it needs a copy of the ips list.
		cam["camera_settings"].update_orbbec_ip_dropdown(ips.duplicate())
