extends MarginContainer
signal active_changed(active)
@export var blobtrack_node : Blobtrack3D:
	set(blobtrack):
		blobtrack_node = blobtrack
		%SmoothingHSlider.set_value_no_signal(blobtrack_node.smoothing)
		%ClusterDistanceSpinBox.set_value_no_signal(blobtrack_node.cluster_dist)
		%ClusterMinPointsSpinBox.set_value_no_signal(blobtrack_node.min_points)
		%MaxBlobsSpinBox.set_value_no_signal(blobtrack_node.max_blobs)
		%MaxDetectionAgeSpinBox.set_value_no_signal(blobtrack_node.max_age)
		%MinHitsSpinBox.set_value_no_signal(blobtrack_node.min_hits)
		%UsePointCountToggle.set_pressed_no_signal(blobtrack.use_point_count)
		%PointCountWeightHSlider.set_value_no_signal(blobtrack.point_count_weight)
		%ActiveToggle.set_pressed_no_signal(ComputePipelinesManager.blobtrack_active)
		active_changed.emit(ComputePipelinesManager.blobtrack_active)
var id := 0

func _on_point_count_weight_h_slider_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_point_count_weight blobtrack " + str(id),
		value,
		blobtrack_node.point_count_weight,
		func(val): blobtrack_node.point_count_weight = val,
		func(val): %PointCountWeightHSlider.set_value_no_signal(val)
	)

func _on_use_point_count_toggle_toggled(toggled_on: bool) -> void:
	UndoManager.add_to_stack(
		"use_point_count blobtrack " + str(id),
		func():
			%UsePointCountToggle.set_pressed_no_signal(toggled_on)
			blobtrack_node.use_point_count = toggled_on,
		func():
			%UsePointCountToggle.set_pressed_no_signal(!toggled_on)
			blobtrack_node.use_point_count = !toggled_on
	)

func _on_merge_memory_spin_box_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_merge_memory blobtrack " + str(id),
		value,
		blobtrack_node.merge_memory_frames,
		func(val): blobtrack_node.merge_memory_frames = val,
		func(val): %MergeMemorySpinBox.set_value_no_signal(val)
	)

func _on_min_hits_spin_box_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_min_hits blobtrack " + str(id),
		value,
		blobtrack_node.min_hits,
		func(val): blobtrack_node.min_hits = val,
		func(val): %MinHitsSpinBox.set_value_no_signal(val)
	)

func _on_max_detection_age_spin_box_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_max_age blobtrack " + str(id),
		value,
		blobtrack_node.max_age,
		func(val): blobtrack_node.max_age = val,
		func(val): %MaxDetectionAgeSpinBox.set_value_no_signal(val)
	)

func _on_max_blobs_spin_box_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_max_blobs blobtrack " + str(id),
		value,
		blobtrack_node.max_blobs,
		func(val): blobtrack_node.max_blobs = val,
		func(val): %MaxBlobsSpinBox.set_value_no_signal(val)
	)

func _on_cluster_min_points_spin_box_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_min_points blobtrack " + str(id),
		value,
		blobtrack_node.min_points,
		func(val): blobtrack_node.min_points = val,
		func(val): %ClusterMinPointsSpinBox.set_value_no_signal(val)
	)

func _on_cluster_distance_spin_box_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set_cluster_dist blobtrack " + str(id),
		value,
		blobtrack_node.cluster_dist,
		func(val): blobtrack_node.cluster_dist = val,
		func(val): %ClusterDistanceSpinBox.set_value_no_signal(val)
	)

func _on_smoothing_h_slider_value_changed(value: float) -> void:
	UndoManager.add_property_change_to_stack(
		"set smoothing blobtrack " + str(id),
		value,
		blobtrack_node.smoothing,
		func(val): blobtrack_node.smoothing = val,
		func(val): %SmoothingHSlider.set_value_no_signal(val)
	)

# manages the unique global blobtrack in computepipelinemanager for now
func _on_active_toggle_toggled(toggled_on: bool) -> void:
	UndoManager.add_to_stack(
		"set active blobtrack " + str(id),
		func():
			%ActiveToggle.set_pressed_no_signal(toggled_on)
			active_changed.emit(toggled_on)
			ComputePipelinesManager.blobtrack_active = toggled_on,
		func():
			%ActiveToggle.set_pressed_no_signal(!toggled_on)
			active_changed.emit(toggled_on)
			ComputePipelinesManager.blobtrack_active = !toggled_on
	)
