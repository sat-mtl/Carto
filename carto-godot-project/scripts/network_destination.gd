extends MarginContainer

var is_active = false:
	set(val):
		is_active = val
		# if we were inactive for a long time we may need to reconnect.
		needs_reconnection = true
		%ActiveToggle.set_pressed_no_signal(val)
var undo_manager
var tcp_sender: StreamPeerTCP = StreamPeerTCP.new()
var needs_reconnection = true
var send_thread : Thread
var tcp_sender_mutex := Mutex.new()
var sender_semaphore := Semaphore.new()
var frame_queue := []
var frame_queue_mutex := Mutex.new()
var should_exit_mutex := Mutex.new()
var should_exit = false

## The property is true if the node only exists in memory while waiting
## to be reinstated by a redo.
var is_removed: int:
	set(val):
		should_exit_mutex.lock()
		should_exit = true
		should_exit_mutex.unlock()
		sender_semaphore.post()
		is_removed = val
		if val:
			tcp_sender.disconnect_from_host()
		else:
			should_exit_mutex.lock()
			should_exit = false
			should_exit_mutex.unlock()
			start_thread()
			needs_reconnection = true

func push_frame(frame: PackedByteArray):
	# don't infinitely accumulate stale frames to avoid out of memory errors.
	if queue_size() >= 1:
		#print("no place in queue")
		return
	frame_queue_mutex.lock()
	frame_queue.push_back(frame)
	frame_queue_mutex.unlock()
	sender_semaphore.post()

func pop_frame():
	frame_queue_mutex.lock()
	var frame = frame_queue.pop_back()
	frame_queue_mutex.unlock()
	return frame

func queue_size():
	frame_queue_mutex.lock()
	var q_size := frame_queue.size()
	frame_queue_mutex.unlock()
	return q_size

func put_data_non_blocking(point_frame:PackedByteArray, timeout_ms:int) -> bool:
	var start_send := Time.get_ticks_msec()
	var to_send = len(point_frame)
	var sent := 0
	while sent < to_send:
		if Time.get_ticks_msec() - start_send > timeout_ms:
			print("timeout")
			return false
		if sent != 0 and len(point_frame) != to_send - sent:
			point_frame = point_frame.slice(sent)
		var result := tcp_sender.put_partial_data(point_frame)
		if result[0] != Error.OK:
			print("error")
			return false
		sent += result[1]
	return true

func send(combined_point_cloud:PackedByteArray):
	if is_removed:
		return
	tcp_sender_mutex.lock()
	# this poll seems important to keep the connection up and running
	tcp_sender.poll()
	if (needs_reconnection or
			not tcp_sender.get_connected_host() or
			tcp_sender.get_status() == tcp_sender.STATUS_NONE or
			tcp_sender.get_status() == tcp_sender.STATUS_ERROR):
		print("tcp_sender.get_status() == tcp_sender.STATUS_NONE :", tcp_sender.get_status() == tcp_sender.STATUS_NONE)
		print("tcp_sender.get_status() == tcp_sender.STATUS_ERROR :", tcp_sender.get_status() == tcp_sender.STATUS_ERROR)
		tcp_sender.disconnect_from_host()
		tcp_sender.connect_to_host(output_ip, output_port)
		tcp_sender.set_no_delay(true)
		tcp_sender.poll()
		needs_reconnection = false
	# frame the message with a 32 bit int
	var point_cloud_frame := PackedByteArray()
	point_cloud_frame.resize(4)
	point_cloud_frame.encode_u32(0, len(combined_point_cloud))
	point_cloud_frame.append_array(combined_point_cloud)
	var success = put_data_non_blocking(point_cloud_frame, 60)
	if not success:
		needs_reconnection = true
	tcp_sender_mutex.unlock()

var output_port: int = 9898:
	set(port):
		%PortSpinBoxEdit.value = port
		output_port = port
var output_ip: String = "127.0.0.1"
var ip_regex = RegEx.new()
@export
var output_num: int

## Use this when loading a save or forcibly setting the port and ip from external
## values. This enforces the same validations as changing the ui values and
## forces a reconnection
func set_port_and_ip(port:int, ip:String):
	_on_port_spinbox_value_changed(port)
	%IPLineEdit.validate(ip)

func send_loop():
	while true:
		sender_semaphore.wait() # Wait until posted.
		should_exit_mutex.lock()
		if should_exit:
			should_exit_mutex.unlock()
			return
		should_exit_mutex.unlock()
		while queue_size():
			var frame = pop_frame()
			# guard against a weird Nil bug, maybe ??
			if frame is PackedByteArray:
				send(frame)

func start_thread():
	# wait for a possibly alive thread to finish
	if send_thread and send_thread.is_alive():
		should_exit_mutex.lock()
		should_exit = true
		should_exit_mutex.unlock()
		# post the semaphore to ensure one loop through the loop to exit it.
		sender_semaphore.post()
		send_thread.wait_to_finish()
		should_exit_mutex.lock()
		should_exit = false
		should_exit_mutex.unlock()

	send_thread = Thread.new()
	send_thread.start(send_loop)

func _ready() -> void:
	ip_regex.compile("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$")
	start_thread()

func _process(_delta):
	tcp_sender_mutex.lock()
	if tcp_sender.get_status() == tcp_sender.STATUS_NONE or tcp_sender.get_status() == tcp_sender.STATUS_ERROR:
		%StatusLed.color = Color(1,0,0)
	elif tcp_sender.get_status() == tcp_sender.STATUS_CONNECTING:
		%StatusLed.color = Color(1,1,0)
	elif tcp_sender.get_status() == tcp_sender.STATUS_CONNECTED:
		%StatusLed.color = Color(0,1,0)
	tcp_sender_mutex.unlock()

func _on_port_spinbox_value_changed(value: float) -> void:
	# minimum and maximum ports are handled in the spinbox's properties
	var old_port = output_port
	undo_manager.add_to_stack(
		"network_output_set_ip " + str(output_num),
		func():
			@warning_ignore("narrowing_conversion")
			self.output_port = value
			%PortSpinBoxEdit.set_value_no_signal(value)
			needs_reconnection = true,
		func():
			self.output_port = old_port
			%PortSpinBoxEdit.set_value_no_signal(old_port)
			needs_reconnection = true
	)

func _on_ip_line_edit_valid_change(new_output_ip: String) -> void:
	var old_ip = output_ip
	undo_manager.add_to_stack(
		"network_output_set_ip " + str(output_num),
		func():
			@warning_ignore("narrowing_conversion")
			self.output_ip = new_output_ip
			%IPLineEdit.validate_no_signal(new_output_ip)
			needs_reconnection = true,
		func():
			self.output_ip = old_ip
			%IPLineEdit.validate_no_signal(old_ip)
			needs_reconnection = true
	)

func _on_active_toggle_toggled(toggled_on: bool) -> void:
	undo_manager.add_to_stack("toggle network active",
		func():
			is_active = toggled_on
			%ActiveToggle.set_pressed_no_signal(toggled_on),
		func():
			is_active = not toggled_on
			%ActiveToggle.set_pressed_no_signal(not toggled_on)
	)
