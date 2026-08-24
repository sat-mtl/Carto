extends Node3D
var num_network_outputs := 0
var network_output_scene := preload("res://scenes/ui_components/network_destination.tscn")

var network_outputs = []

const user_settings_path := "user://carto_user_settings.json"
var user_settings: Dictionary

func scale_ui(ui_scale: float):
	get_window().wrap_controls = true
	get_window().content_scale_factor = ui_scale
	get_window().child_controls_changed()

func _on_log_entry(log_entry):
	%LogsRichTextLabel.text += LogManager.get_str_from_entry(log_entry)

func _ready() -> void:
	CameraManager.carto_node = self
	CameraManager.point_cloud_container = %CalibPointClouds
	CameraManager.camera_container =  %PointCloudCameras
	CameraManager.camera_settings_container = %CamerasContainer

	NdiManager.carto_node = self
	NdiManager.ndi_output_container = %NDIOutputs
	NdiManager.front_cam = %FrontCamera
	NdiManager.side_cam = %SideCamera
	NdiManager.top_cam = %TopCamera

	LogManager.new_log_entry.connect(_on_log_entry)
	# prevent the app from immediately exiting
	# Note : when running carto from the godot editor, the window will still close
	# if you press X but carto will still be running in the Game tab.
	get_tree().set_auto_accept_quit(false)
	%CropRegionContainer.crop_region_request_gizmo.connect(_on_crop_region_gizmo_request)
	%CropRegion.gizmo_requested.connect(_on_crop_region_gizmo_request)

	var user_settings_string := "{}"
	var file: FileAccess
	if not FileAccess.file_exists(user_settings_path):
		file = FileAccess.open(user_settings_path, FileAccess.WRITE)
		file.store_string(user_settings_string)
	else:
		file = FileAccess.open(user_settings_path, FileAccess.READ)
		user_settings_string = file.get_as_text()
	user_settings = JSON.parse_string(user_settings_string)
	var ui_scale = user_settings.get("ui_scaling", 1.0)
	%UIScalingSpinBox.set_value_no_signal(ui_scale)
	scale_ui(ui_scale)
	var args = OS.get_cmdline_args()
	if args and (args[0].ends_with(".ptmap") or args[0].ends_with(".carto") or args[0].ends_with(".autosave")):
		# if we specify a savefile at startup, we probably want that savefile to
		# be loaded immediately without prompting for autosave stuff.
		load_savefile(args[0], false)

func save_user_settings():
	var file := FileAccess.open(user_settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(user_settings))

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var should_quit = false
		# if the user asked to exit and there are unsaved changes or recent autosave data
		# asks if they want to save.
		var has_changes = has_changes_since_last_save()
		if has_changes or get_autosave_data(current_save_path):
			%ConfirmDialog.dialog_text = "There are unsaved changes, do you wish to save before exiting ?"
			%ConfirmDialog.title = "Save unsaved changes ?"
			var cancel_button = %ConfirmDialog.add_button("No", true, "no")
			%ConfirmDialog.popup()
			await %ConfirmDialog.on_choice
			var confirmation_value = %ConfirmDialog.get_last_value()
			if confirmation_value == "yes":
				var save =  save_or_save_as()
				if save == save_type.SAVE_AS:
					await %SaveDialog.on_choice
					var save_choice = %SaveDialog.get_last_value()
					if save_choice == "canceled":
						# cleanup the dialogue if we cancel was pressed.
						%ConfirmDialog.remove_button(cancel_button)
						%ConfirmDialog.visible = false
						return
				should_quit = true
			elif confirmation_value == "no":
				should_quit = true
			else:
				# cleanup the dialogue if we cancel was pressed.
				%ConfirmDialog.remove_button(cancel_button)
				%ConfirmDialog.visible = false
		else:
			should_quit = true
		if should_quit:
			save_user_settings()
			get_tree().quit()

func _gizmo_select_pressed(camera_settings):
	gizmo_select_node(camera_settings.point_cloud, _add)

