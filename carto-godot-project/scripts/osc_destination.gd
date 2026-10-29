extends MarginContainer

signal delete_button_pressed(origin)

func _ready() -> void:
	manage_socket_connection()

var is_active = false:
	set(val):
		is_active = val
		%ActiveToggle.set_pressed_no_signal(val)
		manage_socket_connection()

## The property is true if the node only exists in memory while waiting
## to be reinstated by a redo.
var is_removed: int:
	set(val):
		is_removed = val
		manage_socket_connection()

func send(messages:Dictionary):
	if not is_active or is_removed:
		return
	for addr in messages.keys():
		var msg = messages[addr] if messages[addr] is Array else [messages[addr]]
		%OSCClient.send_message(addr, msg)

var output_port: int = 8787:
	set(port):
		%PortSpinBoxEdit.value = port
		output_port = port

var output_ip: String = "127.0.0.1"

var output_num: int:
	set(num):
		output_num = num
		%OutputNum.text = str(num)

## Use this when loading a save or forcibly setting the port and ip from external
## values. This enforces the same validations as changing the ui values
func set_port_and_ip(port:int, ip:String):
	_on_port_spinbox_value_changed(port)
	%IPLineEdit.validate(ip)

func _on_port_spinbox_value_changed(value: float) -> void:
	# minimum and maximum ports are handled in the spinbox's properties
	var old_port = output_port
	UndoManager.add_to_stack(
		"network_output_set_ip " + str(output_num),
		func():
			@warning_ignore("narrowing_conversion")
			self.output_port = value
			manage_socket_connection()
			%PortSpinBoxEdit.set_value_no_signal(value),
		func():
			self.output_port = old_port
			manage_socket_connection()
			%PortSpinBoxEdit.set_value_no_signal(old_port)
	)

func _on_ip_line_edit_valid_change(new_output_ip: String) -> void:
	var old_ip = output_ip
	UndoManager.add_to_stack(
		"network_output_set_ip " + str(output_num),
		func():
			@warning_ignore("narrowing_conversion")
			self.output_ip = new_output_ip
			manage_socket_connection()
			%IPLineEdit.validate_no_signal(new_output_ip),
		func():
			self.output_ip = old_ip
			manage_socket_connection()
			%IPLineEdit.validate_no_signal(old_ip)
	)

func manage_socket_connection():
	if not is_active or is_removed:
		%OSCClient.close_socket()
	else:
		%OSCClient.connect_socket(output_ip, output_port)

func _on_active_toggle_toggled(toggled_on: bool) -> void:
	UndoManager.add_to_stack("toggle network active",
		func():
			is_active = toggled_on
			manage_socket_connection()
			%ActiveToggle.set_pressed_no_signal(toggled_on),
		func():
			is_active = not toggled_on
			manage_socket_connection()
			%ActiveToggle.set_pressed_no_signal(not toggled_on)
	)

func _on_delete_button_pressed() -> void:
	delete_button_pressed.emit(self)
