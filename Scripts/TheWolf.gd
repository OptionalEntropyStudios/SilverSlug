extends CharacterBody3D


@export var player : CharacterBody3D
var isRunningAway : bool = false
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

var zigZagChosen : bool = false
var zigZagAttack : bool = false
var zigZagTargetsToReach : int = 3
var zigZagTargetsReached : int = 0
var reachedZigZagTargets : Array[Node3D]
var zigZagTargets : Array[Node]
var currentZigZagTarget : Node3D
var currentZigZagTargetChosen : bool = false
var zigZagTargetPosition : Vector3

var secondAttack = false
var canAttack : bool = true
var isPlayerOutside : bool
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
	isPlayerOutside = true
	stateMachine = animTree.get("parameters/playback")
	timeSinceLastStep = 0.0
	print("trying to find zigzag targets")
	var zigZagTargetsHolder = get_tree().get_first_node_in_group("zigZagTargets")
	if(zigZagTargetsHolder == null):
		print("zigzagtargets not found")
	else:
		zigZagTargets = zigZagTargetsHolder.get_children()
func _process(delta):
	velocity = Vector3.ZERO #Reset the velocity everyframe, so there is no unwanted movement
	#Gravity boiiii
	#if(not is_on_floor()):
		#velocity.y -= gravity
	checkWolfLookingStatus(delta)
	if(!isDormant):
		if(global_position.distance_to(player.global_position) < distanceToStartApproachingPlayer):
			if(stateMachine.get_current_node() == "WolfStandingPose"):
				animTree.set("parameters/conditions/isCrouching", true)
		checkWolfMovementState()
		if(ableToLook): #If the wolf is able to look around aka not getting up from being shot at.
			var wolfPos2D = Vector2(global_position.x, global_position.z) #The wolf's global position, from top down view
			var nextNavPoint
			if(!isRunningAway):# If the wolf is not running away
				if(!zigZagChosen):
					getZigZagChance()
				if(zigZagAttack):
					if(zigZagTargetsReached >= zigZagTargetsToReach):
						zigZagAttack = false
					else:
						if(currentZigZagTarget == null and !currentZigZagTargetChosen):
							getZigZagTarget()
						else: navAgent.target_position = zigZagTargetPosition
				else:
					navAgent.target_position = player.global_transform.origin #The target to navigate towards will be player
				nextNavPoint = navAgent.get_next_path_position()
				navAgent.is_target_reachable()
				targetPos2D = Vector2(nextNavPoint.x, nextNavPoint.z) #The player's pos from top down
			else:  #wolf is running away
				if(!gotClosestTarget):
					targetPos2D = getClosestMovementTarget() #Find the nearest escape target
				navAgent.target_position = Vector3(targetPos2D.x, global_position.y, targetPos2D.y) #set that target as the position to move towards
			nextNavPoint = navAgent.get_next_path_position() #calculate next step along the path to the target
			velocity = (nextNavPoint - global_transform.origin).normalized() * moveSpeed #move that way
			
			var lookDirection = (wolfPos2D - Vector2(nextNavPoint.x, nextNavPoint.z)) #We get the look direction by substracting player's pos from wolf's position.
			rotation.y = lerp_angle(rotation.y, atan2(lookDirection.x, lookDirection.y), delta * 10) #Smoothly look at the target position
			if(isRunningAway):
				if(global_position.distance_to(Vector3(navAgent.target_position.x, global_position.y, navAgent.target_position.z)) < 1): #If wolf is closer than 1m to the target, we have reached it
					goDormant()
	footSteps()
	move_and_slide()
#FOR DEBUG
var prevWolfMovementState
var prevDormancyState
func checkWolfMovementState():
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
	if(stateMachine.get_current_node() != prevWolfMovementState):
		print(str(stateMachine.get_current_node()))
		prevWolfMovementState = stateMachine.get_current_node()
		print("targetPos2D value is ", targetPos2D)
		print("The navagent target point is ", navAgent.target_position)
	if(isDormant != prevDormancyState):
		print("The wolf's dormant status is ", isDormant)
		prevDormancyState = isDormant
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
	print("Wolf registered player running")
	if(!isDormant):
		if(stateMachine.get_current_node() == "WolfStandingPose" || stateMachine.get_current_node() == "WolfStalking"):
			sprintAtTheMf()