func gizmo_select_crop_region():
	gizmo_select_node(%CropRegion, false)

func select_crop_region():
	gizmo_select_node(%CropRegion, false)
	# current tab goes to crop region
	%CalibSideBarUI.current_tab = 1
	%CropRegion.highlight()

func _on_crop_gizmo_select_pressed() -> void:
	select_crop_region()

func _on_crop_region_gizmo_request():
	select_crop_region()

func toggle_crop_active(toggled_on):
	CameraManager.request_redraw()
	%CropRegionContainer.visible = toggled_on
	%CropRegion.filter_active = toggled_on
	# this may seem redundant but its needed for undo-redo purposes.
	%CropActive.set_pressed_no_signal(toggled_on)

func _on_crop_active_toggled(toggled_on: bool) -> void:
	UndoManager.add_to_stack("toggle_crop_active", func():toggle_crop_active(toggled_on), func(): toggle_crop_active(!toggled_on))

func _on_camera_delete_requested(cam_num):
	var cam_nodes = CameraManager.get_node_from_num(cam_num)
	var insert_idx = CameraManager.get_array_idx_from_num(cam_num)
	UndoManager.add_to_stack("delete specific camera " + str(cam_num), func(): CameraManager.remove_camera(cam_num), func():CameraManager.add_camera(cam_nodes, insert_idx))

func _on_add_camera_button_pressed() -> void:
	var camera_nodes = CameraManager.initialize_camera_nodes()
	if camera_nodes == null:
		return
	UndoManager.add_to_stack("add camera", func():CameraManager.add_camera(camera_nodes), func(): CameraManager.remove_camera())

func _on_remove_camera_button_pressed() -> void:
	# capture the futurely removed nodes so that their reference
	# count increase and that we can reinstate them on a redo.
	if CameraManager.num_cameras == 0:
		return
	var nodes = CameraManager.nodes[CameraManager.num_cameras-1]
	UndoManager.add_to_stack("remove camera", func(): CameraManager.remove_camera(), func(): CameraManager.add_camera(nodes))

var _add : bool = false

func update_gizmo_mode(selected_node):
	if selected_node == %CropRegion:
		# rotating and scaling on the same gizmo is error prone and rotation is uncommon.
		%Gizmo3D.mode = Gizmo3D.ToolMode.MOVE | Gizmo3D.ToolMode.SCALE
	else:
		# no point cloud scaling right now.
		%Gizmo3D.mode = Gizmo3D.ToolMode.MOVE  | Gizmo3D.ToolMode.ROTATE

func clear_gizmo_selection():
	for cams in CameraManager.nodes:
		cams["point_cloud"].gizmo_selected = false
	%Gizmo3D.clear_selection()

func gizmo_select_node(node, add=false):
	update_gizmo_mode(node)
	if node != %CropRegion:
		%CropRegion.unhighlight()
	if !add:
		clear_gizmo_selection()
		%Gizmo3D.select(node)
		if node != %CropRegion:
			node.gizmo_selected = true
		return
	var has_deselected = %Gizmo3D.deselect(node)
	if !has_deselected:
		%Gizmo3D.select(node)
		if node != %CropRegion:
			node.gizmo_selected = true
	elif node != %CropRegion and has_deselected:
		node.gizmo_selected = false

# used to prevent gizmos from being released when a mouvement was made during
# the click (to pan the camera).
var mouse_movement := Vector2.ZERO
var accumulate_mouse_mouvement := false

func _process(_delta: float) -> void:
	var title := get_window().title
	if not title.ends_with("*") and has_changes_since_last_save():
		get_window().title += " *"
	if Input.is_action_pressed("left_click"):
		accumulate_mouse_mouvement = true
	else:
		# debounce de-clicks lost by long inaction
		mouse_movement = Vector2.ZERO
		accumulate_mouse_mouvement = false

signal forward_input_event(event: InputEvent)

## Input forwarding to make some components still receive inputs even when hovering over
## ui components. You can set this to true from anywhere using
## get_tree().get_root().get_node("Carto").should_forward = true
var should_forward = false

