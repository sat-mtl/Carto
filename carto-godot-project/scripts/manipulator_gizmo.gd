extends Control

enum axes {X=0, Y=1, Z=2}

signal coordinate_change(azimuth, elevation)
signal orthographic_requested(axis:axes, inverted:bool)

func _on_mouse_entered() -> void:
	%HighlightCircle.visible = true

func _on_mouse_exited() -> void:
	%HighlightCircle.visible = false

var x_sphere_color: Color
var y_sphere_color: Color
var z_sphere_color: Color
var x_minus_sphere_color: Color
var y_minus_sphere_color: Color
var z_minus_sphere_color: Color

func _ready() -> void:
	x_sphere_color = %XSphere.get_active_material(0).albedo_color
	y_sphere_color = %YSphere.get_active_material(0).albedo_color
	z_sphere_color = %ZSphere.get_active_material(0).albedo_color
	x_minus_sphere_color = %XMinusSphere.get_active_material(0).albedo_color
	y_minus_sphere_color = %YMinusSphere.get_active_material(0).albedo_color
	z_minus_sphere_color = %ZMinusSphere.get_active_material(0).albedo_color

var highlight_percent = 0.6

var request_axis = null
var request_inverted = null

func _on_z_sphere_area_3d_mouse_entered() -> void:
	%ZSphere.get_active_material(0).albedo_color = %ZSphere.get_active_material(0).albedo_color.lightened(highlight_percent)
	request_axis = axes.Z
	request_inverted = false

func _on_z_sphere_area_3d_mouse_exited() -> void:
	%ZSphere.get_active_material(0).albedo_color = z_sphere_color
	request_axis = null
	request_inverted = null

func _on_x_sphere_area_3d_mouse_entered() -> void:
	%XSphere.get_active_material(0).albedo_color = %XSphere.get_active_material(0).albedo_color.lightened(highlight_percent)
	request_axis = axes.X
	request_inverted = false

func _on_x_sphere_area_3d_mouse_exited() -> void:
	%XSphere.get_active_material(0).albedo_color = x_sphere_color
	request_axis = null
	request_inverted = null

func _on_y_sphere_area_3d_mouse_entered() -> void:
	%YSphere.get_active_material(0).albedo_color = %YSphere.get_active_material(0).albedo_color.lightened(highlight_percent)
	request_axis = axes.Y
	request_inverted = false

func _on_y_sphere_area_3d_mouse_exited() -> void:
	%YSphere.get_active_material(0).albedo_color = y_sphere_color
	request_axis = null
	request_inverted = null

func _on_x_minux_sphere_area_3d_mouse_entered() -> void:
	%XMinusSphere.get_active_material(0).albedo_color = %XMinusSphere.get_active_material(0).albedo_color.lightened(highlight_percent)
	request_axis = axes.X
	request_inverted = true

func _on_x_minux_sphere_area_3d_mouse_exited() -> void:
	%XMinusSphere.get_active_material(0).albedo_color = x_minus_sphere_color
	request_axis = null
	request_inverted = null

func _on_y_minus_sphere_area_3d_mouse_entered() -> void:
	%YMinusSphere.get_active_material(0).albedo_color = %YMinusSphere.get_active_material(0).albedo_color.lightened(highlight_percent)
	request_axis = axes.Y
	request_inverted = true

func _on_y_minus_sphere_area_3d_mouse_exited() -> void:
	%YMinusSphere.get_active_material(0).albedo_color = y_minus_sphere_color
	request_axis = null
	request_inverted = null

func _on_z_minus_sphere_area_3d_mouse_entered() -> void:
	%ZMinusSphere.get_active_material(0).albedo_color = %ZMinusSphere.get_active_material(0).albedo_color.lightened(highlight_percent)
	request_axis = axes.Z
	request_inverted = true

func _on_z_minus_sphere_area_3d_mouse_exited() -> void:
	%ZMinusSphere.get_active_material(0).albedo_color = z_minus_sphere_color
	request_axis = null
	request_inverted = null

# azimuth elevation
var spheric_coords = Vector3(PI/2.0, PI/2.0, 1.6)
var increment = 0.01

func set_azimuth_elevation(azimuth, elevation):
	%Camera3D.position = Vector3(
		spheric_coords[2] * sin(elevation) * cos(azimuth),
		spheric_coords[2] * cos(elevation),
		spheric_coords[2] * sin(elevation) * sin(azimuth)
	)
	#takes care of rotation when we are perfectly aligned with Vector3.UP
	%Camera3D.rotation.y -= (azimuth - spheric_coords[0])
	SpatialUtils.safe_look_at(%Camera3D, Vector3.ZERO)
	spheric_coords[0] = azimuth
	spheric_coords[1] = elevation


func move_cam(mouse_relative):
	var azimuth = spheric_coords[0] + mouse_relative[0] * increment
	var elevation = spheric_coords[1] - mouse_relative[1] * increment
	elevation = min(max(0, elevation),PI)
	set_azimuth_elevation(azimuth, elevation)
	coordinate_change.emit(spheric_coords[0], spheric_coords[1])

func _process(_delta: float) -> void:
	if not Input.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		sliding = false
	## TODO: on alt tab the gizmo highlight stays on. Probably not worth fixing this

var old_mouse_pos
var sliding = false
func _on_gui_input(event: InputEvent):
	if event.is_action_pressed("left_click"):
		old_mouse_pos = get_viewport().get_mouse_position() * get_window().content_scale_factor
		sliding = true
	elif event.is_action_released("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.warp_mouse(old_mouse_pos)
		sliding = false
		get_viewport().gui_release_focus()
		if request_axis != null and request_inverted != null:
			orthographic_requested.emit(request_axis, request_inverted)
	elif event is InputEventMouseMotion:
		%HighlightCircle.visible = true
		if sliding:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			move_cam(event.relative)
