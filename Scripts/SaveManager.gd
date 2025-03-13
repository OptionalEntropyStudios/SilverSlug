extends Node

var savePath = "user://variables.save"
var player
var gun
#Here we will have all the things we want to save from the player
var hasGunState
var loadedAmmoState
var reserveAmmoState
# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_tree().get_first_node_in_group("player")
	gun = get_tree().get_first_node_in_group("gun")
	print(player.name)
	print(gun.name)
	loadStats()
	print("hasGunState is " + str(hasGunState))
	print("loadedAmmoState = " + str(loadedAmmoState))
	print("reserveAmmoState = " + str(reserveAmmoState))
# Called every frame. 'delta' is the elapsed time since the previous frame.
func updateStats():
	hasGunState = gun.hasGun
	loadedAmmoState = gun.loadedAmmo
	reserveAmmoState = gun.reserveAmmo

func saveStats():
	updateStats()
	var saveFile = FileAccess.open(savePath, FileAccess.WRITE)
	saveFile.store_var(hasGunState)
	saveFile.store_var(loadedAmmoState)
	saveFile.store_var(reserveAmmoState)

func loadStats():
	if(FileAccess.file_exists(savePath)):
		var saveFile = FileAccess.open(savePath, FileAccess.READ)
		hasGunState = saveFile.get_var(hasGunState)
		loadedAmmoState = saveFile.get_var(loadedAmmoState)
		reserveAmmoState = saveFile.get_var(reserveAmmoState)
	else:
		print("WE AINT GOT NO DATA BROOO")
		hasGunState = false
		loadedAmmoState = 0
		reserveAmmoState = 0
	gun.hasGun = hasGunState
	gun.loadedAmmo = loadedAmmoState
	gun.reserveAmmo = reserveAmmoState
