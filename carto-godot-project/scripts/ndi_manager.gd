extends DynamicNodeManager

var ndi_output_scene := preload("res://scenes/ui_components/ndi_output.tscn")

var carto_node
var ndi_output_container

var front_cam
var top_cam
var side_cam

func get_num_from_node(ndi_node):
	return ndi_node.output_num

func update_ndi_view_list() -> void:
	var remaining_views = [0, 1, 2, 3]
	for node in nodes:
		var curr_view = node.current_view
		if curr_view == 0:
			continue
		remaining_views.remove_at(remaining_views.find(node.current_view))

	for node in nodes:
		node.populate_dropdown_from_ids(remaining_views)
		node.refresh_cam_state()

func init_ndi_output():
	var ndi_num = get_lowest_available_id()
	if ndi_num == -1:
		ToastManager.show_toast("max ndi output limit of 1024 attained", "error")
		return null
	var ndi_output = ndi_output_scene.instantiate()
	ndi_output.output_num = ndi_num
	
	ndi_output.delete_button_pressed.connect(carto_node._on_ndi_delete_requested)
	return ndi_output

func remove_from_ui(ndi_out):
	ndi_output_container.remove_child(ndi_out)

func remove_ndi_output(ndi_out_num=null):
	if len(nodes) == 0:
		return
	if ndi_out_num == null:
		ndi_out_num = nodes[-1].output_num
	var ndi_out = get_node_from_num(ndi_out_num)
	remove_from_ui(ndi_out)
	remove(ndi_out_num)
	update_ndi_view_list()
	# stop the removed ndi out

func add_to_ui(ndi_output, idx):
	ndi_output_container.add_child(ndi_output)
	if idx != len(nodes):
		ndi_output_container.move_child(ndi_output, idx)

func add_ndi_output(ndi_out, idx=null):
	if idx == null:
		idx = len(nodes)
	add_to_ui(ndi_out, idx)
	add(ndi_out,idx)
	update_ndi_view_list()