func _input(event: InputEvent):
	if event.is_action_pressed("left_click") and get_viewport().gui_get_focus_owner() == null:
		should_forward = true
	if event.is_action_released("left_click"):
		should_forward = false
	# if there were no other gui element that got focus on that event, forward it.
	if should_forward:
		forward_input_event.emit(event)

func _unhandled_input(event: InputEvent) -> void:
	if not Input.is_action_pressed("undo") and not Input.is_action_pressed("redo"):
		_add = Input.is_action_pressed("add_target")
	else:
		_add = false
	if event.is_action_pressed("save"):
		save_or_save_as()
	if event.is_action_pressed("save_as"):
		save_as()
	if event.is_action_pressed("load"):
		initiate_load()
	if event is InputEventMouseMotion and accumulate_mouse_mouvement:
		mouse_movement += event.relative
	# Prevent object picking if user is interacting with the %Gizmo3D
	if %Gizmo3D.hovering || %Gizmo3D.editing:
		return
	if event.is_action_pressed("exit"):
		close_all_modals()
	if event.is_action_pressed("left_click"):
		# deselect buttons and text fields and other gui elements when
		# clicking anywhere else.
		get_viewport().gui_release_focus()
	if event.is_action_released("left_click"):
		var should_not_deselect = mouse_movement.length() > 1
		mouse_movement = Vector2.ZERO
		accumulate_mouse_mouvement = false
		# This is to prevent gizmo selection from being lost when the left
		# clic is used to move the camera
		if should_not_deselect:
			return
		# Raycast from the camera

		var camera := get_viewport().get_camera_3d()
		var dir := camera.project_ray_normal(event.position)
		var from := camera.project_ray_origin(event.position)
		var params = PhysicsRayQueryParameters3D.new()
		params.from = from
		params.to = from + dir * 1000.0
		var result = get_world_3d().direct_space_state.intersect_ray(params)
		# deselect if we clicked on nothing and had something selected.
		if result.size() == 0:
			if %Gizmo3D._selections.size() > 0:
				clear_gizmo_selection()
				%CropRegion.unhighlight()
			return
		# If control is held, add/remove the node to/from the target list. Otherwise set the target to just that node.
		var collider = result["collider"] as Node3D
		var node = collider.get_parent().get_parent()
		gizmo_select_node(node, _add)
		var nodes = CameraManager.get_node_from_num(node.camera_num)
		# current tab goes to cameras
		%CalibSideBarUI.current_tab = 0
		%CameraScrollContainer.ensure_control_visible(nodes["camera_settings"])
		nodes["camera_settings"].focus_gizmo_button()

func init_network_output():
	var idx:int = num_network_outputs + 1
	var network_output = network_output_scene.instantiate()
	network_output.add_to_group("network_outputs")
	network_output.output_num = idx
	network_output.undo_manager = UndoManager
	return network_output

func add_network_output(network_output_node):
	self.num_network_outputs += 1
	#TODO: make sure we restart the orbbec stream if we have redoed node creation.
	%NetworkDestinations.add_child(network_output_node)
	network_outputs.append(network_output_node)
	network_output_node.is_removed = false

func remove_network_output():
	if num_network_outputs == 0:
		return
	num_network_outputs -= 1
	var network_output_node = network_outputs[num_network_outputs]
	%NetworkDestinations.remove_child(network_output_node)
	network_outputs.remove_at(num_network_outputs)
	network_output_node.is_removed = true

func _on_add_network_out_button_pressed() -> void:
	var network_node = init_network_output()
	UndoManager.add_to_stack("add network_output", func():add_network_output(network_node), func(): remove_network_output())

func _on_remove_network_out_button_pressed() -> void:
	if num_network_outputs == 0:
		return
	var network_node = network_outputs[num_network_outputs-1]
	UndoManager.add_to_stack("remove camera", func():remove_network_output(), func(): add_network_output(network_node))

