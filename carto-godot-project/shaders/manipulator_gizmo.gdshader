shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec4 tex = texture(TEXTURE ,UV);
	vec2 uv = vec2(UV.x*2.0-1.0, UV.y*2.0-1.0);
	if (uv.x*uv.x + uv.y*uv.y < 1.0) {
		COLOR = vec4(1.0,1.0,1.0, 0.2);
	} else {
		COLOR = vec4(0.0,0.0,0.0, 0.0);
	}
	//COLOR = vec4(1.0,0.0,0.0,0.2);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
