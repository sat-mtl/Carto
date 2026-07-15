extends Node
var undoredo: UndoRedo = UndoRedo.new()


var _disabled := false
var disabled_reason := ""

func disable(reason: String):
	disabled_reason = reason
	_disabled = true

func enable():
	disabled_reason = ""
	_disabled = false

func notify_disabled():
	ToastManager.show_toast("Undo/Redo is disabled right now : " + disabled_reason, "warning")

func add_property_change_to_stack(action_name, new_val, old_val, property_setter, ui_setter, execute=true):
	## This adds a property change to the stack, it takes the new value, the old value,
	## a callable that will set an arbitrary value to the right property(ies) and
	## a callable that will update a ui component to reflect the changes. This uses
	## MergeMode.MERGE_ENDS which will try to merge actions that have the same name and
	## that arrives in the stack within a certain time (800ms according to the docs).
	var set_value := func(val):
		property_setter.call(val)
		ui_setter.call(val)
	add_to_stack(action_name, func(): set_value.call(new_val), func():set_value.call(old_val), execute, UndoRedo.MergeMode.MERGE_ENDS)

func add_to_stack(action_name, do_callback, undo_callback, execute=true, merge=UndoRedo.MergeMode.MERGE_DISABLE):
	## Add a simple do, undo to the stack. This should be used for actions that
	## are not part of a continuous value change.
	undoredo.create_action(action_name, merge)
	undoredo.add_do_method(do_callback)
	undoredo.add_undo_method(undo_callback)
	undoredo.commit_action(execute)

func empty_stack():
	undoredo.clear_history()
	undo_redo_count = 0

# keep track of undos and redos for auto-saving and change tracking purposes.
var undo_redo_count = 0

func _input(event: InputEvent) -> void:
	if _disabled and (event.is_action_pressed("redo") or event.is_action_pressed("undo")):
		notify_disabled()
		return

	if event.is_action_pressed("redo"):
		if undoredo.redo():
			undo_redo_count -= 1
	elif event.is_action_pressed("undo"):
		if undoredo.undo():
			undo_redo_count += 1
