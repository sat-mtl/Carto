#[compute]
#version 450

#include "point_cloud_shader_commons.glsl.inc"

// the transform buffers layouts are as follow:
// [ t1.x.x, t1.x.y, t1.x.z, t1.y.x, t1.y.y, t1.y.z, t1.z.x, t1.z.y, t1.z.z, t1.origin.x, t1.origin.y, t1.origin.z,
//   t2.x.x, t2.x.y, t2.x.z, t2.y.x, t2.y.y, t2.y.z, t2.z.x, t2.z.y, t2.z.z, t2.origin.x, t2.origin.y, t2.origin.z, ...]
// so 12 floats per elements.
layout(set = 0, binding = 3, std430) buffer FilterTransforms {
  float data[];
} filter_transforms_buffer;

// the filter_settings_buffer is layout like so :  [filter_1_shape, filter_1_mode, filter_2 shape, filter_2_mode, ...]
layout(set = 0, binding = 4, std430) buffer FilterSettings {
  int data[];
} filter_settings_buffer;

// The point_cloud_buffer is [p_c_1.1.x, p_c_1.1.y, p_c_1.1.z, p_c_1.2.x ..., p_c_2.1.x, p_c_2.1.y, p_c_2.1.z, ...]
// so three coordinates per points.
layout(set = 0, binding = 5, std430) buffer PointCloud {
  float data[];
} point_cloud_buffer;

// buffer of the multimesh instance transforms
layout(set = 0, binding = 6, std430) buffer MultimeshBuffer {
  float data[];
} multimesh_buffer;

// thinning mask buffer
layout(set = 0, binding = 7, std430) buffer ThinningMask {
  float data[];
} thinning_mask_buffer;

layout(push_constant) uniform Parameters {
  // size of the point cloud buffer in floats
  int point_cloud_buffer_size;
  // number of filters that we are processing the point cloud with
  int num_filters;
  // number of fields per elements (point cloud or filter) in the transform buffers
  int transforms_num_fields;
  // number of fields per elements in the filter settings buffer.
  int filter_settings_num_fields;
  // max number of points
  int max_points;
  // device type for pre-processing
  int device_type;
  // index of this device used for indexing the global filtered buffers.
  int device_idx;
  // size of the thinning mask
  int thinning_mask_size;
  // current thinning percentage
  float thinning;
  // godot transform of the point cloud
  float pt_cloud_transform_x_x;
  float pt_cloud_transform_x_y;
  float pt_cloud_transform_x_z;
  float pt_cloud_transform_y_x;
  float pt_cloud_transform_y_y;
  float pt_cloud_transform_y_z;
  float pt_cloud_transform_z_x;
  float pt_cloud_transform_z_y;
  float pt_cloud_transform_z_z;
  float pt_cloud_transform_x;
  float pt_cloud_transform_y;
  float pt_cloud_transform_z;
} params;

// x y and z's indexes in the multimesh transform buffer
const int x_idx = 3;
const int y_idx = 7;
const int z_idx = 11;
const int num_floats_per_multimesh_point = 12;

// Thanks IQ for the signed distance functions : https://iquilezles.org/articles/distfunctions/

// Notes on signed distance functions. These give you the distance between a point and a shape.
// the distance is negative if the point is inside the shape. You can't really move the shapes so they
// are all centered on 0,0,0. To "move" the shape what you do instead is move the whole world in the opposite direction.
// to do that, just transform the point with the inverse of the transform you would like to apply to the shape. This inverse transformation
// is baked into the filter transform buffer.

// give this a pos and the transform you want to give to the sdf and
vec3 transform_for_sdf(vec3 pos, mat4x4 transform) {
  return (transform*vec4(pos, 1.0)).xyz;
}

float sphere_sdf(vec3 point, float radius, mat4x4 transform) {
  vec3 transformed_point = transform_for_sdf(point, transform);
  return length(transformed_point) - radius;
}

