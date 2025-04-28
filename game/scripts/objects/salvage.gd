# res://scripts/objects/salvage.gd
extends Area2D

# --- EXPORTS ---
@export var foot_texture: Texture2D
@export var claw_texture: Texture2D
@export var core_texture: Texture2D
@export var pickup_sound: AudioStream
@export var despawn_time: float = 10.0
# --- NEW: Blinking Effect ---
@export var blink_start_time_before_despawn: float = 3.0 # Start blinking X seconds before despawn
@export var blink_frequency: float = 4.0 # How many blinks per second (approx)

# --- NODES ---
@onready var sprite: Sprite2D = $SalvageSprite
@onready var despawn_timer: Timer = $DespawnTimer
@onready var pickup_sound_player: AudioStreamPlayer2D = $PickupSoundPlayer
@onready var collision_shape: CollisionShape2D = $PickupShape

# --- INTERNAL ---
var salvage_type: String = "unknown"
var collected: bool = false
var is_blinking: bool = false # Track if blinking effect should be active

func _ready():
	# --- Null Checks ---
	if sprite == null: printerr("Salvage Error: Sprite node missing!")
	if despawn_timer == null: printerr("Salvage Error: DespawnTimer node missing!")
	if pickup_sound_player == null: printerr("Salvage Error: PickupSoundPlayer missing!")
	if collision_shape == null: printerr("Salvage Error: PickupShape missing!")

	# --- Setup Sprite Based on Type ---
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
			if sprite: sprite.visible = false # Hide if type is invalid

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
		# Ensure start time is valid
		if blink_start_time_before_despawn >= despawn_time:
			printerr("Salvage WARN: Blink start time >= despawn time. Disabling blink.")
			blink_start_time_before_despawn = -1.0 # Disable blinking
			
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


# Process is called every frame
func _process(delta):
	# Don't process if collected, blinking disabled, or essential nodes missing
	if collected or blink_start_time_before_despawn < 0 or despawn_timer == null or sprite == null:
		return

	# Check if we should start/continue blinking
	if despawn_timer.time_left <= blink_start_time_before_despawn:
		is_blinking = true
		# Calculate alpha using sine wave for smooth blinking
		# time_left goes from blink_start_time down to 0
		# We map this to a cycling value using sine
		var time_since_blink_start = blink_start_time_before_despawn - despawn_timer.time_left
		# sin value cycles between -1 and 1. Add 1 to make it 0 to 2. Divide by 2 for 0 to 1.
		var alpha = (sin(time_since_blink_start * blink_frequency * TAU / 2.0) + 1.0) / 2.0 
		# Optional: Make the fade more pronounced (e.g., minimum alpha 0.3)
		alpha = lerp(0.3, 1.0, alpha) 
		
		sprite.modulate.a = alpha # Modulate only the alpha component
	elif is_blinking:
		# If timer somehow reset or time increased past threshold, stop blinking
		is_blinking = false
		sprite.modulate.a = 1.0 # Reset alpha to fully visible


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
		
		# Reset modulation before hiding (good practice)
		if sprite: sprite.modulate.a = 1.0
		visible = false 
		collision_shape.set_deferred("disabled", true)

		if pickup_sound_player.stream != null:
			pickup_sound_player.play(0)
		else:
			call_deferred("queue_free")


func _on_despawn_timer_timeout():
	if not collected:
		#print("Salvage despawned: ", salvage_type) # Reduce console spam
		queue_free()
