## This file is an "autoload" which in godot's terms means it is accessible from
## every other script.
extends Node

func serialize_vec2i(vector2i: Vector2i) -> Array:
	return [vector2i[0], vector2i[1]]

func deserialize_vec2i(vector2i_arr: Array) -> Vector2i:
	return Vector2i(vector2i_arr[0], vector2i_arr[1])

func serialize_vec3(vector3: Vector3) -> Array:
	return [vector3[0], vector3[1], vector3[2]]

func deserialize_vec3(vector3_arr: Array) -> Vector3:
	return Vector3(vector3_arr[0], vector3_arr[1], vector3_arr[2])

## this serialize transforms to a json-friendly structure that can be json
## stringified.
func serialize_transform(transform: Transform3D) -> Dictionary:
	return {
		"basis" : {
			"x": serialize_vec3(transform.basis.x),
			"y": serialize_vec3(transform.basis.y),
			"z": serialize_vec3(transform.basis.z)
		},
		"origin" : serialize_vec3(transform.origin)
	}

func deserialize_transform(transform_dict: Dictionary) -> Transform3D:
	return Transform3D(
		Basis(
			deserialize_vec3(transform_dict["basis"]["x"]),
			deserialize_vec3(transform_dict["basis"]["y"]),
			deserialize_vec3(transform_dict["basis"]["z"])),
		deserialize_vec3(transform_dict["origin"])
	)

func serialize_color(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]

func deserialize_color(color_arr: Array) -> Color:
	return Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])