## for now, we can't have more than 3 ndi outputs (3 fixed perspectives)
func update_add_ndi_enable():
	%AddNDIOutButton.disabled = len(NdiManager.nodes) >= 3

func _on_ndi_delete_requested(ndi_node):
	var insert_idx = NdiManager.get_array_idx_from_num(ndi_node.output_num)
	UndoManager.add_to_stack("remove ndi_output " + str(ndi_node.output_num),
		func():
			NdiManager.remove_ndi_output(ndi_node.output_num)
			update_add_ndi_enable(),
		func():
			NdiManager.add_ndi_output(ndi_node, insert_idx)
			update_add_ndi_enable()
	)

func _on_add_ndi_out_button_pressed() -> void:
	var ndi_node = NdiManager.init_ndi_output()
	if ndi_node == null:
		return
	UndoManager.add_to_stack("add ndi_output",
		func():
			NdiManager.add_ndi_output(ndi_node)
			update_add_ndi_enable(),
		func():
			NdiManager.remove_ndi_output()
			update_add_ndi_enable()
	)

var current_save_path := "":
	set(path):
		current_save_path = path
		if path != "":
			get_window().title = "Carto - " + path

func save_as():
	%SaveDialog.current_path = user_settings.get("last_saveload_directory", "user://") + "/"
	%SaveDialog.visible = true

enum save_type {SAVE, SAVE_AS}
func save_or_save_as():
	if current_save_path == "":
		save_as()
		return save_type.SAVE_AS
	else:
		save_savefile(current_save_path)
		return save_type.SAVE

# please increment this when you make changes to the savefile format.
var current_save_version = 3
func _on_save_settings_dialog_file_selected(path: String) -> void:
	save_savefile(path)

func autosave():
	if current_save_path == "":
		return
	save_savefile(current_save_path+".autosave", false)

func save_savefile(path:String, store_current_path=true):
	# replace old .ptmap name to .carto
	if path.find(".ptmap") != -1:
		path = path.replace(".ptmap", ".carto")
	if not (path.ends_with(".carto") or path.ends_with(".autosave")):
		path+=".carto"
	if store_current_path:
		current_save_path = path
	var save_data = {
		"carto_save_version" : current_save_version,
		"save_time" : Time.get_unix_time_from_system()
		}
	save_data["crop_region"] = {
		"transform":SavefileUtils.serialize_transform(%CropRegion.transform),
		"active": %CropRegion.filter_active
	}
	save_data["viewport_camera"] = {
		"camera_transform": SavefileUtils.serialize_transform(%FreeCamera.transform),
		"pivot_global_position": SavefileUtils.serialize_vec3(%FreeCameraPivot.global_position),
		"camera_mode": %CameraViewMenu.title
	}
	save_data["cameras"] = []
	for camera in CameraManager.nodes:
		var orbbec_settings := {
			"ip": camera["camera_settings"].get_current_orbbec_ip(),
			"fps": camera["camera_settings"].get_current_orbbec_fps(),
			"resolution": camera["camera_settings"].get_current_orbbec_resolution(),
		}
		var hesai_settings := {
			"ip": camera["camera_settings"].get_current_hesai_ip(),
			"port": camera["camera_settings"].current_hesai_port
		}
		var cam_data := {
			"device_type": camera["camera"].enum_to_device_str(camera["camera"].current_device_type),
			"name": camera["camera"].camera_name,
			"has_default_name": camera["camera"].has_default_name,
			"color": SavefileUtils.serialize_color(camera["camera"].color),
			"centroid_toggled": camera["camera"].centroid_toggled,
			"has_centroid": camera["camera"].has_centroid,
			"thinning": camera["camera"].thinning,
			"point_size": camera["camera"].point_size,
			"centroid": SavefileUtils.serialize_vec3(camera["camera"].centroid),
			"transform": SavefileUtils.serialize_transform(camera["camera"].transform),
			"active_state": camera["camera"].active,
			"displayed": camera["camera"].displayed,
			"soloed": camera["camera"].soloed,
			"orbbec_settings": orbbec_settings,
			"hesai_settings": hesai_settings
		}
		save_data["cameras"].append(cam_data)
	save_data["network_outputs"] = []
	for network_output in network_outputs:
		var net_output_data := {
			"active": network_output.is_active,
			"output_port" : network_output.output_port,
			"output_ip" : network_output.output_ip
		}
		save_data["network_outputs"].append(net_output_data)
	save_data["ndi_outputs"] = []
	for ndi_out in NdiManager.nodes:
		save_data["ndi_outputs"].append({
			"toggled": ndi_out.toggled,
			"current_view": ndi_out.current_view
		})
	var save_json := JSON.stringify(save_data, "  ")
	var file = FileAccess.open(path, FileAccess.WRITE)
	user_settings["last_saveload_directory"] = path.get_base_dir()
	file.store_string(save_json)
	# makes it so that no autosave is triggered right after a save
	last_history_count = UndoManager.undoredo.get_history_count()
	last_undo_redo_count = UndoManager.undo_redo_count

