# res://scripts/objects/salvage.gd
extends Area2D

# --- EXPORTS ---
@export var foot_texture: Texture2D
@export var claw_texture: Texture2D
@export var core_texture: Texture2D
@export var pickup_sound: AudioStream
@export var despawn_time: float = 10.0

# --- NODES ---
@onready var sprite: Sprite2D = $SalvageSprite
@onready var despawn_timer: Timer = $DespawnTimer
@onready var pickup_sound_player: AudioStreamPlayer2D = $PickupSoundPlayer
@onready var collision_shape: CollisionShape2D = $PickupShape

# --- INTERNAL ---
# This variable will be set by the Zomborg *before* _ready is called
var salvage_type: String = "unknown" 
var collected: bool = false

func _ready():
	# --- Null Checks ---
	# @onready vars are now guaranteed to be ready here (or will error before)
	if sprite == null: printerr("Salvage Error: Sprite node missing!") # Should not happen if node exists
	if despawn_timer == null: printerr("Salvage Error: DespawnTimer node missing!")
	if pickup_sound_player == null: printerr("Salvage Error: PickupSoundPlayer missing!")
	if collision_shape == null: printerr("Salvage Error: PickupShape missing!")

	# --- Setup Sprite Based on Type ---
	# The 'salvage_type' variable should have been set by the Zomborg by now
	print("Salvage Ready. Type: ", salvage_type) # DEBUG
	match salvage_type:
		"foot":
			if foot_texture: sprite.texture = foot_texture
			else: printerr("Salvage Error: Foot Texture not assigned!")
		"claw":
			if claw_texture: sprite.texture = claw_texture
			else: printerr("Salvage Error: Claw Texture not assigned!")
		"core":
			if core_texture: sprite.texture = core_texture
			else: printerr("Salvage Error: Core Texture not assigned!")
		_:
			printerr("Salvage Error: Unknown salvage type in _ready: ", salvage_type)
			sprite.visible = false # Hide if type is invalid

	# --- DEBUG: Check visibility after setting texture ---
	if sprite:
		print("Salvage Ready. Sprite Visibility: ", sprite.visible)


	# --- Setup Pickup Sound ---
	if pickup_sound == null: printerr("Salvage WARN: Pickup Sound not assigned!")
	elif pickup_sound_player:
		pickup_sound_player.stream = pickup_sound
		pickup_sound_player.playing = false
		pickup_sound_player.autoplay = false
		if not pickup_sound_player.finished.is_connected(call_deferred.bind("queue_free")):
			pickup_sound_player.finished.connect(call_deferred.bind("queue_free"))

	# --- Setup Despawn Timer ---
	if despawn_timer:
		despawn_timer.wait_time = despawn_time
		despawn_timer.one_shot = true
		if not despawn_timer.timeout.is_connected(_on_despawn_timer_timeout):
			var error_code = despawn_timer.timeout.connect(_on_despawn_timer_timeout)
			if error_code != OK: printerr("Salvage Error: Failed connect despawn timer: ", error_code)
		despawn_timer.start()

	# --- Connect Area Entered Signal ---
	if not area_entered.is_connected(_on_area_entered):
		var error_code = area_entered.connect(_on_area_entered)
		if error_code != OK: printerr("Salvage Error: Failed connect area_entered: ", error_code)


# REMOVED the initialize(type) function


func _on_area_entered(other_area):
	if collected or pickup_sound_player == null or collision_shape == null: return

	var parent_node = other_area.get_parent()
	if parent_node != null and parent_node.is_in_group("player"):
		collected = true

		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager and game_manager.has_method("collect_salvage"):
			game_manager.collect_salvage(salvage_type)
		else: printerr("Salvage Error: Game manager missing/invalid!")

		if despawn_timer: despawn_timer.stop()
		visible = false
		collision_shape.set_deferred("disabled", true)

		if pickup_sound_player.stream != null:
			pickup_sound_player.play(0)
		else:
			call_deferred("queue_free")


func _on_despawn_timer_timeout():
	if not collected:
		print("Salvage despawned: ", salvage_type)
		queue_free()
