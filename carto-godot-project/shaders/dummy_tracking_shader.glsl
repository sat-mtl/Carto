#[compute]
#version 450

#include "point_cloud_shader_commons.glsl.inc"

// buffer of the multimesh instance transforms
layout(set = 0, binding = 3, std430) buffer MultimeshBuffer {
  float data[];
} multimesh_buffer;

// buffer for the atomic point counter
layout(set = 0, binding = 4, std430) buffer PointsCounter {
  uint data;
} counter_buffer;

// buffer for the network output
layout(set = 0, binding = 5, std430) buffer Output {
  float data[];
} output_buffer;

// buffer for the multimesh command
layout(set = 0, binding = 6, std430) buffer MultimeshCommandBuffer {
  int vertex_count;
  int instance_count;
  int first_vertex;
  int first_instance;
  int unused;
} multimesh_command_buffer;

layout(push_constant) uniform Parameters {
  // number of point cloud buffer pointers
  int num_point_clouds;
  int max_points;
} params;

// x y z r g b a's indexes in the multimesh data buffer
const int x_idx = 3;
const int y_idx = 7;
const int z_idx = 11;
const int r_idx = 12;
const int g_idx = 13;
const int b_idx = 14;
const int a_idx = 15;

const int num_floats_per_multimesh_point = 16;

void main() {
  uint global_point_idx = get_global_point_idx();
  uint global_float_idx = global_point_idx * num_floats_per_input_point;
  populate_current_offset_and_index(global_point_idx, params.num_point_clouds);
  uint multimesh_buffer_idx = global_point_idx * num_floats_per_multimesh_point;
  uint num_points = get_total_point_size(params.num_point_clouds);
  uint num_floats = num_points * num_floats_per_input_point;
  multimesh_command_buffer.vertex_count = 1;
  multimesh_command_buffer.instance_count = int(num_points);
  multimesh_command_buffer.first_vertex = 0;
  multimesh_command_buffer.first_instance = 0;
  if (global_float_idx + num_floats_per_input_point <= num_floats) {
    int local_point_idx = get_local_idx(global_point_idx);
    uint filtered_output_point_idx = get_filtered_output_point_idx(local_point_idx, current_point_cloud_idx);
    uint filtered_output_float_idx = filtered_output_point_idx * num_floats_per_input_point;
    // // x float value
    float x = filtered_output_buffer.data[filtered_output_float_idx];
    // // y float value
    float y = filtered_output_buffer.data[filtered_output_float_idx + 1];
    // // z float value
    float z = filtered_output_buffer.data[filtered_output_float_idx + 2];
    multimesh_buffer.data[multimesh_buffer_idx + x_idx] = x;
    multimesh_buffer.data[multimesh_buffer_idx + y_idx] = y;
    multimesh_buffer.data[multimesh_buffer_idx + z_idx] = z;
    if (x+y+z > 0.4) {
      // Atomic add to get a unique write index in the points buffer
      // uint kept_point_idx = atomicAdd(counter_buffer.data, 1u);
      // uint point_cloud_packed_idx = kept_point_idx * num_floats_per_input_point;
      // output_buffer.data[point_cloud_packed_idx] = local_float_idx;
      // output_buffer.data[point_cloud_packed_idx + 1] = current_point_cloud_idx;
      // output_buffer.data[point_cloud_packed_idx + 2] = local_float_idx;
      multimesh_buffer.data[multimesh_buffer_idx + r_idx] = 0.0;
      multimesh_buffer.data[multimesh_buffer_idx + g_idx] = 1.0;
      multimesh_buffer.data[multimesh_buffer_idx + b_idx] = 0.0;
    } else {
      multimesh_buffer.data[multimesh_buffer_idx + r_idx] = 1.0;
      multimesh_buffer.data[multimesh_buffer_idx + g_idx] = 1.0;
      multimesh_buffer.data[multimesh_buffer_idx + b_idx] = 1.0;
    }
  } else if (multimesh_buffer_idx + num_floats_per_multimesh_point <= params.max_points * num_floats_per_multimesh_point) {
    multimesh_buffer.data[multimesh_buffer_idx + x_idx] = -666.0;
    multimesh_buffer.data[multimesh_buffer_idx + y_idx] = -666.0;
    multimesh_buffer.data[multimesh_buffer_idx + z_idx] = -666.0;
  }
}
