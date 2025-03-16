extends CharacterBody3D


var player = null
var escapeTarget = null
var isRunningAway : bool = false
@export var playerPath : NodePath
@export var minEscapeDistance : float = 20.0
@onready var navAgent = $NavigationAgent3D
@onready var animTree = $AnimationTree
var stateMachine
@onready var playerHeadPos = $PlayerHeadPos #The position we want the player's head to be in, when attacked
@onready var playerCollision = $PlayerHeadPos/playerCollision

#Sound Effects
@onready var wolfHitSound = $WolfHitSound
@onready var wolfFootstep = $FootSteps
@onready var howlSound = $WolfHowl
@onready var howlSprintBark = $WolfSprintBark
@onready var stalkGrowl = $WolfStalking


#FOOTSTEPS 
var footstepInterval : float = 0.0
@export var sprintInterval : float
@export var stalkInterval : float
var timeSinceLastStep : float = 0.0
var stepsTaken : int = 0

var gotClosestTarget : bool = false
var targetPos2D = null

var secondAttack = false
var canAttack : bool = true
var ableToLook : bool = true
var isDormant : bool = true
signal wentDormant
signal attackFinished
@export var sprintSpeed = 7.5
@export var stalkSpeed = 1.5
@export var moveSpeed = 1.5

@export var distanceToStartApproachingPlayer : float
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	player = get_node(playerPath)
	stateMachine = animTree.get("parameters/playback")
	timeSinceLastStep = 0.0
func _process(delta):
	velocity = Vector3.ZERO #Reset the velocity everyframe, idk why :ddd
	#Gravity boiiii
	if(not is_on_floor()):
		velocity.y -= gravity
	if(!isDormant):
		if(global_position.distance_to(player.global_position) < distanceToStartApproachingPlayer):
			if(stateMachine.get_current_node() == "WolfStandingPose"):
				animTree.set("parameters/conditions/isCrouching", true)
		match stateMachine.get_current_node(): #Check the animationtree for the current animation playing and set movement speed based on that.
			"WolfStandingPose":
				moveSpeed = 0
			"WolfIntoCrouch":
				moveSpeed = 0
			"WolfStalking":
				moveSpeed = stalkSpeed
				footstepInterval = stalkInterval
				if(!stalkGrowl.playing):
					stopAllSounds()
					stalkGrowl.play()
			"WolfSprinting":
				moveSpeed = sprintSpeed
				footstepInterval = sprintInterval
				if(!isRunningAway):
					if(!howlSprintBark.playing):
						stopAllSounds()
						howlSprintBark.play()
			"WolfFirstAttack":
				moveSpeed = 0
			"WolfSecondAttack":
				moveSpeed = 0
			"WolfGetHitRunAway":
				moveSpeed = 0
		if(ableToLook): #If the wolf is able to look around aka not getting up from being shot at.
			var wolfPos2D = Vector2(global_position.x, global_position.z) #The wolf's global position, from top down view
			var nextNavPoint
			if(!isRunningAway):# If the wolf is not running away
				navAgent.target_position = player.global_transform.origin #The target to navigate towards will be player
				nextNavPoint = navAgent.get_next_path_position() # Calculate next target
				velocity = (nextNavPoint - global_transform.origin).normalized() * moveSpeed #apply movespeed
				targetPos2D = Vector2(player.global_position.x, player.global_position.z) #The player's pos from top down
			else:  #wolf is running away
				if(!gotClosestTarget):
					targetPos2D = getClosestMovementTarget() #Find the nearest escape target
				navAgent.target_position = Vector3(targetPos2D.x, global_position.y, targetPos2D.y) #set that target as the position to move towards
				nextNavPoint = navAgent.get_next_path_position() #calculate next step along the path to the target
				velocity = (nextNavPoint - global_transform.origin).normalized() * moveSpeed #move that way
			var lookDirection = (wolfPos2D - targetPos2D) #We get the look direction by substracting player's pos from wolf's position.
			rotation.y = lerp_angle(rotation.y, atan2(lookDirection.x, lookDirection.y), delta / .5) #Smoothly look at the target position
		if(isRunningAway):
			if(global_position.distance_to(Vector3(navAgent.target_position.x, global_position.y, navAgent.target_position.z)) < 1): #If wolf is closer than 1m to the target, we have reached it
				goDormant()
	else:
		pass
	footSteps()
	move_and_slide()


func CollisionDetected(body): #Check if we have hit anything in the spot, where player needs to be for attack
	if(body.name == "Player"):
		if(canAttack):
			if(stateMachine.get_current_node() == "WolfStalking"):
				animTree.set("parameters/conditions/isSprinting", true)
			if(!secondAttack): #If the wolf hasn't attacked before
				body.getAttacked(playerHeadPos) #Call the function found in the player's script
				animTree.set("parameters/conditions/firstAttack", true) #set the condtion controlling attack anim to be true
				secondAttack = true #Next attack will be the second one.
			else:
				body.getAttacked(playerHeadPos) #Call the function found in the player's script
				animTree.set("parameters/conditions/secondAttack", true) #set the condtion controlling attack anim to be true
				print("Game over haha")
func _on_player_player_running(): #Called when the player is running
	if(!isDormant):
		if(stateMachine.get_current_node() == "WolfStandingPose"):
			sprintAtTheMf()
		elif(stateMachine.get_current_node() == "WolfStalking"): #If the wolf is stalking and player starts running, trigger the sprint
			print("Wolf aggroed into sprinting")
			sprintAtTheMf()

func _on_arm_gun_readied(): #Called if the player is readying their gun
	if(!isDormant):
		if(stateMachine.get_current_node() == "WolfStandingPose"):
			print("The wolf was standing and will now sprint at the player")
			sprintAtTheMf()
		elif(stateMachine.get_current_node() == "WolfStalking"):
			sprintAtTheMf()


