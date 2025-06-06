extends Node
signal spawnSignal
signal sprintSignal
var isPlayerOutside : bool
var wolfDormant : bool
var secondsSinceWolfRanAway : float
var spawnCooldown : float
@export var spawnMinCooldown : float = 15
@export var spawnMaxCooldown : float = 30

var gunShotAggroLimit : float
func _ready() -> void:
	isPlayerOutside = true
	if(isPlayerOutside):
		spawnWolf()
var prevDormanState
func _process(delta: float) -> void:
	if(wolfDormant != prevDormanState):
		print("Wolf dormant is ", wolfDormant)
		prevDormanState = wolfDormant
	if(wolfDormant):
		secondsSinceWolfRanAway += delta
		if(secondsSinceWolfRanAway >= spawnCooldown):
			if(isPlayerOutside):
				spawnWolf()

func resetTimeSinceWolfRanAway():
	secondsSinceWolfRanAway = 0.0
	spawnCooldown = randf_range(spawnMinCooldown, spawnMaxCooldown)
	print("The wolf will spawn in " + str(spawnCooldown) + " seconds")
	wolfDormant = true

func onPlayerRanTooLong():
	print("registered player running over the limit")
	if(isPlayerOutside):
		print("The player has ran too much")
		if(wolfDormant):
			spawnWolf()
		else:
			sprintSignal.emit()
	
func spawnWolf():
	spawnSignal.emit()
	wolfDormant = false

func onGunFiredForNoReasonAtAll(): #When the gun is fired for no reason, 
	if(wolfDormant):
		var spawnWolfNumber = randf_range(0,1) #this function will "throw dice",
		if(spawnWolfNumber > gunShotAggroLimit): #if the number is greater than the limit, wolf is spawned.
			print("You done fuck A-aron...")
			if(isPlayerOutside):
				spawnWolf()
			gunShotAggroLimit = 0.8
		else: 
			print("Ima pretend I didn't hear that :D")
			gunShotAggroLimit -= 0.1

func onPlayerWentOut():
	isPlayerOutside = true
func onPlayerWentInside():
	isPlayerOutside = false
