# res://scripts/objects/zomborg.gd
extends CharacterBody2D

# --- NEW SIGNAL ---
signal died # Emitted when health reaches zero, before queue_free

# --- EXPORTS ---
# ... (Keep existing exports) ...
@export var move_speed: float = 150.0
@export var health: int = 3
@export var min_sound_interval: float = 2.0
@export var max_sound_interval: float = 6.0
@export var attack_damage: int = 10
@export var zmb_sounds: Array[AudioStream]
@export var splat_sound: AudioStream
@export var salvage_scene: PackedScene
@export var drop_chance: float = 0.75

# --- NODES ---
# ... (Keep existing node refs) ...
@onready var sprite = $ZomborgSprite
@onready var hitbox_area = $HitboxArea
@onready var sound_timer = $SoundTimer
@onready var sound_player = $SoundPlayer
@onready var splat_sound_player = $SplatSoundPlayer

# --- INTERNAL ---
# ... (Keep existing internal vars) ...
var player = null
var possible_drops = ["foot", "claw", "core"]

func _ready():
	# ... (Keep existing _ready code) ...
	player = get_tree().get_first_node_in_group("player")
	if player == null: printerr("Zomborg couldn't find 'player' group!")

	if hitbox_area == null: printerr("ERROR: HitboxArea node not found!")
	else:
		if not hitbox_area.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox_area.area_entered.connect(_on_hitbox_area_entered)

	if sound_timer == null: printerr("ERROR: SoundTimer node not found!")
	else:
		if not sound_timer.timeout.is_connected(_on_sound_timer_timeout):
			sound_timer.timeout.connect(_on_sound_timer_timeout)
		_randomize_sound_timer()

	if sound_player == null: printerr("ERROR: SoundPlayer node not found!")
	if zmb_sounds == null or zmb_sounds.is_empty(): printerr("WARN: Zomborg Sounds missing!")
	if splat_sound_player == null: printerr("WARN: SplatSoundPlayer node missing!")
	elif splat_sound == null: printerr("WARN: Splat Sound missing!")
	else: splat_sound_player.stream = splat_sound

	if salvage_scene == null: printerr("Zomborg WARN: Salvage Scene not assigned!")


func _physics_process(_delta):
	# ... (Keep existing physics process) ...
	if player == null or is_queued_for_deletion(): return

	var direction_to_player = (player.global_position - global_position).normalized()
	velocity = direction_to_player * move_speed
	look_at(player.global_position)
	move_and_slide()

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision:
			var collider = collision.get_collider()
			if collider != null and collider == player:
				if collider.has_method("take_damage"): collider.take_damage(attack_damage)
				break

func _on_hitbox_area_entered(area):
	# ... (Keep existing area entered) ...
	if area.is_in_group("bullets"):
		take_damage(1)
		area.queue_free()

func take_damage(amount: int):
	# ... (Keep existing take damage, but check health <= 0 *before* calling die) ...
	if health <= 0: return
	health -= amount

	if splat_sound_player != null and splat_sound_player.stream != null:
		splat_sound_player.pitch_scale = randf_range(0.9, 1.1)
		splat_sound_player.play()

	if sprite:
		sprite.modulate = Color(1, 0.5, 0.5)
		get_tree().create_timer(0.1).timeout.connect(_reset_color)

	if health <= 0:
		die() # Call die only when health actually drops to 0 or below

func _reset_color():
	# ... (Keep existing reset color) ...
	if is_instance_valid(self) and sprite != null:
		sprite.modulate = Color(1, 1, 1)

func die():
	# --- Emit Signal BEFORE queue_free ---
	emit_signal("died")
	
	# --- Original die logic ---
	if is_queued_for_deletion(): return # Still good to prevent multiple actions
	if sound_timer: sound_timer.stop()
	if sound_player: sound_player.stop()
	_try_drop_salvage()
	call_deferred("queue_free")


func _try_drop_salvage():
	# ... (Keep existing salvage drop) ...
	if salvage_scene == null or randf() >= drop_chance: return
	if possible_drops.is_empty(): printerr("Zomborg Error: possible_drops empty!"); return

	var chosen_drop_type = possible_drops.pick_random()
	var salvage_instance = salvage_scene.instantiate()

	if not salvage_instance is Area2D:
		printerr("Salvage Drop Error: Instantiated scene not Area2D!")
		salvage_instance.queue_free()
		return

	salvage_instance.salvage_type = chosen_drop_type
	salvage_instance.global_position = global_position

	var salvage_container = get_tree().get_first_node_in_group("salvage_container")
	if salvage_container:
		salvage_container.call_deferred("add_child", salvage_instance)
	else:
		printerr("Salvage Drop WARN: 'salvage_container' group node not found.")


func _randomize_sound_timer():
	# ... (Keep existing randomize timer) ...
	if sound_timer:
		sound_timer.wait_time = randf_range(min_sound_interval, max_sound_interval)
		sound_timer.start()

func _on_sound_timer_timeout():
	# ... (Keep existing sound timeout) ...
	if sound_player and zmb_sounds != null and not zmb_sounds.is_empty() and not sound_player.playing:
		var random_sound = zmb_sounds.pick_random()
		if random_sound is AudioStream:
			sound_player.stream = random_sound
			sound_player.pitch_scale = randf_range(0.85, 1.15)
			sound_player.play()
		else: printerr("WARN: Zomborg sound array element not AudioStream!")
	_randomize_sound_timer()
