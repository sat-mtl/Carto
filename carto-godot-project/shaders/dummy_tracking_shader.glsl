#[compute]
#version 450

#extension GL_EXT_buffer_reference : require

// 64 is going to be optimal for amd and nvidia gpus. maybe.
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// we need to align the references to the smallest element. In our case this is float so the alignement
// is 4 bytes.
layout(buffer_reference, std430, buffer_reference_align = 4) readonly buffer PointCloudBuffer
{
  float data[];
};

layout(set = 0, binding = 0) buffer PointCloudPointers {
    PointCloudBuffer ptrs[];
} point_cloud_pointers;

layout(buffer_reference, std430, buffer_reference_align = 4) readonly buffer PointCloudSize
{
  // this is the size in number of points
  int size;
};

layout(set = 0, binding = 1) buffer PointCloudSizesPointers {
    PointCloudSize ptrs[];
} point_cloud_sizes_pointers;


// buffer of the multimesh instance transforms
layout(set = 0, binding = 2, std430) buffer MultimeshBuffer {
  float data[];
} multimesh_buffer;

// buffer for the atomic point counter
layout(set = 0, binding = 3, std430) buffer PointsCounter {
  uint data;
} counter_buffer;

// buffer for the network output
layout(set = 0, binding = 4, std430) buffer Output {
  float data[];
} output_buffer;

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

const int l_size_x = 64;
const int max_workgroup_idx = 65535;
const int max_x_idx = max_workgroup_idx * l_size_x;
const int num_floats_per_input_point = 3;

// gets the current point cloud index from the global index.
// example: if we are processing 2 point clouds, one which starts at 0 and one which starts at 675 and
// we pass 56, this returns 0. if we pass 897, this returns 1. This allows us to retrieve the
// transform associated with the point cloud.
uint get_current_point_cloud_idx(uint point_idx /*in number of floats*/) {
  uint offset = 0;
  for(int idx = 0; idx < params.num_point_clouds; idx++) {
    // iterate until the offset is over the buffer index
    offset += point_cloud_sizes_pointers.ptrs[idx].size * num_floats_per_input_point;
    if (point_idx < offset) {
      // when the offset is greater, it means the last index was the right one.
      return idx;
    }
  }
  // if we went through the whole loop and didn't find any point_idx > last offset, we are at the last point cloud.
  // fun fact : if you ommit this return, glsl panics and returns the argument of the function.
  return params.num_point_clouds - 1;
}

int get_local_idx(uint global_idx, uint point_cloud_idx) {
  int offset = 0;
  for(int idx = 0; idx < point_cloud_idx; idx++) {
    // iterate until the offset is over the buffer index
    offset += point_cloud_sizes_pointers.ptrs[idx].size * num_floats_per_input_point;
  }
  return int(global_idx) - offset;
}

// we could get this value computed one in another shader pass before this one maybe
// not sure its worth optimizing this right now
uint get_total_float_size() {
  uint total_size = 0;
  for(int i = 0; i < params.num_point_clouds; i++) {
    total_size += point_cloud_sizes_pointers.ptrs[i].size;
  }
  return total_size * 3;
}

void main() {
  uint global_point_idx =
      ((gl_WorkGroupID.x + gl_LocalInvocationID.x + ((l_size_x - 1) * gl_WorkGroupID.x)) +
       gl_WorkGroupID.y * max_x_idx +
       gl_WorkGroupID.z * max_x_idx * max_workgroup_idx);
  uint multimesh_buffer_idx = global_point_idx * num_floats_per_multimesh_point;
  uint global_float_idx = global_point_idx * num_floats_per_input_point;
  uint num_point_floats = get_total_float_size();
  if (global_float_idx + num_floats_per_input_point <= num_point_floats) {
    uint current_point_cloud_idx = get_current_point_cloud_idx(global_float_idx);
    int local_float_idx = get_local_idx(global_float_idx, current_point_cloud_idx);
    // // x float value
    float x = point_cloud_pointers.ptrs[current_point_cloud_idx].data[local_float_idx];
    // // y float value
    float y = point_cloud_pointers.ptrs[current_point_cloud_idx].data[local_float_idx+1];
    // // z float value
    float z = point_cloud_pointers.ptrs[current_point_cloud_idx].data[local_float_idx+2];
    multimesh_buffer.data[multimesh_buffer_idx + x_idx] = x;
    multimesh_buffer.data[multimesh_buffer_idx + y_idx] = y;
    multimesh_buffer.data[multimesh_buffer_idx + z_idx] = z;
    if (x+y+z > 0.4) {
    //   // Atomic add to get a unique write index in the points buffer
      uint kept_point_idx = atomicAdd(counter_buffer.data, 1u);
      uint point_cloud_packed_idx = kept_point_idx * num_floats_per_input_point;
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
    // multimesh_buffer.data[0] = 0;
  } else if (multimesh_buffer_idx + num_floats_per_multimesh_point <= params.max_points * num_floats_per_multimesh_point) {
    multimesh_buffer.data[multimesh_buffer_idx + x_idx] = -666.0;
    multimesh_buffer.data[multimesh_buffer_idx + y_idx] = -666.0;
    multimesh_buffer.data[multimesh_buffer_idx + z_idx] = -666.0;
  }
}
