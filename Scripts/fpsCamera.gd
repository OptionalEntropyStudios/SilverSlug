extends Camera3D
@export var arm : Node3D
@export var shoot_ray : RayCast3D
@export var crosshair : TextureRect
var xHairStartPos : Vector2
var canAim : bool
func _ready():
	xHairStartPos = crosshair.global_position
func _process(delta):
	if(Input.is_action_pressed("aimButton") and arm.canHoldGunUp):
		if(shoot_ray.is_colliding()):
			var point = shoot_ray.get_collision_point()
			crosshair.show()
			crosshair.global_position = unproject_position(point)
		else: crosshair.hide()
	else: 
		crosshair.global_position = xHairStartPos
		crosshair.show()