func _on_arm_gun_readied(): #Called if the player is readying their gun
	if(!isDormant):
		if(stateMachine.get_current_node() == "WolfStandingPose" || stateMachine.get_current_node() == "WolfStalking"):
			sprintAtTheMf()


func _on_animation_tree_animation_finished(anim_name):
	if(anim_name == "WolfFirstAttack"):
		
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
		var distanceToTarget = global_position.distance_to(target.global_position)
		if(closestTarget != null): #just a check for the first time, cuz no spots have been measured yet
			if(distanceToTarget < closestTarget.global_position.distance_to(self.global_position) && distanceToTarget > minEscapeDistance): #If the distance to iterated target is smaller, assign that as new closestTarget
				closestTarget = target
		else: 
			if(target.global_position.distance_to(self.global_position) > minEscapeDistance): #If the target is further away than the minEscape distance,
				closestTarget = target #Set that to be target
			else: continue
	return Vector2(closestTarget.global_position.x, closestTarget.global_position.z)

func getZigZagChance():
	zigZagChosen = true
	var zigZagChance = randf_range(0,1)
	if(zigZagChance > 0.35):
		zigZagAttack = true
	else: zigZagAttack = false


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

var playerLookedTooLongAtWolf : bool = false
var notVisibleToPlayer : bool
func onPlayerLookedToolong():
	print("playerLookedTooLongAtWolf is registered")
	playerLookedTooLongAtWolf = true

func onPlayerLookedAway():
	notVisibleToPlayer = true
	onPlayerLookingAwayAfterStaring()

func onPlayerLookedAtWolf():
	notVisibleToPlayer = false
	print("player is looking at wolf")

@export var wolfLookingLimit : float = 10 #If the wolf is looked at for too long, trigger the wolf to start stalking at the player
var timeSpentLookingAtWolf : float = 0.0
func checkWolfLookingStatus(delta):
	if(!notVisibleToPlayer):
		timeSpentLookingAtWolf += delta
	else:
		timeSpentLookingAtWolf -= delta
	if(timeSpentLookingAtWolf > wolfLookingLimit):
		print("Looked at wolf too long, emitting the wolf is gonna change status when looking away")
		playerLookedTooLongAtWolf = true
		timeSpentLookingAtWolf = 0.0

func onPlayerLookingAwayAfterStaring():
	if(playerLookedTooLongAtWolf):
		playerLookedTooLongAtWolf = false
		if(stateMachine.get_current_node() == "WolfIntoCrouch" || stateMachine.get_current_node() == "WolfStandingPose"):
			animTree.set("parameters/conditions/isCrouching", true)
			animTree.set("parameters/conditions/isStalking", true)
		elif(stateMachine.get_current_node() == "WolfStalking"):
			animTree.set("parameters/conditions/isSprinting", true)
			animTree.set("parameters/conditions/isCrouching", false)
			animTree.set("parameters/conditions/isStalking", false)
			animTree.set("parameters/conditions/goDormant", false)
		
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
	print("trying to get start position now")
	for target in get_tree().get_nodes_in_group("movementTarget"): #Get every node, that is in group movementTarget and iterate through them
		print("checking if ", target.name, " is")
		print(player.name)
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
	isDormant = true
	zigZagChosen = false
	zigZagTargetsReached = 0
	reachedZigZagTargets.clear()
	setAllConditionsToFalse()
	animTree.set("parameters/conditions/goDormant", true) #The wolf will just stand around.
	canAttack = false
	isRunningAway = false
	self.visible = false
	playerLookedTooLongAtWolf = false
	wentDormant.emit()

func spawnIntoTheWorld():
	var closestTargetPos = getStartPosition()
	global_position = Vector3(closestTargetPos.x, global_position.y, closestTargetPos.y)
	self.visible = true
	canAttack = true
	isDormant = false
	gotClosestTarget = false

