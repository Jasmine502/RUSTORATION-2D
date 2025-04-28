# res://scripts/objects/zomborg.gd
extends CharacterBody2D

signal died # Emitted when health reaches zero, before queue_free

# --- EXPORTS ---
@export var base_health: int = 3
@export var base_speed: float = 150.0
@export var base_attack_damage: int = 10
@export var stat_variation_percent: float = 0.15
@export var focus_bonus_multiplier: float = 1.6
@export var min_sound_interval: float = 2.0
@export var max_sound_interval: float = 6.0
@export var zmb_sounds: Array[AudioStream]
@export var splat_sound: AudioStream
@export var salvage_scene: PackedScene
@export var drop_chance: float = 0.75

# --- NODES ---
@onready var sprite = $ZomborgSprite
@onready var hitbox_area = $HitboxArea
@onready var sound_timer = $SoundTimer
@onready var sound_player = $SoundPlayer
@onready var splat_sound_player = $SplatSoundPlayer

# --- INTERNAL ---
var player = null
var actual_health: int
var actual_max_health: int
var actual_speed: float
var actual_attack_damage: int
var determined_drop_type: String = "unknown"


func initialize(p_base_health: int, p_base_speed: float, p_base_attack_damage: int, focus_type: String):
	var health_variation = p_base_health * stat_variation_percent
	actual_max_health = int(randf_range(p_base_health - health_variation, p_base_health + health_variation))
	actual_max_health = max(1, actual_max_health)
	actual_health = actual_max_health

	var speed_variation = p_base_speed * stat_variation_percent
	actual_speed = randf_range(p_base_speed - speed_variation, p_base_speed + speed_variation)
	actual_speed = max(10.0, actual_speed)

	var damage_variation = float(p_base_attack_damage) * stat_variation_percent
	actual_attack_damage = int(randf_range(p_base_attack_damage - damage_variation, p_base_attack_damage + damage_variation))
	actual_attack_damage = max(1, actual_attack_damage)

	var initial_health = actual_max_health
	var initial_speed = actual_speed
	var initial_damage = actual_attack_damage
	
	match focus_type.to_lower():
		"speed": actual_speed *= focus_bonus_multiplier
		"damage": actual_attack_damage = int(float(actual_attack_damage) * focus_bonus_multiplier); actual_attack_damage = max(1, actual_attack_damage)
		"health": actual_max_health = int(float(actual_max_health) * focus_bonus_multiplier); actual_max_health = max(1, actual_max_health); actual_health = actual_max_health

	var health_boost = float(actual_max_health) / float(initial_health) if initial_health > 0 else 1.0
	var speed_boost = actual_speed / initial_speed if initial_speed > 0 else 1.0
	var damage_boost = float(actual_attack_damage) / float(initial_damage) if initial_damage > 0 else 1.0
	var max_boost = max(health_boost, max(speed_boost, damage_boost))
	var tolerance = 0.001 
	
	if abs(max_boost - health_boost) < tolerance: determined_drop_type = "core"
	elif abs(max_boost - damage_boost) < tolerance: determined_drop_type = "claw"
	else: determined_drop_type = "foot"


func _ready():
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
	if player == null or is_queued_for_deletion(): return

	var direction_to_player = (player.global_position - global_position).normalized()
	velocity = direction_to_player * actual_speed
	look_at(player.global_position)
	move_and_slide()

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision:
			var collider = collision.get_collider()
			if collider != null and collider == player:
				if collider.has_method("take_damage"):
					collider.take_damage(actual_attack_damage)
				break

# --- Corrected Function - Attempt 2 (Using 'in') ---
func _on_hitbox_area_entered(area):
	# Check group first
	if area.is_in_group("bullets"):
		var bullet_damage = 1 # Default damage
		# Check if the 'damage' property exists on the bullet instance
		if "damage" in area: 
			bullet_damage = area.damage
		else:
			printerr("WARN: Bullet instance entering Zomborg hitbox is missing 'damage' property!")
			
		take_damage(bullet_damage) 
		
		# Destroy the bullet that hit
		area.queue_free() 

func take_damage(amount: int):
	if actual_health <= 0: return
	actual_health -= amount

	if splat_sound_player != null and splat_sound_player.stream != null:
		splat_sound_player.pitch_scale = randf_range(0.9, 1.1)
		splat_sound_player.play()

	if sprite:
		sprite.modulate = Color(1, 0.5, 0.5)
		get_tree().create_timer(0.1).timeout.connect(_reset_color)

	if actual_health <= 0:
		die()

func _reset_color():
	if is_instance_valid(self) and sprite != null:
		sprite.modulate = Color(1, 1, 1)

func die():
	emit_signal("died")
	if is_queued_for_deletion(): return
	if sound_timer: sound_timer.stop()
	if sound_player: sound_player.stop()
	_try_drop_salvage()
	call_deferred("queue_free")


func _try_drop_salvage():
	if salvage_scene == null or randf() >= drop_chance: return
	if determined_drop_type == "unknown":
		printerr("Zomborg Error: Drop type was not determined correctly!")
		return

	var salvage_instance = salvage_scene.instantiate()
	if not salvage_instance is Area2D:
		printerr("Salvage Drop Error: Instantiated scene not Area2D!")
		salvage_instance.queue_free(); return

	salvage_instance.salvage_type = determined_drop_type
	salvage_instance.global_position = global_position

	var salvage_container = get_tree().get_first_node_in_group("salvage_container")
	if salvage_container:
		salvage_container.call_deferred("add_child", salvage_instance)
	else: printerr("Salvage Drop WARN: 'salvage_container' group node not found.")


func _randomize_sound_timer():
	if sound_timer:
		sound_timer.wait_time = randf_range(min_sound_interval, max_sound_interval)
		sound_timer.start()

func _on_sound_timer_timeout():
	if sound_player and zmb_sounds != null and not zmb_sounds.is_empty() and not sound_player.playing:
		var random_sound = zmb_sounds.pick_random()
		if random_sound is AudioStream:
			sound_player.stream = random_sound
			sound_player.pitch_scale = randf_range(0.85, 1.15)
			sound_player.play()
		else: printerr("WARN: Zomborg sound array element not AudioStream!")
	_randomize_sound_timer()
