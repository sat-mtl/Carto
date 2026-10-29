extends DynamicNodeManager

var osc_output_scene := preload("res://scenes/ui_components/osc_destination.tscn")

var carto_node
var osc_output_container

func get_num_from_node(ndi_node):
	return ndi_node.output_num

func init_osc_output():
	var osc_num = get_lowest_available_id()
	if osc_num == -1:
		ToastManager.show_toast("max osc output limit of 1024 attained", "error")
		return null
	var osc_output = osc_output_scene.instantiate()
	osc_output.output_num = osc_num
	osc_output.delete_button_pressed.connect(carto_node._on_osc_delete_requested)
	return osc_output

func remove_from_ui(osc_out):
	osc_output_container.remove_child(osc_out)

func remove_osc_output(osc_out_num=null):
	if len(nodes) == 0:
		return
	if osc_out_num == null:
		osc_out_num = nodes[-1].output_num
	var osc_out = get_node_from_num(osc_out_num)
	remove_from_ui(osc_out)
	osc_out.is_removed = true
	remove(osc_out_num)

func add_to_ui(osc_output, idx):
	osc_output_container.add_child(osc_output)
	if idx != len(nodes):
		osc_output_container.move_child(osc_output, idx)

func add_osc_output(osc_out, idx=null):
	if idx == null:
		idx = len(nodes)
	add_to_ui(osc_out, idx)
	osc_out.is_removed = false
	add(osc_out,idx)