func initiate_load() -> void:
	%LoadDialog.current_path = user_settings.get("last_saveload_directory", "user://")
	%LoadDialog.visible = true

func _on_load_dialog_file_selected(path: String) -> void:
	load_savefile(path)

## check for autosave data at a given path.
## returns false if there is none or if the autosave is less recent
## than the last save. returns the autosave data otherwise
func get_autosave_data(path: String):
	if path == "":
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var save_data = JSON.parse_string(file.get_as_text())

	if FileAccess.file_exists(path+".autosave"):
		var autosave_file = FileAccess.open(path+".autosave", FileAccess.READ)
		var autosave_data = JSON.parse_string(autosave_file.get_as_text())
		# if our autosave is more recent than the last savefile, return the data
		if autosave_data["save_time"] > save_data["save_time"]:
			return autosave_data
	return false

func load_savefile(path: String, look_for_autosave: bool = true):
	var file := FileAccess.open(path, FileAccess.READ)
	user_settings["last_saveload_directory"] = path.get_base_dir()
	var save_data = JSON.parse_string(file.get_as_text())
	if (not save_data.has("pointmapper_save_version") and (not save_data.has("carto_save_version"))):
		return
	# look for autosave data. this method will only give us
	# autosave data if it exists and is more recent than the save.
	var autosave_data = get_autosave_data(path)
	if look_for_autosave and autosave_data:
		# popup our dialog and wait for its on_choice signal to continue
		# loading
		%ConfirmDialog.dialog_text = "This file has autosave data that is more recent than the last save.\n\nDo you wish to recover that save data ?"
		%ConfirmDialog.title = "Autosave data found"
		%ConfirmDialog.cancel_button_text = "No"
		%ConfirmDialog.popup()
		await %ConfirmDialog.on_choice
		if %ConfirmDialog.get_last_value() == "yes":
			save_data = autosave_data
		# cleanup the button's name
		%ConfirmDialog.cancel_button_text = "Cancel"
	current_save_path = path
	# clear gizmo selection to avoid gizmo panic when a selected item is
	# removed from the scene tree
	clear_gizmo_selection()
	CameraManager.reset()
	CameraManager.soloed_devices = []
	while num_network_outputs > 0:
		remove_network_output()
	while len(NdiManager.nodes) > 0:
		NdiManager.remove_ndi_output()
	var viewport_camera_settings = save_data.get("viewport_camera", {})
	if viewport_camera_settings == {}:
		viewport_camera_settings["camera_transform"] = save_data.get("viewport_camera_transform", false)
		viewport_camera_settings["pivot_global_position"] = SavefileUtils.serialize_vec3(Vector3.ZERO)
		viewport_camera_settings["camera_mode"] = "Perspective"
	if viewport_camera_settings["camera_transform"]:
		%FreeCamera.transform = SavefileUtils.deserialize_transform(viewport_camera_settings["camera_transform"])
		%FreeCamera.set_pivot_position(SavefileUtils.deserialize_vec3(viewport_camera_settings["pivot_global_position"]))
		select_camera_mode_from_text(viewport_camera_settings.get("camera_mode", "Perspective"))
	for network_output in save_data["network_outputs"]:
		var net_out = init_network_output()
		add_network_output(net_out)
		net_out.is_active = network_output["active"]
		net_out.set_port_and_ip(network_output["output_port"], network_output["output_ip"])
	for cam in save_data["cameras"]:
		var cam_nodes = CameraManager.initialize_camera_nodes()
		# this may happen if someone decides to put more than the max amount
		# of cameras in the json savefile.
		if cam_nodes == null:
			continue
		CameraManager.add_camera(cam_nodes)
		if cam.get("name", false):
			cam_nodes["camera"].set_camera_name(cam["name"], cam["has_default_name"])
		cam_nodes["camera"].color = SavefileUtils.deserialize_color(cam["color"])
		var centroid_pivot = SavefileUtils.deserialize_vec3(cam["centroid"])
		cam_nodes["camera"].has_centroid = cam.get("has_centroid", centroid_pivot != Vector3.ZERO)
		cam_nodes["camera"].centroid = SavefileUtils.deserialize_vec3(cam["centroid"])
		cam_nodes["camera"].set_centroid_toggled(cam["centroid_toggled"])
		cam_nodes["camera"].thinning = cam["thinning"]
		cam_nodes["camera"].point_size = cam.get("point_size", 1.0)
		var camera_transform = SavefileUtils.deserialize_transform(cam["transform"])
		cam_nodes["point_cloud"].transform = camera_transform
		cam_nodes["camera"].transform = camera_transform
		cam_nodes["camera_settings"].set_controls_to_transform(camera_transform)
		# this avoids triggering an undo/redo related transform change
		cam_nodes["point_cloud"].last_transform = cam_nodes["point_cloud"].transform
		var device_type: String = cam.get("device_type", "No type")
		var device_type_enum
		if device_type != "No type":
			device_type_enum = cam_nodes["camera"].device_str_to_enum(device_type)
		else:
			device_type_enum = cam_nodes["camera"].device_types.ORBBEC
		cam_nodes["camera_settings"].select_device_type(device_type_enum)
		if device_type.to_lower() == "no type":
			# restore orbbec config from the root
			cam_nodes["camera_settings"].select_orbbec_ip(cam["ip"])
			cam_nodes["camera_settings"].select_orbbec_fps(cam.get("fps", ""))
			cam_nodes["camera_settings"].select_orbbec_resolution(cam.get("resolution", ""))
		else:
			# restore each device type's config from their config object.
			cam_nodes["camera_settings"].select_orbbec_ip(cam["orbbec_settings"]["ip"])
			cam_nodes["camera_settings"].select_orbbec_fps(cam["orbbec_settings"]["fps"])
			cam_nodes["camera_settings"].select_orbbec_resolution(cam["orbbec_settings"]["resolution"])
			cam_nodes["camera_settings"].set_hesai_ip(cam["hesai_settings"].get("ip", "192.168.1.201"))
			cam_nodes["camera_settings"].set_hesai_port(cam["hesai_settings"].get("port", 2368))
		cam_nodes["camera"].current_device_type = device_type_enum
		cam_nodes["camera_settings"].start_device()
		cam_nodes["camera_settings"].active_state = cam.get("active_state", true)
		cam_nodes["camera"].displayed = cam.get("displayed", true)
		cam_nodes["camera"].soloed = cam.get("soloed", false)

	var ndi_outputs = save_data.get("ndi_outputs", [])
	if ndi_outputs is Dictionary:
		ToastManager.show_toast("Old NDI format in savefile. Please instanciate your desired NDI view.", "warning")
	else:
		for ndi_out in ndi_outputs:
			var ndi_out_node = NdiManager.init_ndi_output()
			NdiManager.add_ndi_output(ndi_out_node)
			ndi_out_node.current_view = int(ndi_out["current_view"])
			ndi_out_node.set_ndi_cam_from_current_view()
			ndi_out_node.toggled = ndi_out["toggled"]
	%CropRegion.transform = SavefileUtils.deserialize_transform(save_data["crop_region"]["transform"])
	# avoids triggering an undo/redo related transform change
	%CropRegion.last_transform = %CropRegion.transform
	toggle_crop_active(save_data["crop_region"]["active"])
	# update the controls and cameras related to the crop region.
	%CropRegion.update_controls()
	%CropRegion.update_cameras()
	# need to manually update the borders since we don't want the transform change to be called.
	%CropRegionContainer.update_borders(%CropRegion.transform)
	%CameraSpeedSpinBox.value = save_data.get("general_settings", {}).get("camera_speed", 4.0)
	UndoManager.empty_stack()
	last_history_count = 0
	last_undo_redo_count = 0

