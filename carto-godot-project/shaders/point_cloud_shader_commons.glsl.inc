// 64 is going to be optimal for amd and nvidia gpus. maybe.
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

const int l_size_x = 64;
const int max_workgroup_idx = 65535;
const int max_x_idx = max_workgroup_idx * l_size_x;
const int num_floats_per_input_point = 3;
// buffer for the filtered output. an invocation for a device only
// writes to a part of this.
layout(set = 0, binding = 0, std430) buffer FilteredOutput {
  float data[];
} filtered_output_buffer;

// buffer that contains the actual valid size of each point cloud in the filtered output buffer.
// the size is in number of points not in number of floats
layout(set = 0, binding = 1, std430) buffer FilteredOutputSizes {
  uint sizes[];
} filtered_sizes_buffer;

uint get_global_point_idx() {
  // trust me, this results in a smoothly incrementing id.
  return ((gl_WorkGroupID.x + gl_LocalInvocationID.x + ((l_size_x - 1) * gl_WorkGroupID.x)) +
       gl_WorkGroupID.y * max_x_idx +
       gl_WorkGroupID.z * max_x_idx * max_workgroup_idx);
}

// TODO: maybe put this as a push constant if it ever changes.
const int num_points_per_point_clouds = 1024*1024;
int current_point_cloud_idx = -1;
int current_point_cloud_offset = -1;

// sets the current point cloud index and offset from the global index.
// example: if we are processing 2 point clouds, one which starts at 0 and one which starts at 675 and
// we pass 56, this returns 0. if we pass 897, this sets current_point_cloud_idx to 1 and current_point_cloud_offset to 675.
void populate_current_offset_and_index(uint global_point_idx, uint num_point_clouds) {
  if (current_point_cloud_idx != -1 && current_point_cloud_offset != -1) {
    // don't recompute this.
    return;
  }
  uint offset = 0;
  for(int idx = 0; idx < num_point_clouds; idx++) {
    // iterate until the offset is over the buffer index
    offset += filtered_sizes_buffer.sizes[idx];
    if (global_point_idx < offset) {
      // when the offset is greater, it means the last index was the right one.
      current_point_cloud_offset = int(offset);
      current_point_cloud_idx = int(idx);
      return;
    }
  }
  current_point_cloud_offset = int(offset);
  current_point_cloud_idx = int(num_point_clouds - 1);
}

// from a global index (in number of floats, not points), returns the local index in float
// for the point cloud pointed at by point_cloud_idx
// so like ...

// ([o][o][o][o])([o][o][o][x][o][o])([o][o][o][o][o][o][o])
//         |                 |              |
//         v                 v              v
// pt cloud 0           pt cloud 1        pt cloud 2
// global_idx for the x is 7 (starting at 0)
// local_idx for x is 3
//  **call populate_current_offset_and_index before calling this**
int get_local_idx(uint global_point_idx) {
  return int(global_point_idx) - current_point_cloud_offset;
}

// gets the actual float index in filtered points buffer.
// num_points_per_point_clouds is the constant size (in points) of the portion of the filtered_output_buffer
// that is reserved for every device.
uint get_filtered_output_point_idx(int local_point_idx, int pt_cloud_index) {
  return local_point_idx + (pt_cloud_index * num_points_per_point_clouds);
}

// we could get this value computed one in another shader pass before this one maybe
// not sure its worth optimizing this right now
uint get_total_point_size(uint num_point_clouds) {
  uint total_size = 0;
  for(int idx = 0; idx < num_point_clouds; idx++) {
    total_size += filtered_sizes_buffer.sizes[idx];
  }
  return total_size;
}
