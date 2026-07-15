@tool
extends HBoxContainer
@export var keybinding_text: String = "":
	set(text):
		keybinding_text = text
		update_label()
		
@export var help_text: String = "":
	set(text):
		help_text = text
		update_label()

func _ready():
	if get_tree().current_scene:
		get_tree().current_scene.ready.connect(_on_scenetree_ready)

func update_label() -> void:
	if get_node_or_null("KeyPanel/KeyText"):
		$KeyPanel/KeyText.text = " " + keybinding_text + " "
	if get_node_or_null("Label"):
		$Label.text = help_text

func _on_scenetree_ready():
	update_label()
