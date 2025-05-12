extends Node3D
@onready var fpsCamera = $"../shakeable_camera"
#@onready var fpsCamera = $"../shakeable_camera"
@export var hasGun : bool = false
@onready var holstered_position = $"../HolsteredPosition"
@onready var shoot_ray = $shotgun/ShootRay #Ray for detecting if the gun can hit something
@onready var gun_clip_check_ray = $"../GunClipCheckRay" #Ray for checking if gun is clipping
@onready var ammo_text = $"../../CanvasLayer/AmmoText" #Tells the player the amount of ammo
@onready var muzzle_flash = $shotgun/MuzzleFlash
@onready var poof_effect = $shotgun/PoofEffect
@onready var shotgun = $shotgun
@onready var player = $"../.."

signal gunReadied #We shall emit this, when the player is holding their gun up, when the wolf is stalking
var wolfOnScreen : bool
@export var gunReadiedThreshold : float = -7.0 #The limit at which the gun will register as readied
signal gunShot #We shall emit this, if the player hits the wolf
signal gunFiredForNoReasonAtAll
@onready var gunSound = $shotgun/GunShotSFX
@onready var emptyClickSound = $shotgun/EmptyClickSound

var readyRotation = basis.get_euler()
var readyPosition = self.position
var holsteredRotation
var holsteredPosition

@export var equipSpeed : float = 1#How fast the gun is equipped from being holstered
@export var holsterSpeed : float = .85#How fast the gun is holstered
@export var aimSpeed : float = 13 #How fast the gun can be aimed around
@export var returnSpeed : float = .5 #How fast the gun returns to ready position when stopped aiming

@export var traumaAmount = 0.6
var recoilPositionZ
var recoilRotationX #How much the gun tilts when fired
var gunStartZPosition
@export var recoilReturnSpeed = 1.6 #How fast the gun returns to position when fired

var gunDrawn : bool
var reloading : bool
var reloadFunctionCalled : bool
var isReloadSoundQueued : bool
@onready var gunReloadSFX = $shotgun/GunReloadSound
@export var reloadTime : float = 3.65 #How long reloading takes after the gun is lowered
@export var reloadSoundDelay : float = 1.4
@export var loadedAmmo : int = 0
@export var reserveAmmo : int = 0

@export var gunHoldLimit : float = 10.0 #How long the gun can be aimed around
var gunHeldTime : float = 0.0 #How long the gun has been held up
var canHoldGunUp : bool = false
var flashTime = 0.05
# Called when the node enters the scene tree for the first time.
func _ready():
	gunStartZPosition = self.position.z
	recoilRotationX = 0.2
	recoilPositionZ = gunStartZPosition + 0.3
	muzzle_flash.visible = false
	poof_effect.emitting = false
	updateAmmoText()
	gunDrawn = false
	reloading = false
	reloadFunctionCalled = false
	isReloadSoundQueued = false
	holsteredRotation = holstered_position.rotation
	holsteredPosition = holstered_position.position
@warning_ignore("unused_parameter")

#FOR DEBUG
var prevReloadState
func _process(delta):
	self.visible = hasGun
	if(hasGun):
		var wantToAim = Input.is_action_pressed("aimButton")
		if(!player.beingAttacked):
			if(Input.is_action_just_pressed("holsterButton") and not reloading):
				gunDrawn = !gunDrawn
			if(!wantToAim || !canHoldGunUp):
				if(gunHeldTime > 0.0):
					gunHeldTime -= get_process_delta_time() * 2 #We remove 2 seconds per second from the time held
				if(gunHeldTime <= 0.05): canHoldGunUp = true #If the held time has reset to close zero, we can hold it up again.
			if(gunDrawn): 
				if(self.position.z > gunStartZPosition):
					self.position.z = lerpf(self.position.z, gunStartZPosition, recoilReturnSpeed * delta)
				ammo_text.show()
				if(!gun_clip_check_ray.is_colliding()):
					_readyPosition()
					if(Input.is_action_just_pressed("reloadButton") and reserveAmmo > 0 and not reloading):
						print("player wants to and we can reload")
						reloading = true
						gunNotLowered = true
					if(reloading and gunNotLowered):
						reloadGun()
					if(Input.is_action_just_pressed("fireButton") and not reloading and wantToAim):
						shootGun()
				else: holsterPosition()
			else:
				ammo_text.hide()
				holsterPosition()
			self.rotation.z = 0
		else:
			holsterPosition()
			ammo_text.hide()
	else: 
		holsterPosition()
		ammo_text.hide()
