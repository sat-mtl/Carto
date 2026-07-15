extends MarginContainer

var current_view = 0

signal delete_button_pressed(origin)

func refresh_cam_state():
	if ndi_cam:
		ndi_cam.toggle(toggled)

# reset ndi cam to previous state when the component re-enters the tree
func _enter_tree() -> void:
	refresh_cam_state()
# shut down ndi cam when component exits the tree.
func _exit_tree() -> void:
	if ndi_cam:
		ndi_cam.toggle(false)

var toggled :bool :
	get():
		return %ActiveToggle.button_pressed
	set(tog):
		toggled = tog
		%ActiveToggle.set_pressed_no_signal(tog)
		if ndi_cam:
			ndi_cam.toggle(tog)
		
# orthographic camera node
var ndi_cam:
	set(ndi_cam_node):
		if ndi_cam_node == null:
			set_texture(null)
		else:
			set_texture(ndi_cam_node.get_ndi_texture())
		# prevent the old ndi cam from being on when switching to none.
		if ndi_cam:
			ndi_cam.toggle(false)
		ndi_cam = ndi_cam_node

var output_num: int:
	set(num):
		output_num = num
		%OutputNum.text = str(num)

func set_texture(tex: ViewportTexture):
	%NDITextureRect.texture = tex

enum ndi_views {NONE=0, FRONT=1, SIDE=2, TOP=3}
var ndi_strings = {ndi_views.NONE:"None", ndi_views.FRONT:"Front", ndi_views.SIDE:"Side", ndi_views.TOP:"Top"}

func set_ndi_cam_from_current_view():
	match current_view:
		ndi_views.NONE:
			ndi_cam = null
		ndi_views.FRONT:
			ndi_cam = NdiManager.front_cam
		ndi_views.SIDE:
			ndi_cam = NdiManager.side_cam
		ndi_views.TOP:
			ndi_cam = NdiManager.top_cam
	refresh_cam_state()


func populate_dropdown_from_ids(ids:Array):
	ids = ids.duplicate()
	if current_view not in ids:
		ids.append(current_view)
	ids.sort()
	%ViewOptionButton.clear()
	for id in ids:
		%ViewOptionButton.add_item(ndi_strings[id], id)
	%ViewOptionButton.select(get_idx_from_id(current_view))

func get_idx_from_id(button_id:int):
	var idx = -1
	for i in range(%ViewOptionButton.item_count):
		var id = %ViewOptionButton.get_item_id(i)
		if button_id == id:
			return i
	return idx

func _on_delete_button_pressed() -> void:
	delete_button_pressed.emit(self)

func _on_view_option_button_item_selected(index: int) -> void:
	var old_view = current_view
	var new_view = %ViewOptionButton.get_item_id(index)
	UndoManager.add_to_stack("select ndi_view", 
		func(): 
			current_view = new_view
			%ViewOptionButton.select(index)
			NdiManager.update_ndi_view_list()
			set_ndi_cam_from_current_view(),
		func():
			current_view = old_view
			%ViewOptionButton.select(get_idx_from_id(old_view))
			NdiManager.update_ndi_view_list()
			set_ndi_cam_from_current_view()
	)

func stack_toggle_ndi(toggled_on) -> void:
	UndoManager.add_to_stack(
		"toggle_ndi " + str(output_num),
		func():
			%ActiveToggle.set_pressed_no_signal(toggled_on)
			toggled = toggled_on,
		func():
			%ActiveToggle.set_pressed_no_signal(not toggled_on)
			toggled = not toggled_on
	)

func _on_active_toggle_toggled(toggled_on: bool) -> void:
	stack_toggle_ndi(toggled_on)
