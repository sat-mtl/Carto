extends Node

@export var default_position: String = "BL"
@export var spacing_px: float = 10.0
@export var reduced_motion: bool = true
@export var toast_scene: PackedScene = preload("res://addons/properUI_toast/Toast.tscn")

# Per-position widths
@export var toast_widths := {
	"TL": 320.0, "T": 360.0, "TR": 320.0,
	"ML": 320.0, "C": 360.0, "MR": 320.0,
	"BL": 320.0, "B": 360.0, "BR": 320.0
}

@export var max_active := {
	"TL": 8, "T": 8, "TR": 8,
	"ML": 8, "C": 8, "MR": 8,
	"BL": 8, "B": 8, "BR": 8
}

# Insets for stack boxes (distance from edges, converted by anchor preset)
@export var stack_boxes := {
	"TL": {"left": 20.0, "right": 420.0, "top": 20.0, "bottom": 420.0},
	"T":  {"left": 420.0, "right": 420.0, "top": 20.0, "bottom": 540.0},
	"TR": {"left": 420.0, "right": 20.0, "top": 20.0, "bottom": 420.0},

	"ML": {"left": 20.0, "right": 420.0, "top": 180.0, "bottom": 180.0},
	"C":  {"left": 420.0, "right": 420.0, "top": 180.0, "bottom": 180.0},
	"MR": {"left": 420.0, "right": 20.0, "top": 180.0, "bottom": 180.0},

	"BL": {"left": 20.0, "right": 420.0, "top": 420.0, "bottom": 20.0},
	"B":  {"left": 420.0, "right": 420.0, "top": 540.0, "bottom": 20.0},
	"BR": {"left": 420.0, "right": 20.0, "top": 420.0, "bottom": 20.0}
}

var _layer: CanvasLayer
var _roots: Dictionary = {}     # key -> Control stack root
var _active: Dictionary = {}    # key -> Array[Control]
var _queue: Dictionary = {}     # key -> Array[Dictionary]
var _pending: Dictionary = {}   # key -> int (count of toasts currently spawning)

func _ready() -> void:
	# Create our drawing layer high in order
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	# Create 9 stack roots
	for p in ["TL","T","TR","ML","C","MR","BL","B","BR"]:
		_create_stack_root(p, p)
		_pending[p] = 0

func _create_stack_root(key: String, pos: String) -> void:
	var box := Control.new()
	box.name = "Stack_" + key
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(box)

	# Anchors preset by quadrant/edge
	match pos:
		"TL":
			box.anchors_preset = Control.PRESET_TOP_LEFT
		"T":
			box.anchors_preset = Control.PRESET_TOP_WIDE
		"TR":
			box.anchors_preset = Control.PRESET_TOP_RIGHT
		"ML":
			box.anchors_preset = Control.PRESET_LEFT_WIDE
		"C":
			box.anchors_preset = Control.PRESET_FULL_RECT
		"MR":
			box.anchors_preset = Control.PRESET_RIGHT_WIDE
		"BL":
			box.anchors_preset = Control.PRESET_BOTTOM_LEFT
		"B":
			box.anchors_preset = Control.PRESET_BOTTOM_WIDE
		"BR":
			box.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		_:
			box.anchors_preset = Control.PRESET_BOTTOM_RIGHT

	var cfg: Dictionary = stack_boxes.get(key, {"left": 20.0, "right": 20.0, "top": 20.0, "bottom": 20.0})

	# Convert semantic insets to offsets based on the preset
	if pos == "TL":
		box.offset_left = float(cfg.left)
		box.offset_top = float(cfg.top)
		box.offset_right = box.offset_left + 400.0
		box.offset_bottom = box.offset_top + 300.0
	elif pos == "T":
		box.offset_left = float(cfg.left)
		box.offset_right = -float(cfg.right)
		box.offset_top = float(cfg.top)
		box.offset_bottom = box.offset_top + 180.0
	elif pos == "TR":
		box.offset_left = -float(cfg.left) - 400.0
		box.offset_right = -float(cfg.right)
		box.offset_top = float(cfg.top)
		box.offset_bottom = box.offset_top + 300.0
	elif pos == "ML":
		box.offset_left = float(cfg.left)
		box.offset_right = -float(cfg.right)
		box.offset_top = float(cfg.top)
		box.offset_bottom = -float(cfg.bottom)
	elif pos == "C":
		box.offset_left = float(cfg.left)
		box.offset_right = -float(cfg.right)
		box.offset_top = float(cfg.top)
		box.offset_bottom = -float(cfg.bottom)
	elif pos == "MR":
		box.offset_left = float(cfg.left)
		box.offset_right = -float(cfg.right)
		box.offset_top = float(cfg.top)
		box.offset_bottom = -float(cfg.bottom)
	elif pos == "BL":
		box.offset_left = float(cfg.left)
		box.offset_right = box.offset_left + 400.0
		box.offset_bottom = -float(cfg.bottom)
		box.offset_top = box.offset_bottom - 300.0
	elif pos == "B":
		box.offset_left = float(cfg.left)
		box.offset_right = -float(cfg.right)
		box.offset_bottom = -float(cfg.bottom)
		box.offset_top = box.offset_bottom - 180.0
	elif pos == "BR":
		box.offset_left = -float(cfg.left) - 400.0
		box.offset_right = -float(cfg.right)
		box.offset_bottom = -float(cfg.bottom)
		box.offset_top = box.offset_bottom - 300.0

	_roots[key] = box
	_active[key] = []
	_queue[key] = []

