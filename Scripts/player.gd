extends CharacterBody3D

@onready var head = $Head
@onready var headPos = $justTheheadPos
@onready var player = $"."
@onready var arm = $Head/Arm
@onready var interact_ray = $Head/InteractRay
@onready var blood = $Head/bloodSplatter
@export var lookSensitivity = 5.5

#For the attacking <3
var theCross
@onready var crossPos = $crossPos
var crossDropped : bool = false
@onready var shakeable_camera = $Head/shakeable_camera
@onready var camera: Camera3D = $Head/shakeable_camera/Camera

var beingAttacked : bool = false #Is true, if we are.... being attacked -_-
var gettingUp : bool = false
var pouncePosition : Node3D
#wuba luba dub dub here will be the blood effect 
@onready var attackScreamSFX = $AttackScreamSFX
@onready var outdoorFootstep: AudioStreamPlayer3D = $outdoorFootstep
@onready var indoorFootstep: AudioStreamPlayer3D = $indoorFootstep
var isIndoors : bool
var footStepStartPitch
var footStepPitch

@export var stepWalkInterval : float = 0.8
var timeSinceLastStep : float
# and sounds too haha

#GAS BAR 
@onready var gasBar = $CanvasLayer/GasAmountBar
@export var gasBarVisibleLimit : float = 3.5
@onready var canPickupSFX = $gasCanSound

@onready var inspect_text = $CanvasLayer/InspectText
@export var inspectTextShowTime = 0.0

@onready var shellPickupSound = $shellPickupSound

@onready var interactXhair = $CanvasLayer/Crosshair/XhairHandInteract
@onready var pickupXhair = $CanvasLayer/Crosshair/XhairHandPickup
@onready var xhair_pointer = $CanvasLayer/Crosshair/Xhair_pointer
@onready var xhair_eye = $CanvasLayer/Crosshair/Xhair_eye

var currentSpeed : float
@export var baseSpeed = 150.0
@export var runSpeed = 1.75
@export var gunHoldingSpeed = 0.45
enum movementStates {WALKING, RUNNING, GUNDRAWN}
var currentMovementState : movementStates
#The run limit in a certain time
var maxAllowedSprinting : float = 7.5
var timeSprinting : float = 0.0
var running = false
signal playerRanTooLong
signal playerIndoors
signal playerOutdoors

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	theCross = get_tree().get_first_node_in_group("x")
	if(theCross != null):
		theCross.hide()
	crossDropped = false
	isIndoors = false #Player starts outdoors
	footStepStartPitch = outdoorFootstep.volume_db
	gasBar.modulate.a = 0
func _process(delta):
	checkGasBarOpacity(delta)
	checkCrosshairStatus()
	checkCurrentMovementState()

	getPlayerMoveSpeed()
	if(beingAttacked):
		gettingUp = true
		head.global_position = pouncePosition.global_position #Set the head's pos to the attacked position
		head.rotation_degrees.x = lerpf(head.rotation_degrees.x, pouncePosition.rotation_degrees.x, 0.1) #Rotate the head to point that way
		var wolf = get_tree().get_first_node_in_group("wolf")
		look_at(wolf.global_position, Vector3.UP)
		#add sounds and blood effects here
	elif (gettingUp):
		if(not crossDropped):
			crossDropped = true
			theCross.global_position = crossPos.global_position
			theCross.show()
			#Then also play the cross broke sound
		if(head.position.y < headPos.position.y - 0.05):
			head.position = lerp(head.position, headPos.position, 0.7 * delta)
			head.rotation_degrees.x = lerpf(head.rotation_degrees.x, 0, 0.8 * delta)
		else: 
			gettingUp = false
			timeSprinting = 0.0
			head.position = headPos.position
			head.rotation_degrees.x = 0
	head.rotation_degrees.x = clampf(head.rotation_degrees.x, -90, 90) #Limit head roatation to look straight up and down'
	head.rotation_degrees.y = 0.0
	head.rotation_degrees.z = 0.0
	rotation_degrees.x = 0.0
	rotation_degrees.z = 0.0
	if(Input.is_key_pressed(KEY_CTRL)):
		pass
var mouseInput
func _input(event):
	var aiming = Input.is_action_pressed("aimButton")
	if event is InputEventMouseMotion: #If mouse is moved
		mouseInput = Vector2(event.screen_relative.x, event.screen_relative.y)
		if(!beingAttacked and !gettingUp):
			if(mouseInput):
				if(aiming): #If user is not aiming, allow looking around with camera
					if(arm.gunDrawn and not arm.reloading and arm.canHoldGunUp):
						pass
					else:
						if(head.rotation_degrees.x < 90 and head.rotation_degrees.x > -90):
							head.rotate_x(deg_to_rad(-mouseInput.y * lookSensitivity * get_process_delta_time()))
						player.rotate_y(deg_to_rad(-mouseInput.x * lookSensitivity * get_process_delta_time()))
						head.rotation_degrees.x = clampf(head.rotation_degrees.x, -90, 90)
						head.rotation_degrees.y = 0.0
				else:
					xhair_pointer.show()
					head.rotate_x(deg_to_rad(-mouseInput.y * lookSensitivity * get_process_delta_time()))
					player.rotate_y(deg_to_rad(-mouseInput.x * lookSensitivity * get_process_delta_time()))
					head.rotation_degrees.x = clampf(head.rotation_degrees.x, -90, 90)
	#head.rotation_degrees.x = clampf(head.rotation_degrees.x, -90, 90)