func onGunShotForNoFukenReasonAtAll():
	if(stateMachine.get_current_node() == "WolfStandingPose" || stateMachine.get_current_node() == "WolfIntoCrouch"):
		var attackChance = randf_range(0, 1)
		if(attackChance > 0.5):
			sprintAtTheMf()

func sprintAtTheMf():
	animTree.set("parameters/conditions/goDormant", false)
	animTree.set("parameters/conditions/isCrouching", true)
	animTree.set("parameters/conditions/isStalking", true)
	animTree.set("parameters/conditions/isSprinting", true) #Start sprinting at them

func onPlayerWentOut():
	isPlayerOutside = true

func onPlayerWentInside():
	isPlayerOutside = false
	goDormant()

signal bitPlayer
@onready var crossBreakSound: AudioStreamPlayer3D = $CrossBreakingSound


func onAnimationReachedPlayerBitSpot() -> void :
	bitPlayer.emit()
	if(stateMachine.get_current_node() == "WolfFirstAttack"):
		print("this the first time attacking")
		crossBreakSound.play()
		wolfHitSound.play() #The wolf gets "hurt" cuz of the silver cross



func reachedNavAgentTarget() -> void:
	if(zigZagAttack and currentZigZagTarget != null):
		zigZagTargetsReached += 1
		reachedZigZagTargets.append(currentZigZagTarget)
		currentZigZagTarget = null
		currentZigZagTargetChosen = false

func getZigZagTarget():
	currentZigZagTargetChosen = true
	await get_tree().create_timer(0.25).timeout
	#print("function - getZigZagTarget : Getting all possible zigZagTargets")
	var reachableTargets : Array[Node3D]
	#print("function - getZigZagTarget : There are ", zigZagTargets.size(), " targets to check")
	var savedNavAgentTarget = navAgent.target_position
	for target in zigZagTargets:
		navAgent.target_position = target.global_position
		#print("function - getZigZagTarget : checking if ", target.name, " is reachable")
		#print("target's globalPos: ", navAgent.target_position, "  finalPos: ", navAgent.get_final_position(), " | distance between the two need to be lower than targetDesiredDistance: ", navAgent.target_desired_distance, " and that distance is ", testDistance)
		if(navAgent.is_target_reachable()):
			#print("This one is reachable: ", target.name)
			reachableTargets.append(target)
		elif(savedNavAgentTarget != null):
			#print("navAgent would not be able to reach ", target.global_position, " when wolf's global_pos is ", global_position)
			navAgent.target_position = savedNavAgentTarget
	#print("function - getZigZagTarget : all reachable targets have been checked")
	var chosenTargets : Array[Node3D]

	#print("function - getZigZagTarget : checking if any of the viable targets have been reached before")
	for target in reachableTargets:
		var targetAlreadyChosen : bool = false
		for i in range(0, reachedZigZagTargets.size() -1):
			if(target.name != reachedZigZagTargets[i].name):
				continue
			else: targetAlreadyChosen = true
		if(targetAlreadyChosen):
			#print(target.name, " has been chosen before, skipping it")
			continue
		else: 
			#print(target.name, " has not been chosen before, adding it to array")
			chosenTargets.append(target)
	var closestTarget : Node3D
	for target in chosenTargets:
		if(closestTarget == null):
			closestTarget = target
		else:
			var distanceToTarget = global_position.distance_to(target.global_position)
			var distanceToClosestTarget = global_position.distance_to(closestTarget.global_position)
			var distanceFromTargetToPlayer = target.global_position.distance_to(player.global_position)
			var distanceToPlayer = global_position.distance_to(player.global_position)
			if(distanceToTarget < distanceToClosestTarget and distanceFromTargetToPlayer <= distanceToPlayer):
				closestTarget = target
	currentZigZagTarget = closestTarget
	print("current zigzagtarget is ", currentZigZagTarget.name)
	zigZagTargetPosition = currentZigZagTarget.global_position