var last_history_count = 0
var last_undo_redo_count = 0
func has_changes_since_last_save() -> bool:
	var current_history_count = UndoManager.undoredo.get_history_count()
	if (current_history_count != last_history_count
			or last_undo_redo_count != UndoManager.undo_redo_count) :
		return true
	return false

func _on_autosave_timer_timeout() -> void:
	if has_changes_since_last_save() :
		autosave()

func _on_camera_speed_spin_box_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set cam speed",
		value,
		%FreeCamera.base_speed,
		func(val): %FreeCamera.base_speed = val,
		func(val): %CameraSpeedSpinBox.set_value_no_signal(val)
	)

func close_all_modals() -> void:
	for modal in get_tree().get_nodes_in_group("modals"):
		modal.visible = false

func _on_close_modal_window_pressed() -> void:
	close_all_modals()

func _on_shortcuts_button_pressed() -> void:
	close_all_modals()
	%ShortcutsWindow.visible = true

func _on_settings_button_pressed() -> void:
	close_all_modals()
	%SettingsWindow.visible = true

func _on_logs_button_pressed() -> void:
	close_all_modals()
	%LogsWindow.visible = true

func _on_camera_discovery_timer_timeout() -> void:
	CameraManager.update_orbbec_ip_lists()

func _on_file_popup_menu_id_pressed(id: int) -> void:
	match id:
		0:
			save_or_save_as()
		1:
			save_as()
		2:
			initiate_load()

