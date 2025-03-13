extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	@warning_ignore("int_as_enum_without_cast")
	Input.set_mouse_mode(2)

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta):
	if(Input.is_action_just_pressed("pause")):
		get_tree().quit()

