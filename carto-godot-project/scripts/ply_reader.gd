extends Node
class_name PLYReader

signal point_cloud_frame(point_cloud_buffer: RID, point_cloud_bytes: PackedByteArray)
signal max_points_changed(max_points:int)


var is_active = true
var max_points: int:
	set(m_pts):
		max_points = m_pts
		max_points_changed.emit(max_points)
var point_frames: Array[PackedVector3Array]
var buffer := RID()
var time_since_last_send := 0.0
var current_frame := 0
var rd := ComputeShaderUtils.rendering_device

func poll_for_frame(delta: float) -> void:
	if not is_active or max_points == 0:
		return
	time_since_last_send += delta
	if time_since_last_send >= play_period:
		var frame = point_frames[current_frame % len(point_frames)]
		var frame_bytes := frame.to_byte_array()
		rd.buffer_update(buffer, 0, frame_bytes.size(), frame_bytes)
		point_cloud_frame.emit(buffer, frame_bytes)
		time_since_last_send -= play_period
		current_frame+=1

var frame_rate : float :
	set(rate):
		play_period = 1.0/rate
		time_since_last_send = 0.0
	get:
		return 1.0/play_period

# play period of the frames in seconds
var play_period := 1.0/60.0

var current_folder_path:String
var current_file_name_prefix:String

func make_process_file_func(frames_files_string):
	return func(idx):
		var frame = read_ply_file(frames_files_string[idx])
		if frame:
			point_frames[idx] = frame

func read_folder(path:String, file_name_prefix:String) -> bool:
	# short circuit this long operation if its the same as before.
	if max_points > 0 and current_folder_path == path and current_file_name_prefix == file_name_prefix:
		return true
	current_folder_path = path
	current_file_name_prefix = file_name_prefix
	point_frames.clear()
	max_points = 0
	time_since_last_send = 0.0
	current_frame = 0
	if file_name_prefix == "" or current_folder_path == "":
		return false
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var frames_nums := {}
	for file: String in dir.get_files():
		var file_split := file.replace(path, "").split(".")
		if file_split[len(file_split) - 1] != "ply":
			continue
		if not file.contains(file_name_prefix):
			continue
		var frame_num_str := file_split[0].split(file_name_prefix)[1]
		# use a dict here so that numbers prefixed with zeroes are preserved at
		# the next step were we want to traverse files in numerical order.
		frames_nums[frame_num_str.to_int()] = frame_num_str
	frames_nums.sort()
	var frames_files_strings := []
	for frame_num_int in frames_nums:
		var file_path :String = path+"/"+file_name_prefix+frames_nums[frame_num_int]+".ply"
		if FileAccess.file_exists(file_path):
			frames_files_strings.append(file_path)
	point_frames.resize(len(frames_nums))
	var process_file_func = make_process_file_func(frames_files_strings)
	var tasks = WorkerThreadPool.add_group_task(process_file_func, len(frames_files_strings),-1)
	WorkerThreadPool.wait_for_group_task_completion(tasks)
	for frame in point_frames:
		max_points = max(max_points, len(frame))
	for frame in point_frames:
		var old_frame_size := len(frame)
		var size_diff = max_points - old_frame_size
		frame.resize(max_points)
		# fill empty slots in vector buffer so that all the frame are the same size
		for i in range(size_diff):
			frame[old_frame_size + i] = Vector3.ONE*-666.0

	if buffer.is_valid():
		rd.free_rid(buffer)
	# 3 floats of 4 bytes per point
	buffer = rd.storage_buffer_create(max_points*3*4)
	return true

func read_ply_file(path):
	var frame:= PackedVector3Array()
	var file: FileAccess
	if not FileAccess.file_exists(path):
		return false
	else:
		file = FileAccess.open(path, FileAccess.READ)
		var ply_lines = file.get_as_text().split("\n", false)
		var header_ended:= false
		for line in ply_lines:
			if not header_ended:
				if line.strip_edges() == "end_header":
					header_ended = true
				continue
			var coords := line.strip_edges().split(" ")
			var point := Vector3(coords[0].to_float(), coords[1].to_float(), coords[2].to_float())
			if is_zero_approx(point.x) and is_zero_approx(point.y) and is_zero_approx(point.z):
				continue
			if is_nan(point.x) or is_nan(point.y) or is_nan(point.z):
				continue
			frame.append(point)
	return frame