func show_toast(text: String, kind: String = "info", opts: Dictionary = {}, position: String = "") -> void:
	var log_level:LogManager.log_level

	match kind:
		"warning":
			log_level = LogManager.log_level.WARNING
		"error":
			log_level = LogManager.log_level.ERROR
		"success":
			log_level = LogManager.log_level.SUCCESS
		_:
			log_level = LogManager.log_level.INFO

	LogManager.add_to_log(text, log_level)

	var key: String = position if position != "" else default_position
	if not _roots.has(key):
		push_warning("ProperUIToast: unknown position '%s', using default '%s'" % [key, default_position])
		key = default_position

	opts["reduced_motion"] = bool(opts.get("reduced_motion", reduced_motion))

	var active_count: int = (_active[key] as Array).size()
	var pending_count: int = _pending.get(key, 0)

	if active_count + pending_count < int(max_active.get(key, 3)):
		_pending[key] = pending_count + 1
		await _spawn_and_show_in(key, text, kind, opts)
		_pending[key] = max(0, _pending[key] - 1)
	else:
		_queue[key].append({ "text": text, "kind": kind, "opts": opts })

func clear_all() -> void:
	for key in _active.keys():
		for t in (_active[key] as Array).duplicate():
			if is_instance_valid(t):
				t.call("dismiss")
		_active[key].clear()
		for c in (_roots[key] as Control).get_children():
			if is_instance_valid(c):
				c.queue_free()
		_queue[key].clear()

func _spawn_and_show_in(key: String, text: String, kind: String, opts: Dictionary) -> void:
	var root: Control = _roots[key]
	var toast: Control = toast_scene.instantiate() as Control
	root.add_child(toast)

	# Enforce column width per position
	var w: float = float(toast_widths.get(key, 320.0))
	if toast.has_method("set_width"):
		toast.call("set_width", w)
	else:
		toast.custom_minimum_size.x = w
		toast.size.x = w

	toast.call("setup", text, kind, opts)
	# Ensure sizes are computed
	await get_tree().process_frame

	if toast.has_signal("dismissed"):
		toast.connect("dismissed", Callable(self, "_on_toast_dismissed").bind(key, toast))

	_active[key].append(toast)
	_place_and_animate(key, toast)

func _on_toast_dismissed(key: String, toast: Control) -> void:
	_active[key].erase(toast)
	_place_and_animate(key, null)
	_promote_from_queue(key)

func _promote_from_queue(key: String) -> void:
	while (_active[key] as Array).size() + _pending.get(key, 0) < int(max_active.get(key, 3)) and (_queue[key] as Array).size() > 0:
		var next: Dictionary = _queue[key].pop_front()
		_pending[key] = _pending.get(key, 0) + 1
		await _spawn_and_show_in(key, next.text, next.kind, next.opts)
		_pending[key] = max(0, _pending[key] - 1)

func _place_and_animate(key: String, animated_in_toast: Control) -> void:
	var root: Control = _roots[key]
	var rect: Rect2 = root.get_rect()
	var area_w: float = rect.size.x
	var area_h: float = rect.size.y

	var align_right: bool = key == "TR" or key == "MR" or key == "BR"
	var align_left: bool = key == "TL" or key == "ML" or key == "BL"
	var align_center_x: bool = key == "T" or key == "C" or key == "B"

	var stack_from_bottom: bool = key == "BL" or key == "B" or key == "BR"
	var stack_from_top: bool = key == "TL" or key == "T" or key == "TR"
	var stack_center_y: bool = key == "ML" or key == "C" or key == "MR"

	var y: float = 0.0
	if stack_from_bottom:
		y = area_h
	elif stack_center_y:
		y = area_h * 0.5
	else:
		y = 0.0

	for i in range((_active[key] as Array).size() - 1, -1, -1):
		var t: Control = _active[key][i]
		if not is_instance_valid(t):
			continue

		var w: float = t.size.x
		if w <= 1.0:
			w = float(toast_widths.get(key, 320.0))

		if align_right:
			t.position.x = area_w - w
		elif align_left:
			t.position.x = 0.0
		elif align_center_x:
			t.position.x = (area_w - w) * 0.5

		var h: float = t.size.y
		if h <= 1.0:
			h = max(t.get_minimum_size().y, 48.0)

		var target_y: float = 0.0
		if stack_from_bottom:
			y -= h
			target_y = y
			y -= spacing_px
		elif stack_center_y:
			var baseline: float = area_h * 0.5
			target_y = baseline
			for j in range(i + 1, (_active[key] as Array).size()):
				var tj: Control = _active[key][j]
				if is_instance_valid(tj):
					var hj: float = tj.size.y
					if hj <= 1.0:
						hj = max(tj.get_minimum_size().y, 48.0)
					target_y -= (hj + spacing_px)
		else:
			target_y = y
			y += h + spacing_px

		if t == animated_in_toast:
			if t.has_method("place_immediately"):
				t.call("place_immediately", target_y)
			if t.has_method("animate_in_to"):
				t.call("animate_in_to", target_y)
		else:
			if t.has_method("move_to"):
				t.call("move_to", target_y)

	for i in range((_active[key] as Array).size()):
		var node: Control = _active[key][i]
		if is_instance_valid(node):
			node.z_index = i + 1
			node.move_to_front()