func _physics_process(delta):
	if(!beingAttacked and !gettingUp): #If the player is being attacked, they're not supposed to be able to move :D
		doMovementStuff(delta)
		footSteps(delta)
		move_and_slide()

func ShowInspectText(showableText):
	inspect_text.text = showableText
	var textShowLimit = showableText.length() / 10
	inspect_text.show()
	await get_tree().create_timer(textShowLimit).timeout
	inspect_text.hide()
func updateGasAmount(gasAmount : float):
	gasBar.set_value_no_signal(gasBar.value + gasAmount)
	gasBar.modulate.a = 1
	
func checkGasBarOpacity(delta):
	var gasMeterChecked = Input.is_action_pressed("checkGasMeter")
	if(!gasMeterChecked):
		if(gasBar.modulate.a > 0):
			gasBar.modulate.a -= delta / 2
	else: gasBar.modulate.a = 1
func getAttacked(wolfAttackPosition : Node3D): #Called, if wolf reaches player
	attackScreamSFX.play()
	beingAttacked = true
	pouncePosition = wolfAttackPosition
func attackOver():
	print("We are not being attacked anymore")
	beingAttacked = false

func checkCrosshairStatus():
	if(interact_ray.is_colliding()):
		var target = interact_ray.get_collider()
		if(target != null):
			if(target.is_in_group("ammo")):
				pickupXhair.show()
				xhair_pointer.hide()
				if(Input.is_action_just_pressed("useButton")):
					arm.reserveAmmo += 1
					shellPickupSound.play()
					arm.updateAmmoText()
					target.queue_free()
			elif(target.is_in_group("interactable")):
				interactXhair.show()
				xhair_pointer.hide()
				if(Input.is_action_just_pressed("useButton")):
					target.LoadNextScene(self)
					isIndoors = !isIndoors
					if(isIndoors):
						playerIndoors.emit()
					else: 
						playerOutdoors.emit()
			elif(target.is_in_group("gas")):
				pickupXhair.show()
				xhair_pointer.hide()
				if(Input.is_action_just_pressed("useButton")):
					updateGasAmount(target.gasAmount)
					canPickupSFX.play()
					target.queue_free()
			elif(target.is_in_group("inspectable")):
				xhair_eye.show()
				xhair_pointer.hide()
				if(Input.is_action_just_pressed("useButton")):
					ShowInspectText(target.viewableText)
			elif(target.is_in_group("gun")):
				pickupXhair.show()
				xhair_pointer.hide()
				if(Input.is_action_just_pressed("useButton")):
					arm.hasGun = true
					arm.gunDrawn = true
					target.queue_free()
			else:
				hideAllCrosshairs()
		else:
			hideAllCrosshairs()
	else:
		hideAllCrosshairs()

func emitBlood():
	if(blood.emitting):
		blood.emitting = false
		blood.emitting = true
	else:
		blood.emitting = true
	shakeable_camera._addTrauma(0.5)

func hideAllCrosshairs():
	xhair_eye.hide()
	pickupXhair.hide()
	interactXhair.hide()

func footSteps(delta):
	if (velocity.normalized() != Vector3.ZERO):
		timeSinceLastStep += delta
		footStepPitch = (footStepStartPitch - randi_range(20, 50))
		outdoorFootstep.volume_db = footStepPitch
		indoorFootstep.volume_db = footStepPitch
		var currentStepInterval
		if(currentMovementState == movementStates.RUNNING):
			currentStepInterval = stepWalkInterval / 2
		else: currentStepInterval = stepWalkInterval
		if timeSinceLastStep >= currentStepInterval:
			timeSinceLastStep = 0.0
			if(isIndoors):
				indoorFootstep.play()
			else: outdoorFootstep.play()

#FOR DEBUG
var prevMovementState : movementStates
func checkCurrentMovementState():
	if(arm.gunDrawn):
		currentMovementState = movementStates.GUNDRAWN
	elif(Input.is_action_pressed("runButton") and Input.is_action_pressed("moveForward") and not Input.is_action_pressed("moveBack")):
		currentMovementState = movementStates.RUNNING
	else: currentMovementState = movementStates.WALKING
	if(currentMovementState != prevMovementState):
		print("Movementstate: " + str(movementStates.keys()[currentMovementState]))
		prevMovementState = currentMovementState

func getPlayerMoveSpeed():
	match currentMovementState:
		movementStates.RUNNING:
			currentSpeed = baseSpeed * runSpeed
		movementStates.GUNDRAWN:
			currentSpeed = baseSpeed * gunHoldingSpeed
		movementStates.WALKING:
			currentSpeed = baseSpeed
		_:
			currentSpeed = baseSpeed

func doMovementStuff(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	var input_dir = Input.get_vector("moveLeft", "moveRight", "moveForward", "moveBack")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction: #If user is moving
		velocity.x = direction.x * currentSpeed * delta
		velocity.z = direction.z * currentSpeed * delta
	else:
		velocity.x = move_toward(velocity.x, 0, baseSpeed)
		velocity.z = move_toward(velocity.z, 0, baseSpeed)
	if(currentMovementState == movementStates.RUNNING):
		timeSprinting += delta
	else:
		if(timeSprinting > 0.0):
			timeSprinting -= delta
	if(timeSprinting > maxAllowedSprinting):
		playerRanTooLong.emit()
		timeSprinting = 0.0
