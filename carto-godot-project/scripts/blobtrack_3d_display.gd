extends Node3D
class_name BlobtrackDisplay
var label3ds:Array[Label3D]

func _init() -> void:
	for i in range(1000):
		var l3d = Label3D.new()
		add_child(l3d)
		l3d.position = Vector3.ONE * -666
		l3d.text = str(i)
		l3d.font_size = 100
		label3ds.append(l3d)
		l3d.billboard = true

func display_blobs(blobs):
	var cnt := 0
	for blob in blobs:
		DebugDraw.draw_box_aabb(blob.bounding_box, Color(1,1,1,1))
		DebugDraw.draw_line_3d(blob.centroid, blob.centroid + blob.velocity*3, Color(1,1,1,1))
		if cnt < 1000:
			label3ds[cnt].position = blob.centroid
			label3ds[cnt].text = str(blob.blob_id)
			cnt+=1
	while cnt < %BlobTrack3D.max_blobs:
		label3ds[cnt].position = Vector3.ONE*-666
		cnt += 1