func _on_animation_tree_animation_finished(anim_name):
	if(anim_name == "WolfFirstAttack"):
		wolfHitSound.play() #The wolf gets "hurt" cuz of the silver cross
		attackFinished.emit()
		var forwardTeleportLocation = playerCollision.global_position#We gotta teleport like 2 meters forward, so
		global_position = forwardTeleportLocation #So we just gonna teleport to where the player pos was
		isRunningAway = true #We're running away now
		canAttack = false
		animTree.set("parameters/conditions/firstAttack", false)
		animTree.set("parameters/conditions/finishedAttack", true)

	if(anim_name == "WolfGetHitRunAway"): #If the wolf has recovered from getting hit
		animTree.set("parameters/conditions/isHit",false)
		animTree.set("parameters/conditions/gotUp", true)
		animTree.set("parameters/conditions/isSprinting", false)
		ableToLook = true
		isRunningAway = true
	if(anim_name == "WolfSecondAttack"):
		get_tree().quit(0) #THIS NEEDS TO BE CHANGED
func getShot(): #Called, when the shot hits the wolf
	wolfHitSound.play()
	ableToLook = false #The wolf can't point towards the player, if it's getting up
	canAttack = false
	animTree.set("parameters/conditions/isHit", true) #Trigger the get shot animations
	animTree.set("parameters/conditions/gotUp", false) #Set the got up animation trigger to false, so it doesn't just loop endlessly
									 		#Go through all movementTargets in the world and return the closest 
func getClosestMovementTarget() -> Vector2: #one's position from top down view
	gotClosestTarget = true
	var closestTarget = null #The variable to store the closest node3d into
	for target in get_tree().get_nodes_in_group("movementTarget"): #Get every node, that is in group movementTarget and iterate through them
		var distanceToTarget = self.global_position.distance_to(target.global_position)
		if(closestTarget != null): #just a check for the first time, cuz no spots have been measured yet
			if(distanceToTarget < closestTarget.global_position.distance_to(self.global_position) && distanceToTarget > minEscapeDistance): #If the distance to iterated target is smaller, assign that as new closestTarget
				closestTarget = target
		else: 
			if(target.global_position.distance_to(self.global_position) > minEscapeDistance): #If the target is further away than the minEscape distance,
				closestTarget = target #Set that to be target
			else: continue
	return Vector2(closestTarget.global_position.x, closestTarget.global_position.z)

func setAllConditionsToFalse():
	animTree.set("parameters/conditions/finishedAttack",false)
	animTree.set("parameters/conditions/firstAttack", false)
	animTree.set("parameters/conditions/goDormant", false)
	animTree.set("parameters/conditions/gotUp", false)
	animTree.set("parameters/conditions/isCrouching",false)
	animTree.set("parameters/conditions/isHit", false)
	animTree.set("parameters/conditions/isSprinting", false)
	animTree.set("parameters/conditions/secondAttack", false)
	animTree.set("parameters/conditions/isStalking", false)


func onVisibleOnScreen():
	if(stateMachine.get_current_node() == "WolfIntoCrouch"):
		animTree.set("parameters/conditions/isStalking", true)
	elif(stateMachine.get_current_node() == "WolfStalking"):
		animTree.set("parameters/conditions/isSprinting", true)

func footSteps():
	if (stateMachine.get_current_node() == "WolfStalking" || stateMachine.get_current_node() == "WolfSprinting"):
		timeSinceLastStep += get_process_delta_time()
		if timeSinceLastStep >= footstepInterval:
			timeSinceLastStep = 0.0
			wolfFootstep.play()

func getStartPosition():
	var possibleTargets : Array[Vector2]
	var startPos
	var i = 0
	for target in get_tree().get_nodes_in_group("movementTarget"): #Get every node, that is in group movementTarget and iterate through them
		var distanceToTarget = player.global_position.distance_to(target.global_position) #Measure the distance to the target from player pos
		#We're also going to want to check it to be far away enough to not be visible to the player.
		if(distanceToTarget > minEscapeDistance): #if the distance is long enough, add it to the array
			possibleTargets.insert(i, Vector2(target.global_position.x, target.global_position.z))
			i+=1
		else: continue
	startPos = possibleTargets[randi_range(0, possibleTargets.size() - 1)]
	return Vector2(startPos)

func stopAllSounds():
	wolfHitSound.stop()
	howlSound.stop()
	howlSprintBark.stop()
	stalkGrowl.stop()

func goDormant():
	howlSound.play()
	isDormant = true
	setAllConditionsToFalse()
	animTree.set("parameters/conditions/goDormant", true) #The wolf will just stand around.
	canAttack = false
	isRunningAway = false
	self.visible = false
	wentDormant.emit()

func spawnIntoTheWorld():
	var closestTargetPos = getStartPosition()
	global_position = Vector3(closestTargetPos.x, global_position.y, closestTargetPos.y)
	self.visible = true
	canAttack = true
	isDormant = false
	gotClosestTarget = false
	print("I have spawned into the world")

func onGunShotForNoFukenReasonAtAll():
	if(stateMachine.get_current_node() == "WolfStandingPose"):
		var attackChance = randf_range(0, 1)
		if(attackChance > 0.5):
			sprintAtTheMf()

func sprintAtTheMf():
	animTree.set("parameters/conditions/goDormant", false)
	animTree.set("parameters/conditions/isCrouching", true)
	animTree.set("parameters/conditions/isStalking", true)
	animTree.set("parameters/conditions/isSprinting", true) #Start sprinting at them
