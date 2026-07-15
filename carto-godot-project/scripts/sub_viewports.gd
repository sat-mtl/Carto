extends SubViewport

@export var camera: Camera3D

func toggle(enabled: bool):
	%NDIOutput.enable_video_output = enabled
	if enabled:
		render_target_update_mode = UPDATE_ALWAYS
		%NDIViewport.render_target_update_mode = UPDATE_ALWAYS
	else:
		render_target_update_mode = UPDATE_DISABLED
		%NDIViewport.render_target_update_mode = UPDATE_DISABLED
