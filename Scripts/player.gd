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

@export var stepWalkInterval : float
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
@export var SPEED = 150.0
@export var runSpeed = 1.75

#The run limit in a certain time
var maxAllowedSprinting : float = 7.5
var timeSprinting : float = 0.0
var running = false
signal playerRunning
signal playerRanTooLong
@export var gunHoldingSpeed = 0.45
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	theCross = get_tree().get_first_node_in_group("x")
	theCross.hide()
	crossDropped = false
	isIndoors = false #Player starts outdoors
	footStepStartPitch = outdoorFootstep.volume_db
func _process(delta):
	checkCrosshairStatus()
	if(beingAttacked):
		gettingUp = true
		emitBlood()
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
			print("My cross is broken :(")
			#Then also play the cross broke sound
			
		blood.emitting = false
		if(head.position.y < 1.45):
			head.position = lerp(head.position, headPos.position, 0.4 * delta)
			head.rotation_degrees.x = lerpf(head.rotation_degrees.x, 0, 0.6 * delta)
		else: 
			gettingUp = false
			timeSprinting = 0.0
			head.position = Vector3(0,1.5,0)
	head.rotation_degrees.x = clampf(head.rotation_degrees.x, -88, 88) #Limit head roatation to look straight up and down
func _input(event):
	if(not beingAttacked):
		if event is InputEventMouseMotion: #If mouse is moved
			if(Input.is_action_pressed("aimButton")): #If user is not aiming, allow looking around with camera
				if(arm.gunDrawn == true and not arm.reloading and arm.canHoldGunUp == true):
					#xhair_pointer.hide()
					pass
				else:
					head.rotate_x(deg_to_rad(-event.relative.y*lookSensitivity*get_process_delta_time()))
					player.rotate_y(deg_to_rad(-event.relative.x*lookSensitivity*get_process_delta_time()))
			else:
				xhair_pointer.show()
				head.rotate_x(deg_to_rad(-event.relative.y*lookSensitivity*get_process_delta_time()))
				player.rotate_y(deg_to_rad(-event.relative.x*lookSensitivity*get_process_delta_time()))
func _physics_process(delta):
	if(not beingAttacked and not gettingUp): #If the player is being attacked, they're not supposed to be able to move :D
		# Add the gravity.
		if not is_on_floor():
			velocity.y -= gravity * delta
		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var input_dir = Input.get_vector("moveLeft", "moveRight", "moveForward", "moveBack")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction: #If user is moving
			if(Input.is_action_pressed("runButton") and Input.is_action_pressed("moveForward") and arm.gunDrawn == false): #if user is pressing run key and moving forward
				playerRunning.emit() #If the player is running, emit the runnin signal
				velocity.x = direction.x * SPEED * runSpeed *get_process_delta_time()
				velocity.z = direction.z * SPEED * runSpeed *get_process_delta_time()
				running = true
				if(timeSinceLastStep <= maxAllowedSprinting):
					timeSprinting += delta #When running, add elapsed seconds to keep track of how much the player has been running
				if(timeSprinting > maxAllowedSprinting):
					print("I have sprinted too much")
					playerRanTooLong.emit() #If the player has run too long, emit this signal
			elif(arm.gunDrawn):
				running = false
				if(Input.is_action_pressed("aimButton")  and not arm.reloading and arm.canHoldGunUp):
					if(timeSprinting > 0.0):
						timeSprinting -= delta
					velocity.x = move_toward(velocity.x, 0, SPEED)
					velocity.z = move_toward(velocity.z, 0, SPEED)
				else:
					if(timeSprinting > 0.0):
						timeSprinting -= delta
					velocity.x = direction.x * SPEED * gunHoldingSpeed *get_process_delta_time()
					velocity.z = direction.z * SPEED * gunHoldingSpeed *get_process_delta_time()
			else:
				running = false
				if(timeSprinting > 0.0):
					timeSprinting -= delta
				velocity.x = direction.x * SPEED *get_process_delta_time()
				velocity.z = direction.z * SPEED *get_process_delta_time()
		else:
			if(timeSprinting > 0.0):
				timeSprinting -= delta
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
		footSteps(running)
		move_and_slide()
func ShowInspectText(showableText):
	inspect_text.text = showableText
	var textShowLimit = showableText.length() / 5
	inspect_text.show()
	await get_tree().create_timer(textShowLimit).timeout
	inspect_text.hide()
func updateGasAmount(gasAmount : float):
	gasBar.set_value_no_signal(gasBar.value + gasAmount)
	gasBar.visible = true
	await get_tree().create_timer(gasBarVisibleLimit).timeout
	gasBar.visible = false
func getAttacked(wolfAttackPosition : Node3D): #Called, if wolf reaches player
	print("We're getting attacked HUEEEEUUUGH")
	attackScreamSFX.play()
	beingAttacked = true
	pouncePosition = wolfAttackPosition
func attackOver():
	print("We made it bois")
	beingAttacked = false

func checkCrosshairStatus():
	if(interact_ray.is_colliding()):
		var target = interact_ray.get_collider()
		if(interact_ray.get_collider() != null):
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
	await get_tree().create_timer(1.35).timeout
	blood.emitting = true
	shakeable_camera._addTrauma(0.5)

func hideAllCrosshairs():
	xhair_eye.hide()
	pickupXhair.hide()
	interactXhair.hide()

func footSteps(runnin : bool):
	if (velocity.normalized() != Vector3.ZERO):
		timeSinceLastStep += get_process_delta_time()
		footStepPitch = (footStepStartPitch - randi_range(25, 45))
		outdoorFootstep.volume_db = footStepPitch
		indoorFootstep.volume_db = footStepPitch
		if(runnin):
			if timeSinceLastStep >= stepWalkInterval / 2:
				timeSinceLastStep = 0.0
				if(isIndoors):
					indoorFootstep.play()
				else: outdoorFootstep.play()
		else:
			if timeSinceLastStep >= stepWalkInterval:
				timeSinceLastStep = 0.0
				if(isIndoors):
					indoorFootstep.play()
				else: outdoorFootstep.play()
