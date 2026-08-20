#[compute]
#version 450

// 64 is going to be optimal for amd and nvidia gpus. maybe.
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// buffer of the multimesh instance transforms
layout(set = 0, binding = 0, std430) buffer MultimeshBuffer {
  float data[];
} multimesh_buffer;

layout(push_constant) uniform Parameters {
  // number of points in the multimesh buffer
  int max_points;
  int num_floats_per_multimesh_point;
  float x;
  float y;
  float z;
  float r;
  float g;
  float b;
  float a;
} params;

// x y z r g b a's indexes in the multimesh data buffer
const int x_idx = 3;
const int y_idx = 7;
const int z_idx = 11;
const int r_idx = 12;
const int g_idx = 13;
const int b_idx = 14;
const int a_idx = 15;

const int l_size_x = 64;
const int max_workgroup_idx = 65535;
const int max_x_idx = max_workgroup_idx * l_size_x;

void main() {
  uint global_point_idx =
      ((gl_WorkGroupID.x + gl_LocalInvocationID.x + ((l_size_x - 1) * gl_WorkGroupID.x)) +
       gl_WorkGroupID.y * max_x_idx +
       gl_WorkGroupID.z * max_x_idx * max_workgroup_idx);
  uint multimesh_buffer_idx = global_point_idx * params.num_floats_per_multimesh_point;
  if (multimesh_buffer_idx + params.num_floats_per_multimesh_point <= params.max_points) {
    // basis
    multimesh_buffer.data[multimesh_buffer_idx]         = 1.0;
    multimesh_buffer.data[multimesh_buffer_idx + 1]     = 0.0;
    multimesh_buffer.data[multimesh_buffer_idx + 2]     = 0.0;
    multimesh_buffer.data[multimesh_buffer_idx + 4]     = 0.0;
    multimesh_buffer.data[multimesh_buffer_idx + 5]     = 1.0;
    multimesh_buffer.data[multimesh_buffer_idx + 6]     = 0.0;
    multimesh_buffer.data[multimesh_buffer_idx + 8]     = 0.0;
    multimesh_buffer.data[multimesh_buffer_idx + 9]     = 0.0;
    multimesh_buffer.data[multimesh_buffer_idx + 10]    = 1.0;
    multimesh_buffer.data[multimesh_buffer_idx + x_idx] = params.x;
    multimesh_buffer.data[multimesh_buffer_idx + y_idx] = params.y;
    multimesh_buffer.data[multimesh_buffer_idx + z_idx] = params.z;
    // this doesnt account for custom data. if we ever need them, maybe put a
    // mode flag instead of size check
    if (params.num_floats_per_multimesh_point > 12) {
      multimesh_buffer.data[multimesh_buffer_idx + r_idx] = params.r;
      multimesh_buffer.data[multimesh_buffer_idx + g_idx] = params.g;
      multimesh_buffer.data[multimesh_buffer_idx + b_idx] = params.b;
      multimesh_buffer.data[multimesh_buffer_idx + a_idx] = params.a;
    }
  }
}
