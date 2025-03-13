extends Area3D

@export var traumaReductionRate : float = 0.7

@export var maxX = 10.0
@export var maxY = 10.0
@export var maxZ = 5.0
@export var noise : FastNoiseLite
@export var noiseSpeed = 50.0
var trauma = 0.0
@onready var camera = $Camera
@onready var startRotation := camera.rotation_degrees as Vector3

var time = 0.0
func _process(delta):
	time += delta
	trauma = max(trauma - delta * traumaReductionRate, 0.0)
	camera.rotation_degrees.x = startRotation.x + maxX * getShakeIntensity() * getNoiseFromSeed(0)
	camera.rotation_degrees.y = startRotation.y + maxY * getShakeIntensity() * getNoiseFromSeed(1)
	camera.rotation_degrees.z = startRotation.z + maxZ * getShakeIntensity() * getNoiseFromSeed(2)
func _addTrauma(traumaAmount : float):
	trauma = clamp(trauma + traumaAmount, 0.0, 1.0)
func getShakeIntensity() -> float:
	return trauma * trauma

func getNoiseFromSeed(seedNumber : int) -> float:
	noise.seed = seedNumber
	return noise.get_noise_1d(time * noiseSpeed)
