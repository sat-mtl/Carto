extends Camera3D
@export
var ndi_stream_name: String
var render_quad: MeshInstance3D = null
## The material used to produce the final image.
var mat := ShaderMaterial.new()

## returns the texture that is going to be sent as NDI output
## the texture does not have the binarizing shader so you'll have to apply
## it as a shader material.
func get_ndi_texture():
	return %SubViewport.get_texture()

func _ready() -> void:
	%NDIOutput.name = ndi_stream_name
	%TextureRect.texture = %SubViewport.get_texture()

const min_zoom_level := 1.0
const max_zoom_level := 10.0
var current_zoom_level := 0.0
var curr_x_size = 1
var curr_y_size = 1
func set_viewport_ratio(x_size:float, y_size:float):
	curr_x_size = x_size
	curr_y_size = y_size
	if x_size > y_size:
		var x_pix = 1920
		var y_pix = int(1920 * (y_size/x_size))
		%NDIViewport.size = Vector2i(x_pix, y_pix)
		%SubViewport.size = Vector2i(x_pix, y_pix)
	elif y_size > x_size:
		var y_pix = 1920
		var x_pix = int(1920 * (x_size/y_size))
		%NDIViewport.size = Vector2i(x_pix, y_pix)
		%SubViewport.size = Vector2i(x_pix, y_pix)
	else:
		%NDIViewport.size = Vector2i(1920, 1920)
		%SubViewport.size = Vector2i(1920, 1920)

func _process(_delta: float) -> void:
	%NDICamera.global_transform = global_transform
	var current_zoom_factor = (current_zoom_level*(max_zoom_level - min_zoom_level)) + min_zoom_level
	%NDICamera.size = size / current_zoom_factor
	%NDICamera.size /= ((max(curr_y_size, curr_x_size)/min(curr_x_size, curr_y_size)))

func toggle(toggled: bool):
	%SubViewport.toggle(toggled)

func set_ndi_zoom(zoom_level:float):
	current_zoom_level = zoom_level

#For future use
func set_stream_name(nm:String):
	ndi_stream_name = nm
	%NDIOutput.name = ndi_stream_name
