extends PanelContainer

signal dismissed
signal action_invoked(name: String)

const DEFAULT_DISPLAY_SEC: float = 6.0
const DEFAULT_FADE_SEC: float = 0.20
const DEFAULT_SLIDE_PX: float = 56.0

enum Kind { SUCCESS, INFO, WARNING, ERROR }

var message_label: Label
var icon_label: Label
var primary_button: Button
var secondary_button: Button
var actions_box: HBoxContainer
var dismiss_button: Button

var kind: Kind = Kind.INFO
var persistent: bool = false

var _tween: Tween
var _timer: Timer
var _is_hovered: bool = false
var _target_y: float = 0.0
var _display_sec: float = DEFAULT_DISPLAY_SEC
var _fade_sec: float = DEFAULT_FADE_SEC
var _slide_px: float = DEFAULT_SLIDE_PX
var _reduced_motion: bool = true
var _is_in_queue: bool = false
var _aria_role: String = "status" # "status" for info/success, "alert" for warning/error
var _action_name_primary: String = ""
var _action_name_secondary: String = ""

func _ready() -> void:
	message_label = get_node("Margin/HBox/Content/Message") as Label
	actions_box = get_node("Margin/HBox/Content/Actions") as HBoxContainer
	primary_button = get_node("Margin/HBox/Content/Actions/ActionButton") as Button
	secondary_button = get_node("Margin/HBox/Content/Actions/SecondaryActionButton") as Button
	dismiss_button = get_node("Margin/HBox/Dismiss") as Button

	# Don’t steal clicks, but allow keyboard focus to support Esc/Enter.
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	primary_button.pressed.connect(func(): _emit_action(_action_name_primary))
	secondary_button.pressed.connect(func(): _emit_action(_action_name_secondary))
	dismiss_button.pressed.connect(func(): dismiss())

	# Accessibility hints (theme-agnostic)
	_update_accessibility()

	visible = false
	modulate = Color(1, 1, 1, 1)

func setup(text: String, type: String = "info", opts: Dictionary = {}) -> void:
	if not message_label or not %IconTextureRect:
		return

	_display_sec = float(opts.get("display_sec", DEFAULT_DISPLAY_SEC))
	_fade_sec = float(opts.get("fade_sec", DEFAULT_FADE_SEC))
	_slide_px = float(opts.get("slide_px", DEFAULT_SLIDE_PX))
	_reduced_motion = bool(opts.get("reduced_motion", true))
	persistent = bool(opts.get("persistent", false))

	# Action API:
	# opts.action = {"text": "Undo", "name": "undo"}     # primary
	# opts.secondary_action = {"text": "View", "name": "view"} # optional secondary
	_configure_actions(opts)

	# Label behavior
	message_label.text = text
	message_label.clip_text = false
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.max_lines_visible = int(opts.get("max_lines", 3))
	_set_kind_from_string(type)
	_set_aria_role_for_kind()

	# Dismiss affordance
	dismiss_button.visible = bool(opts.get("show_dismiss", true))

	# RTL mirroring support: respect project/parent layout
	layout_direction = int(opts.get("layout_direction", Control.LAYOUT_DIRECTION_INHERITED))

	position.y = _target_y + (0.0 if _reduced_motion else _slide_px)

func set_width(w: float) -> void:
	custom_minimum_size.x = w
	size.x = w

func set_queued(queued: bool) -> void:
	_is_in_queue = queued
	if queued:
		_pause_timer()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS

func place_immediately(y: float) -> void:
	_target_y = y
	position.y = y + (0.0 if _reduced_motion else _slide_px)

func animate_in_to(y: float) -> void:
	_target_y = y
	_kill_tween()
	visible = true

	if _reduced_motion:
		position.y = _target_y
	else:
		_tween = create_tween()
		_tween.tween_property(self, "position:y", _target_y, _fade_sec) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_start_timer_if_needed()

