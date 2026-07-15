# thanks https://github.com/adamviola/simple-free-look-camera/blob/master/camera.gd
extends Camera3D

# Modifier keys' speed multiplier
const SHIFT_MULTIPLIER = 2.5
const ALT_MULTIPLIER = 1.0 / SHIFT_MULTIPLIER


var right_click_sensitivity: float = 0.4
var left_click_sensitivity: float = 0.15

# Mouse state
var _mouse_impulse = Vector2(0.0, 0.0)

# Movement state
var _direction = Vector3(0.0, 0.0, 0.0)
var _velocity = Vector3(0.0, 0.0, 0.0)
var _acceleration = 30
var _deceleration = -30
var base_speed = 4

# Keyboard state
var _w = false
var _s = false
var _a = false
var _d = false
var _q = false
var _e = false
var _shift = false
var _alt = false

# Mouse state
var _right_click_pressed = false
var _left_click_pressed = false

var init_transform: Transform3D

# azimuth/elevation/distance with respect to the FreeCameraPivot
var spheric_coords: Vector3

func get_spheric_coords():
	var distance_from_pivot = position.distance_to(%FreeCameraPivot.global_position)
	var pos_relative_to_pivot = position - %FreeCameraPivot.global_position
	var x = pos_relative_to_pivot[0]
	var y = pos_relative_to_pivot[1]
	var z = pos_relative_to_pivot[2]
	var elev = acos(y/distance_from_pivot)
	var azi = atan2(z, x)
	return Vector3(azi,elev, distance_from_pivot)

## sets the pivot position and ensures the camera stays coherently aligned with it.
## also recomputes the spheric coordinates in accordance with the new position.
func set_pivot_position(pivot_pos):
	%FreeCameraPivot.global_position = pivot_pos
	spheric_coords = get_spheric_coords()
	%ManipulatorGizmo.set_azimuth_elevation(spheric_coords[0], spheric_coords[1])
	SpatialUtils.safe_look_at(self, %FreeCameraPivot.global_position)
	%FreeCameraPivot.global_position = pivot_pos


func _ready() -> void:
	init_transform = transform
	# initialise free camera pivot to an arbitrary position that works well with the default
	set_pivot_position(Vector3(4,0,2))

func reset_position():
	transform = init_transform
	set_pivot_position(Vector3(4,0,2))

var inhibit_motion = false
var last_frame_time = 0
func _process(delta):
	last_frame_time = delta
	# reset the key state in case we missed the keyup event
	if not Input.is_key_pressed(KEY_W):
		_w = false
	if not Input.is_key_pressed(KEY_A):
		_a = false
	if not Input.is_key_pressed(KEY_S):
		_s = false
	if not Input.is_key_pressed(KEY_D):
		_d = false
	if not Input.is_key_pressed(KEY_Q):
		_q = false
	if not Input.is_key_pressed(KEY_E):
		_e = false
	if not Input.is_key_pressed(KEY_SHIFT):
		_shift = false
	if not Input.is_key_pressed(KEY_ALT):
		_alt = false

const max_zoom_val := 2.0
const min_zoom_val := 0.07
const zoom_proportion := 0.06
const min_zoom_distance := 0.1

func zoom(direction):
	var zoom_val = spheric_coords[2] * zoom_proportion
	zoom_val = min(max_zoom_val, zoom_val)
	zoom_val = max(min_zoom_val, zoom_val)
	spheric_coords[2] = max(min_zoom_distance, spheric_coords[2] + zoom_val * direction)
	set_azimuth_elevation(spheric_coords[0], spheric_coords[1])
	if projection == PROJECTION_ORTHOGONAL:
		size = spheric_coords[2]

func process_input(event: InputEvent):
	if event is InputEventMouseButton:
		if (event.button_index != MOUSE_BUTTON_WHEEL_DOWN and
				event.button_index != MOUSE_BUTTON_WHEEL_LEFT and
				event.button_index != MOUSE_BUTTON_WHEEL_RIGHT and
				event.button_index != MOUSE_BUTTON_WHEEL_UP):
			get_viewport().gui_release_focus()
			get_tree().get_root().get_node("Carto").should_forward = true
	if get_viewport().gui_get_focus_owner() != null:
		return
	# don't move the camera while control is held to avoid moving while
	# entering shortcuts.
	if event.ctrl_pressed:
		return
	if not current:
		return
	if %Gizmo3D.editing:
		return
	# Receives mouse motion
	if event is InputEventMouseMotion and not inhibit_motion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		# tries to avoid janky behaviours with big lags.
		if last_frame_time > 0.1 and event.relative.length() >= 250:
			return
		_mouse_impulse += event.relative

	# Receives mouse button input
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT: # Only allows rotation if right click down
				_right_click_pressed = event.pressed
			MOUSE_BUTTON_LEFT:
				_left_click_pressed = event.pressed
			MOUSE_BUTTON_WHEEL_DOWN:
				# prevent zoom in/out when
				# editing a value in the gui
				zoom(1)
			MOUSE_BUTTON_WHEEL_UP:
				zoom(-1)
	elif event is InputEventPanGesture:
		zoom(event.delta.y)

	# Receives key input
	if event is InputEventKey and not event.alt_pressed:
		match event.keycode:
			KEY_W:
				_w = event.pressed
			KEY_S:
				_s = event.pressed
			KEY_A:
				_a = event.pressed
			KEY_D:
				_d = event.pressed
			KEY_Q:
				_q = event.pressed
			KEY_E:
				_e = event.pressed
			KEY_SHIFT:
				_shift = event.pressed
			KEY_ALT:
				_alt = event.pressed
			KEY_R:
				reset_position()