func select_camera_mode_from_text(text:String):
	for i in range(%CameraViewMenu.item_count):
		if %CameraViewMenu.get_item_text(i) == text:
			_on_camera_view_menu_id_pressed(i)
			return
	ToastManager.show_toast("Couldn't find camera view "+ text, "warning")

func _on_camera_view_menu_id_pressed(id: int) -> void:
	%CameraViewMenu.title = %CameraViewMenu.get_item_text(id)
	match id:
		0:
			%FreeCamera.set_to_perspective()
		1:
			%FreeCamera.set_to_orthographic(%ManipulatorGizmo.axes.X, true)
		2:
			%FreeCamera.set_to_orthographic(%ManipulatorGizmo.axes.X, false)
		3:
			%FreeCamera.set_to_orthographic(%ManipulatorGizmo.axes.Z, false)
		4:
			%FreeCamera.set_to_orthographic(%ManipulatorGizmo.axes.Z, true)
		5:
			%FreeCamera.set_to_orthographic(%ManipulatorGizmo.axes.Y, false)
		6:
			%FreeCamera.set_to_orthographic(%ManipulatorGizmo.axes.Y, true)

func _on_ui_scaling_spin_box_value_changed(value: float) -> void:
	scale_ui(value)
	user_settings["ui_scaling"] = value

func _on_tracking_mode_button_toggled(toggled_on: bool) -> void:
	%CalibPointClouds.visible = not toggled_on
	%TrackingPointCloud.visible = toggled_on
	%CalibSideBarUI.visible = not toggled_on
	%TrackingSideBarUI.visible = toggled_on
	if toggled_on:
		# un-gizmo-select everything when in tracking mode
		clear_gizmo_selection()
	%CropRegionContainer.visible = not toggled_on
