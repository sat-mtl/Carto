extends LineEdit

@export var last_valid_ip := "127.0.0.1"
@export var allow_none := false
var ip_regex := RegEx.new()
func _ready() -> void:
	ip_regex.compile("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$")
	text = last_valid_ip

signal valid_change(ip:String)

func validate(ip:String, should_emit:bool = true):
	if ip == last_valid_ip:
		return
	if allow_none and ip == "":
		ip = "None"
	if ip_regex.search(ip) or (allow_none and ip == "None"):
		last_valid_ip = ip
		text = ip
		if should_emit:
			valid_change.emit(ip)
	else:
		text = last_valid_ip

func validate_no_signal(ip):
	validate(ip, false)

func _on_text_submitted(new_text: String) -> void:
	validate(new_text)

func _on_focus_exited() -> void:
	validate(text)
