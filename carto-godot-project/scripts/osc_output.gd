extends Node

# osc messages to send for this frame
var osc_messages: Dictionary

func _process(_delta: float):
	var should_send = osc_messages.size() != 0
	if should_send:
		for osc_destination in %OSCOutputs.get_children():
			if osc_destination.is_active:
				osc_destination.send(osc_messages)
	# reset to an empty dict
	osc_messages.clear()