float box_sdf(vec3 point, vec3 dimensions, mat4x4 transform) {
  vec3 transformed_point = transform_for_sdf(point, transform);
  // I'd like to give a descriptive name to q but I'm not sure what it represents.
  vec3 q = abs(transformed_point) - dimensions;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

// takes the buffer position of the first element of a filter transform
// and makes a 4x4 transformation matrix from it.
mat4x4 get_filter_matrix_from_transform(int buffer_offset) {

  float x_x = filter_transforms_buffer.data[buffer_offset];
  float x_y = filter_transforms_buffer.data[buffer_offset + 1];
  float x_z = filter_transforms_buffer.data[buffer_offset + 2];

  float y_x = filter_transforms_buffer.data[buffer_offset + 3];
  float y_y = filter_transforms_buffer.data[buffer_offset + 4];
  float y_z = filter_transforms_buffer.data[buffer_offset + 5];

  float z_x = filter_transforms_buffer.data[buffer_offset + 6];
  float z_y = filter_transforms_buffer.data[buffer_offset + 7];
  float z_z = filter_transforms_buffer.data[buffer_offset + 8];

  float x = filter_transforms_buffer.data[buffer_offset + 9];
  float y = filter_transforms_buffer.data[buffer_offset + 10];
  float z = filter_transforms_buffer.data[buffer_offset + 11];

  return mat4x4(
      x_x,   x_y,   x_z,   0.0,
      y_x,   y_y,   y_z,   0.0,
      z_x,   z_y,   z_z,   0.0,
      x,       y,     z,   1.0
  );
}

// constants related to filter settings.
const int BOX = 0;
const int SPHERE = 1;
const int INCLUSION = 0;
const int EXCLUSION = 1;
const int INACTIVE = 2;

// constants for device types
const int DEBUG = 0;
const int ORBBEC = 1;
const int HESAI = 2;

const float min_point_z_value = 1e-6f;

// Applies the ith filter on a point
bool apply_filter(vec3 point, int i) {
  int filter_settings_idx = i * params.filter_settings_num_fields;
  int filter_shape = filter_settings_buffer.data[filter_settings_idx];
  int filter_mode = filter_settings_buffer.data[filter_settings_idx + 1];
  if (filter_mode == INACTIVE) {
    // if the filter is inactive, the point is always included.
    return true;
  }
  int filter_transform_idx = i * params.transforms_num_fields;
  mat4x4 filter_transform = get_filter_matrix_from_transform(filter_transform_idx);
  float dist;
  if (filter_shape == BOX) {
    dist = box_sdf(point, vec3(1.0,1.0,1.0), filter_transform);
  } else if (filter_shape == SPHERE) {
    dist = sphere_sdf(point, 1.0, filter_transform);
  }
  // SDF return < 0 if a point is inside the shape.
  if (filter_mode == INCLUSION) {
    return dist <= 0.0;
  } else if (filter_mode == EXCLUSION) {
    return dist > 0.0;
  }
}

// The code we want to execute in each invocation
void main() {
  uint point_idx = get_global_point_idx();
  uint point_cloud_buffer_idx = point_idx * num_floats_per_input_point;
  uint multimesh_buffer_idx = point_idx * num_floats_per_multimesh_point;
  if (point_cloud_buffer_idx + num_floats_per_input_point <= params.point_cloud_buffer_size) {
    vec3 point_coords;
    bool point_is_kept = true;
    switch (params.device_type) {
      case ORBBEC:
        // we invert the x and y axis and divide by 1000 because orbbecs report points in mm instead of meters and the x and y are somehow inverted.
        point_coords = vec3(-point_cloud_buffer.data[point_cloud_buffer_idx]/1000.0, -point_cloud_buffer.data[point_cloud_buffer_idx + 1]/1000.0, point_cloud_buffer.data[point_cloud_buffer_idx + 2]/1000.0);
        // orbbec points with 0 z are invalid points, filter them out
        point_is_kept = point_coords.z > min_point_z_value;
        break;
      case HESAI:
        // x = -y; y = z; z = -x , no rescaling as the hesai should already be in meters.
        point_coords = vec3(-point_cloud_buffer.data[point_cloud_buffer_idx+1], point_cloud_buffer.data[point_cloud_buffer_idx + 2], -point_cloud_buffer.data[point_cloud_buffer_idx]);
        break;
      default:
        // catches DEBUG
        point_coords = vec3(point_cloud_buffer.data[point_cloud_buffer_idx], point_cloud_buffer.data[point_cloud_buffer_idx + 1], point_cloud_buffer.data[point_cloud_buffer_idx + 2]);
    }
    // get the point clouds transform from the push constant.
    mat4x4 point_cloud_transform = mat4x4(
        params.pt_cloud_transform_x_x,   params.pt_cloud_transform_x_y,   params.pt_cloud_transform_x_z,   0.0,
        params.pt_cloud_transform_y_x,   params.pt_cloud_transform_y_y,   params.pt_cloud_transform_y_z,   0.0,
        params.pt_cloud_transform_z_x,   params.pt_cloud_transform_z_y,   params.pt_cloud_transform_z_z,   0.0,
        params.pt_cloud_transform_x,     params.pt_cloud_transform_y,     params.pt_cloud_transform_z,     1.0
    );
    // the point coordinate we receive are the raw points values. They do not take in account the translations/rotations/scale
    // of their respective MultiMeshInstance3D. We need to retransform them in order to get the effective point coordinate in 3D space.
    vec3 transformed_coords = (point_cloud_transform * vec4(point_coords, 1.0)).xyz;

    // look to see if this point should be thinned by our thinning mask.
    float thinning_value = thinning_mask_buffer.data[point_idx%params.thinning_mask_size];
    point_is_kept = point_is_kept && (thinning_value > params.thinning);
    if (point_is_kept) {
      for(int i = 0; i < params.num_filters; i++) {
        point_is_kept = apply_filter(transformed_coords, i);
        if (!point_is_kept) {
          break;
        }
      }
    }
    if (point_is_kept) {
      // Atomic add to get a unique write index in the points buffer
      uint local_idx = atomicAdd(filtered_sizes_buffer.sizes[params.device_idx], 1u);
      uint filtered_output_idx = get_filtered_output_point_idx(int(local_idx), params.device_idx);
      // if the point is included in the filters,  update the position to match the
      // point cloud's transform.
      int point_cloud_packed_idx = int(filtered_output_idx) * num_floats_per_input_point;
      filtered_output_buffer.data[point_cloud_packed_idx] = transformed_coords.x;
      filtered_output_buffer.data[point_cloud_packed_idx + 1] = transformed_coords.y;
      filtered_output_buffer.data[point_cloud_packed_idx + 2] = transformed_coords.z;
      // update the multimesh transform buffer to render the points
      multimesh_buffer.data[multimesh_buffer_idx + x_idx] = point_coords.x;
      multimesh_buffer.data[multimesh_buffer_idx + y_idx] = point_coords.y;
      multimesh_buffer.data[multimesh_buffer_idx + z_idx] = point_coords.z;
    } else {
      // move the filtered point away from sight.
      multimesh_buffer.data[multimesh_buffer_idx + x_idx] = -666.0;
      multimesh_buffer.data[multimesh_buffer_idx + y_idx] = -666.0;
      multimesh_buffer.data[multimesh_buffer_idx + z_idx] = -666.0;
    }
  } else if (multimesh_buffer_idx + num_floats_per_multimesh_point <= params.max_points * num_floats_per_multimesh_point) {
    // if we are out of range of the data but in range of the max point cloud size,
    // update the multimesh's transform to 0.0

    // TODO: try compaction + multimesh command buffer update to reduce number of drawn points instead.
    // see https://docs.godotengine.org/en/latest/classes/class_renderingserver.html#class-renderingserver-method-multimesh-get-command-buffer-rd-rid
    // Note: I have tried this and its hard to get right. This is performant enough for now.
    multimesh_buffer.data[multimesh_buffer_idx + x_idx] = -666.0;
    // exile the surplus points in the depths of hell.
    multimesh_buffer.data[multimesh_buffer_idx + y_idx] = -666.0;
    multimesh_buffer.data[multimesh_buffer_idx + z_idx] = -666.0;
  }
}
