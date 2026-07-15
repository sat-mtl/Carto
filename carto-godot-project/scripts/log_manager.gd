extends Node
var logs := []

enum log_level {INFO=0, WARNING=1, ERROR=2, SUCCESS=3}
var level_to_colors:= {log_level.INFO: Color.LIGHT_BLUE, log_level.WARNING: Color.YELLOW, log_level.ERROR: Color.RED, log_level.SUCCESS:Color.LIME_GREEN}

signal new_log_entry(entry)

func add_to_log(message:String, severity:log_level):
	var entry := {"msg":message, "lvl":severity, "time":Time.get_datetime_string_from_system().replace("T", " | ")}
	logs.append(entry)
	new_log_entry.emit(entry)

func get_str_from_entry(log_entry):
	var date_color = level_to_colors[log_entry["lvl"]].to_html(false)
	return "([color=#%s]%s[/color]) : %s\n" % [date_color, log_entry["time"], log_entry["msg"]]
