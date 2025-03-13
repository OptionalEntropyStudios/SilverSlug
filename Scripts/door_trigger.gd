extends StaticBody3D

@export var targetPosition : Node3D
@onready var doorSound = $doorOpenSFX
func LoadNextScene(player : CharacterBody3D):
	player.global_position = targetPosition.global_position
	doorSound.play()
