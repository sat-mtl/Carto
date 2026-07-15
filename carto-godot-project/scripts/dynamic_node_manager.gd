## This is intended to be used for nodes which can dynamically be created and removed,
## from a ui and need to have a unique numeric id. look at ndi_manager.gd for
## a simple implementation.
@abstract
class_name DynamicNodeManager
extends Node

# 1024 nodes should be enough.
var available_ids := range(1,1025)

var nodes: Array

## needs to be set to a function that takes "node" and returns the 
@abstract
func get_num_from_node(node)

func get_node_from_num(cam_num) -> Variant:
	for cam in nodes:
		if get_num_from_node(cam) == cam_num:
			return cam
	# shouldn't happen
	return null

func get_array_idx_from_num(cam_num):
	for i in range(len(nodes)):
		if get_num_from_node(nodes[i]) == cam_num:
			return i
	return null

func remove(obj_num) -> Variant:
	for i in range(len(nodes)):
		if get_num_from_node.call(nodes[i]) == obj_num:
			var nds = nodes[i]
			nodes.remove_at(i)
			available_ids.append(obj_num)
			return nds
	return null

func add(obj, idx):
	if idx != len(nodes):
		nodes.insert(idx, obj)
	else:
		nodes.append(obj)
	var node_id = get_num_from_node(obj)
	available_ids.remove_at(available_ids.find(node_id))
	return obj

@abstract func add_to_ui(obj, idx)

@abstract func remove_from_ui(obj)

func get_lowest_available_id():
	if len(available_ids) == 0:
		return -1
	available_ids.sort()
	return available_ids.pop_front()