func _unhandled_input(event: InputEvent):
	process_input(event)

# Updates mouselook and movement every frame
func _physics_process(delta: float) -> void:
	if not _left_click_pressed and not _right_click_pressed:
		_mouse_impulse = Vector2.ZERO
	_update_mouselook()
	_update_movement(delta)

# Updates camera movement
func _update_movement(delta):
	# Computes desired direction from key states
	_direction = Vector3(
		(_d as float) - (_a as float),
		(_e as float) - (_q as float),
		(_s as float) - (_w as float)
	)
	# Computes the change in velocity due to desired direction and "drag"
	# The "drag" is a constant acceleration on the camera to bring it's velocity to 0
	var offset = _direction.normalized() * _acceleration * base_speed * delta \
		+ _velocity.normalized() * _deceleration * base_speed * delta

	if _right_click_pressed:
		_mouse_impulse *= right_click_sensitivity
		offset.x += _mouse_impulse[0]
		offset.y -= _mouse_impulse[1]
	_mouse_impulse *= 0.8

	if abs(_mouse_impulse.length()) < 0.3:
		_mouse_impulse = Vector2.ZERO
	# Compute modifiers' speed multiplier
	var speed_multi = 1
	if _shift: speed_multi *= SHIFT_MULTIPLIER
	if _alt: speed_multi *= ALT_MULTIPLIER

	# Checks if we should bother translating the camera
	if (_direction == Vector3.ZERO and _mouse_impulse == Vector2.ZERO) and offset.length_squared() > _velocity.length_squared():
		# Sets the velocity to 0 to prevent jittering due to imperfect deceleration
		_velocity = Vector3.ZERO
	elif _mouse_impulse == Vector2.ZERO:
		# Clamps speed to stay within maximum value (base_speed)
		_velocity.x = clamp(_velocity.x + offset.x, -base_speed, base_speed)
		_velocity.y = clamp(_velocity.y + offset.y, -base_speed, base_speed)
		_velocity.z = clamp(_velocity.z + offset.z, -base_speed, base_speed)
	else:
		_velocity.x = clamp(_velocity.x + offset.x, -base_speed*4, base_speed*4)
		_velocity.y = clamp(_velocity.y + offset.y, -base_speed*4, base_speed*4)
		_velocity.z = clamp(_velocity.z + offset.z, -base_speed*4, base_speed*4)


	translate(_velocity * delta * speed_multi)

# Updates mouse look
func _update_mouselook():
	# Only rotates mouse if the mouse is captured
	if _left_click_pressed and projection == PROJECTION_PERSPECTIVE:
		_mouse_impulse *= left_click_sensitivity
		var yaw = _mouse_impulse.x
		var pitch = _mouse_impulse.y * -0.018
		# adding a small offset to -PI/2 and PI/2 gets around an annoying edge case in
		# the lookat function that makes the manipulator gizmo suddenly rotate when reaching -90/90 degrees.
		# there is probably a better fix but this does the job.
		var new_pitch = clamp(rotation.x + pitch, -PI/2 + 0.0001, PI/2 - 0.0001)

		rotate_y(deg_to_rad(-yaw))
		rotation.x = new_pitch
		spheric_coords = get_spheric_coords()
		# need to set new azimuth and elevation on the manipulator gizmo to account
		# for the new rotation.
		%ManipulatorGizmo.set_azimuth_elevation(spheric_coords[0], spheric_coords[1])

# rotates the camera around its pivot.
func set_azimuth_elevation(azimuth, elevation):
	var pivot_pos = %FreeCameraPivot.global_position
	position = Vector3(
		spheric_coords[2] * sin(elevation) * cos(azimuth),
		spheric_coords[2] * cos(elevation),
		spheric_coords[2] * sin(elevation) * sin(azimuth)
	) + %FreeCameraPivot.global_position
	rotation.y -= (azimuth - spheric_coords[0])
	SpatialUtils.safe_look_at(self, pivot_pos)
	%FreeCameraPivot.global_position = pivot_pos
	spheric_coords[0] = azimuth
	spheric_coords[1] = elevation

func _on_manipulator_gizmo_coordinate_change(azimuth: Variant, elevation: Variant) -> void:
	set_to_perspective()
	set_azimuth_elevation(azimuth, elevation)

func set_to_perspective():
	projection = Camera3D.PROJECTION_PERSPECTIVE
	%CameraViewMenu.set_to_perspective()

func set_to_orthographic(axis, inverted):
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = spheric_coords[2]
	var azi = PI/2.0
	var elev = PI/2.0
	if axis == %ManipulatorGizmo.axes.X:
		if inverted:
			azi = PI
		else:
			azi = 0
	elif axis == %ManipulatorGizmo.axes.Y:
		if inverted:
			# sidesteps a weird look-at issue
			elev = PI-0.0001
		else:
			# same as above comment.
			elev = 0.0001
	elif axis == %ManipulatorGizmo.axes.Z:
		if inverted:
			azi = 3*PI/2.0
		else:
			azi = PI/2.0
	set_azimuth_elevation(azi, elev)
	%ManipulatorGizmo.set_azimuth_elevation(spheric_coords[0], spheric_coords[1])

func _on_manipulator_gizmo_orthographic_requested(axis: int, inverted: bool) -> void:
	set_to_orthographic(axis, inverted)
