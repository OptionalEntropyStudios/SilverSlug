extends StaticBody3D
var game_manager


# Called when the node enters the scene tree for the first time.
func _ready():
	game_manager = get_tree().get_first_node_in_group("gamemanager")
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _die():
	queue_free()
