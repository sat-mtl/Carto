extends Node3D
class_name BlobtrackDisplay

var label3ds:Array[Label3D]
var cleared = false
var tracking_mode:=true:
	set(is_it):
		tracking_mode = is_it
		cleared = false

func _init() -> void:
	for i in range(1000):
		var l3d := Label3D.new()
		add_child(l3d)
		l3d.position = Vector3.ONE * -666
		l3d.text = str(i)
		l3d.font_size = 100
		l3d.no_depth_test = true
		l3d.render_priority = 5
		l3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label3ds.append(l3d)

func clear_labels(start_idx:int = 0):
	while start_idx < 1000:
		label3ds[start_idx].position = Vector3.ONE*-666
		start_idx += 1

var last_output_ids := []

func output_blobs(blobs):
	var output_ids = []
	for blob in blobs:
		var blob_prefix := "/blob/{0}".format([blob.blob_id])
		%OSCOutput.osc_messages[blob_prefix+"/id"]=blob.blob_id
		%OSCOutput.osc_messages[blob_prefix+"/active"]=1
		%OSCOutput.osc_messages[blob_prefix+"/centroid"]=[blob.centroid.x, blob.centroid.y, blob.centroid.z]
		%OSCOutput.osc_messages[blob_prefix+"/velocity"]=[blob.velocity.x, blob.velocity.y, blob.velocity.z]
		var a := AABB()
		%OSCOutput.osc_messages[blob_prefix+"/bounding_box_origin"]=a.position
		output_ids.append(blob.blob_id)
		var last_output_idx = last_output_ids.find(blob.blob_id)
		if last_output_idx != -1:
			last_output_ids.remove_at(last_output_idx)
	for id in last_output_ids:
		var blob_prefix := "/blob/{0}".format([id])
		%OSCOutput.osc_messages[blob_prefix+"/active"]=0
	last_output_ids = output_ids


func display_blobs(blobs):
	var cnt := 0
	if tracking_mode and ComputePipelinesManager.blobtrack_active:
		for blob in blobs:
			DebugDraw.draw_box_aabb(blob.bounding_box, Color(1,1,1,1), 1)
			DebugDraw.draw_line_3d(blob.centroid, blob.centroid + blob.velocity*30, Color(1,1,1,1))
			if cnt < 1000:
				label3ds[cnt].position = blob.centroid
				label3ds[cnt].text = str(blob.blob_id)
				cnt+=1
	if (tracking_mode and ComputePipelinesManager.blobtrack_active) or not cleared:
		clear_labels(cnt)
		cleared = true
	if tracking_mode and ComputePipelinesManager.blobtrack_active:
		cleared = false

func _on_blob_track_ui_active_changed(_active) -> void:
	clear_labels()