func move_to(y: float) -> void:
	_target_y = y
	_kill_tween()
	var t: Tween = create_tween()
	t.tween_property(self, "position:y", _target_y, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func dismiss() -> void:
	if not is_inside_tree():
		return
	_animate_out(true)

func _animate_out(force: bool = true) -> void:
	_kill_tween()
	if not force and (_is_hovered or persistent or _is_in_queue):
		if not persistent and not _is_in_queue:
			_timer.wait_time = 0.25
			_timer.start()
		return

	if _reduced_motion:
		_cleanup_and_emit()
		return

	_tween = create_tween()
	_tween.tween_property(self, "position:y", _target_y + _slide_px, _fade_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_cleanup_and_emit)

func _cleanup_and_emit() -> void:
	visible = false
	if is_inside_tree():
		queue_free()
	emit_signal("dismissed")

func _start_timer_if_needed() -> void:
	if persistent or _is_in_queue:
		return
	# Severity-based durations (readable and short-by-default)
	var min_read: float = 0.5
	if kind == Kind.WARNING:
		_timer.wait_time = max(min_read, max(_display_sec, 4.0))
	elif kind == Kind.ERROR:
		_timer.wait_time = max(min_read, max(_display_sec, 5.0))
	else:
		_timer.wait_time = max(min_read, _display_sec)
	_timer.start()

func _pause_timer() -> void:
	if _timer and not _timer.is_stopped():
		_timer.paused = true

func _resume_timer_if_needed() -> void:
	if _timer and not _timer.is_stopped():
		_timer.paused = false

func _on_timer_timeout() -> void:
	_animate_out()

func _on_mouse_entered() -> void:
	_is_hovered = true
	_pause_timer()

func _on_mouse_exited() -> void:
	_is_hovered = false
	if not persistent and not _is_in_queue:
		_resume_timer_if_needed()

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null

func _set_kind_from_string(type_str: String) -> void:
	match type_str.to_lower():
		"success":
			_set_kind(Kind.SUCCESS)
		"warning":
			_set_kind(Kind.WARNING)
		"error":
			_set_kind(Kind.ERROR)
		_:
			_set_kind(Kind.INFO)

func _set_kind(value: Kind) -> void:
	kind = value
	_apply_visuals_for_kind()

var info_tex = preload("res://assets/Info.svg")
var warning_tex = preload("res://assets/StatusWarning.svg")
var error_tex = preload("res://assets/StatusError.svg")
var success_tex = preload("res://assets/StatusSuccess.svg")
func _apply_visuals_for_kind() -> void:
	var style := get_theme_stylebox("panel", "PanelContainer")
	var icon_tex: DPITexture

	if style is StyleBoxFlat:
		var sb := style.duplicate() as StyleBoxFlat
		var border := Color(0.40, 0.60, 1.00, 1.00)
		var shadow_size := 8
		var shadow_color := Color(0, 0, 0, 0.18)

		match kind:
			Kind.SUCCESS:
				border = Color(0.20, 0.75, 0.35, 1.00)
				icon_tex = success_tex
			Kind.WARNING:
				border = Color(1.00, 0.75, 0.30, 1.00)
				icon_tex = warning_tex
			Kind.ERROR:
				border = Color(1.00, 0.40, 0.40, 1.00)
				icon_tex = error_tex
			_:
				# Kind.INFO and fallback
				border = Color(0.40, 0.60, 1.00, 1.00)
				icon_tex = info_tex


		sb.border_color = border
		# Subtle translucency and elevation
		var bg := sb.bg_color
		sb.bg_color = Color(bg.r, bg.g, bg.b, min(bg.a, 0.95))
		sb.shadow_size = shadow_size
		sb.shadow_color = shadow_color
		add_theme_stylebox_override("panel", sb)

	if %IconTextureRect:
		%IconTextureRect.texture = icon_tex

func _configure_actions(opts: Dictionary) -> void:
	var act = opts.get("action", null)
	var sec = opts.get("secondary_action", null)

	# Primary
	if act is Dictionary and act.has("text"):
		_action_name_primary = String(act.get("name", "primary"))
		primary_button.text = String(act.get("text", ""))
		primary_button.visible = true
	else:
		primary_button.visible = false
		_action_name_primary = ""

	# Secondary (minimal prominence)
	if sec is Dictionary and sec.has("text"):
		_action_name_secondary = String(sec.get("name", "secondary"))
		secondary_button.text = String(sec.get("text", ""))
		secondary_button.visible = true
	else:
		secondary_button.visible = false
		_action_name_secondary = ""

	actions_box.visible = primary_button.visible or secondary_button.visible

func _emit_action(name: String) -> void:
	if name == "":
		return
	emit_signal("action_invoked", name)
	# Immediate dismiss if action is safe and directly related
	dismiss()

func _unhandled_key_input(event: InputEvent) -> void:
	# Do not steal focus: only react if focused or mouse is over
	if not has_focus() and not _is_hovered:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel"): # Esc
			dismiss()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept") and primary_button.visible: # Enter/Space
			_emit_action(_action_name_primary)
			get_viewport().set_input_as_handled()

func _update_accessibility() -> void:
	# Godot doesn't have ARIA, but we can hint via tooltip and names
	tooltip_text = "" # avoid duplicate OS tooltips on hover
	# Expose concise descriptions for AT via accessible_name (Godot 4.3+)
	if has_method("set_accessible_name"):
		var heading := ""
		match kind:
			Kind.SUCCESS: heading = "Success"
			Kind.INFO: heading = "Information"
			Kind.WARNING: heading = "Warning"
			Kind.ERROR: heading = "Error"
		var msg := message_label.text if message_label else ""
		var action := ""
		if primary_button.visible:
			action = " Action: %s." % primary_button.text
		call_deferred("set_accessible_name", "%s toast. %s.%s" % [heading, msg, action])

func _set_aria_role_for_kind() -> void:
	_aria_role = "status"
	if kind == Kind.WARNING or kind == Kind.ERROR:
		_aria_role = "alert"
