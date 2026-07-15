extends FileDialog

signal on_choice
var last_value = "canceled"

func get_last_value():
	var val = last_value
	last_value = "canceled"
	return val

func _on_file_selected(_path: String) -> void:
	last_value = "confirmed"
	on_choice.emit()

func _on_canceled() -> void:
	last_value = "canceled"
	on_choice.emit()

func _on_confirmed() -> void:
	last_value = "confirmed"
	on_choice.emit()

func _on_close_requested() -> void:
	last_value = "canceled"
	on_choice.emit()