func _input(event):
	if (event is InputEventMouseMotion):
		if(gunDrawn and not reloading): ##If the gun is drawn, rotate it with the mouse movement.
			self.rotate_x(deg_to_rad(-event.screen_relative.y * aimSpeed * get_process_delta_time()))
			self.rotate_y(deg_to_rad(-event.screen_relative.x * aimSpeed * get_process_delta_time())) 
func _readyPosition(): #If the gun is drawn, keep gun in drawn position and clamp its rotation
	if(not reloading):
		var wantToAim = Input.is_action_pressed("aimButton")
		if(wantToAim and canHoldGunUp): #If player wants to aim and they can hold the gun up, we aim
			gunHeldTime += get_process_delta_time()
			if(self.rotation_degrees.x > gunReadiedThreshold): #If the gun's rotation is above this threshold, it will register as being readied
				if(wolfOnScreen):
					gunReadied.emit() #Emit gunReadied signal, that will be picked up by werewolf to react to it.
			if(gunHeldTime >= gunHoldLimit): canHoldGunUp = false #If we have held the gun up for 25 seconds, cannot hold longer
		else:
			self.rotation.x = lerpf(self.rotation.x, readyRotation.x, returnSpeed * get_process_delta_time())
			self.rotation.y = lerpf(self.rotation.y, readyRotation.y, returnSpeed * get_process_delta_time())
			if(gunHeldTime > 0.0):
				gunHeldTime -= get_process_delta_time() * 2 #We remove 2 seconds per second from the time held
		if(gunHeldTime <= 0): 
			canHoldGunUp = true #If the held time has reset to close zero, we can hold it up again.
		self.rotation.x = clampf(self.rotation.x, deg_to_rad(-25), deg_to_rad(10))
		self.rotation.y = clampf(self.rotation.y, deg_to_rad(-20), deg_to_rad(20))
		self.position.y = lerpf(self.position.y, readyPosition.y, equipSpeed * get_process_delta_time())
func shootGun(): #Fire the gun and decrease the ammo amount
	if(loadedAmmo > 0):
		var hitWolf : bool = false
		poof_effect.emitting = true;
		self.rotation.x += recoilRotationX
		self.position.z = recoilPositionZ
		gunSound.play()
		fpsCamera._addTrauma(traumaAmount)
		loadedAmmo -= 1
		updateAmmoText()
		muzzleFlashEffect()
		if(shoot_ray.is_colliding()):
			var hit_object = shoot_ray.get_collider()
			print("The gun has hit ", hit_object.name)
			if(hit_object.is_in_group("wolf")):
				gunShot.emit()
				hitWolf = true
		if(!hitWolf):
			gunFiredForNoReasonAtAll.emit()
			print("gunFiredForNoReasonAtAll emitted")
	else:
		emptyClickSound.play()
var gunNotLowered
func reloadGun():#Lower the gun and "reload it" and return it back up.
	if(gunNotLowered):
		if(position.y > holsteredPosition.y + .05):
			holsterPosition()
		else: gunNotLowered = false
	if(!gunReloadSFX.is_playing()):
		gunReloadSFX.play()


func holsterPosition():
	self.rotation.x = lerpf(self.rotation.x, holsteredRotation.x, holsterSpeed * get_process_delta_time())
	self.rotation.y = lerpf(self.rotation.y, holsteredRotation.y, holsterSpeed * get_process_delta_time())
	self.position.y = lerpf(self.position.y, holsteredPosition.y, holsterSpeed * get_process_delta_time())
func updateAmmoText():
	ammo_text.text = str(loadedAmmo) + " / " + str(reserveAmmo)
func muzzleFlashEffect():
	muzzle_flash.visible = true
	@warning_ignore("redundant_await")
	await get_tree().create_timer(flashTime).timeout
	muzzle_flash.visible = false

func onWolfVisibleOnScreen():
	print("The wolf is on screen")
	wolfOnScreen = true

func onWolfLeftScreen():
	print("The wolf is off screen")
	wolfOnScreen = false

func gunFinishedReloading() -> void:
	reloading = false
	loadedAmmo = 1
	reserveAmmo -= 1
	updateAmmoText()
