extends AcceptDialog

signal on_choice(choice)
var last_value

func get_last_value():
	var val = last_value
	last_value = "canceled"
	return val

func _on_custom_action(_action: StringName) -> void:
	last_value = "no"
	on_choice.emit()

func _on_confirmed() -> void:
	last_value = "yes"
	on_choice.emit()

func _on_canceled() -> void:
	last_value = "canceled"
	on_choice.emit()
