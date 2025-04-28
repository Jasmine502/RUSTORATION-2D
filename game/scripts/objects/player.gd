# res://scripts/objects/Player.gd
extends CharacterBody2D

signal stats_updated(current_health, current_max_health)
signal player_died

# --- EXPORTS ---
@export var base_move_speed: float = 300.0
@export var base_max_health: int = 100
@export var base_bullet_damage: int = 1 # Starting damage is effectively Tier 0

@export var acceleration: float = 1500.0
@export var friction: float = 1200.0
@export var shoot_cooldown: float = 0.2
@export var bullet_scene: PackedScene
@export var damage_cooldown_time: float = 0.5

# Stat increase *per Tier* (adjust these values for balance)
@export var speed_increase_per_tier: float = 40.0
@export var damage_increase_per_tier: int = 1
@export var health_increase_per_tier: int = 25

# Exported Sounds/Textures (Keep as before)
@export var hurt_sound: AudioStream
@export var shoot_sound: AudioStream
@export var normal_texture: Texture2D
@export var shooting_texture: Texture2D
@export var hurt_texture: Texture2D

# --- INTERNAL VARIABLES ---
var can_shoot: bool = true
var current_health: int
var can_take_damage: bool = true

# Actual stats derived from Tiers
var current_move_speed: float
var current_max_health: int
var current_bullet_damage: int

# --- NEW: Tier and Upgrade Point Tracking ---
var health_tier: int = 0
var damage_tier: int = 0
var speed_tier: int = 0
# Points accumulated towards the *next* tier
var health_upgrade_points: int = 0
var damage_upgrade_points: int = 0
var speed_upgrade_points: int = 0
# Base cost for Tier 0 -> Tier 1 (matches Game.gd/UpgradeScreen.gd)
var upgrade_base_cost = 5 
# Cost scaling factor per tier (matches Game.gd/UpgradeScreen.gd)
var upgrade_cost_increase_per_tier = 3 


# --- NODES ---
@onready var sprite: Sprite2D = $PlayerSprite
@onready var muzzle = $Muzzle
@onready var shoot_timer = $ShootTimer
@onready var damage_cooldown_timer = $DamageCooldownTimer
@onready var hurt_sound_player = $HurtSoundPlayer
@onready var shoot_sound_player = $ShootSoundPlayer
@onready var shoot_sprite_timer = $ShootSpriteTimer

func _ready():
	# Calculate initial stats based on Tier 0
	_recalculate_stats()
	# Fully heal at the start
	current_health = current_max_health
	
	emit_signal("stats_updated", current_health, current_max_health)

	if sprite and normal_texture: sprite.texture = normal_texture
	elif sprite: printerr("WARN: Player Normal Texture not assigned!")
	# Null Checks and Setup... (Keep as before)
	if shoot_timer == null: printerr("ERROR: ShootTimer node not found!")
	else: shoot_timer.wait_time = shoot_cooldown; shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	if damage_cooldown_timer == null: printerr("ERROR: DamageCooldownTimer node not found!")
	else: damage_cooldown_timer.wait_time = damage_cooldown_time; damage_cooldown_timer.one_shot = true; damage_cooldown_timer.timeout.connect(_on_damage_cooldown_timer_timeout)
	if shoot_sprite_timer == null: printerr("ERROR: ShootSpriteTimer node not found!")
	else: shoot_sprite_timer.wait_time = 0.1; shoot_sprite_timer.one_shot = true; shoot_sprite_timer.timeout.connect(_on_shoot_sprite_timer_timeout)
	if hurt_sound_player == null: printerr("WARN: HurtSoundPlayer node not found!")
	elif hurt_sound == null: printerr("WARN: Hurt Sound not assigned!")
	else: hurt_sound_player.stream = hurt_sound
	if shoot_sound_player == null: printerr("WARN: ShootSoundPlayer node not found!")
	elif shoot_sound == null: printerr("WARN: Shoot Sound not assigned!")
	else: shoot_sound_player.stream = shoot_sound


func _physics_process(delta):
	# ... (No changes needed here, uses current_move_speed) ...
	if current_health <= 0:
		if is_physics_processing(): set_physics_process(false); return
	if sprite == null or muzzle == null: printerr("ERROR: Player nodes missing!"); if is_physics_processing(): set_physics_process(false); return
	look_at(get_global_mouse_position())
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity = input_direction * current_move_speed
	if input_direction != Vector2.ZERO: velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else: velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	if shoot_timer != null and Input.is_action_pressed("shoot") and can_shoot:
		if shoot_sound_player != null and shoot_sound_player.stream != null: shoot_sound_player.pitch_scale = randf_range(0.9, 1.1); shoot_sound_player.play()
		if sprite and shooting_texture: sprite.texture = shooting_texture; if shoot_sprite_timer: shoot_sprite_timer.start()
		elif sprite: printerr("WARN: Player Shooting Texture not assigned!")
		_shoot(); can_shoot = false; shoot_timer.start()


func _shoot():
	# ... (Uses current_bullet_damage) ...
	if muzzle == null: printerr("ERROR: Muzzle node null!"); return
	if not bullet_scene: printerr("Bullet scene not set!"); return
	var bullet_instance = bullet_scene.instantiate()
	if "damage" in bullet_instance: bullet_instance.damage = current_bullet_damage
	else: printerr("WARN: Bullet missing 'damage' property!")
	if bullet_instance.has_method("start"): bullet_instance.start(muzzle.global_position, transform.x)
	else: printerr("Bullet instance missing start()"); bullet_instance.global_position = muzzle.global_position
	if get_parent() == null: printerr("ERROR: Player has no parent!"); return
	get_parent().call_deferred("add_child", bullet_instance)


func _on_shoot_timer_timeout(): can_shoot = true
func _on_shoot_sprite_timer_timeout():
	if sprite and normal_texture and can_take_damage: sprite.texture = normal_texture
	elif sprite and not normal_texture: printerr("WARN: Player Normal Texture not assigned!")

func take_damage(amount: int):
	# ... (Uses current_health and current_max_health) ...
	if not can_take_damage: return
	current_health -= amount; current_health = max(current_health, 0)
	emit_signal("stats_updated", current_health, current_max_health)
	can_take_damage = false
	if damage_cooldown_timer != null: damage_cooldown_timer.start()
	else: printerr("Damage cooldown timer missing!")
	if sprite and hurt_texture: sprite.texture = hurt_texture
	elif sprite: printerr("WARN: Player Hurt Texture not assigned!")
	if hurt_sound_player != null and hurt_sound_player.stream != null: hurt_sound_player.pitch_scale = randf_range(0.95, 1.05); hurt_sound_player.play()
	if current_health <= 0: die()

func _on_damage_cooldown_timer_timeout():
	can_take_damage = true; if sprite and normal_texture: sprite.texture = normal_texture

func die():
	# ... (Die logic remains mostly the same) ...
	print("Player Died!"); emit_signal("player_died")
	if is_physics_processing(): set_physics_process(false)
	if is_processing(): set_process(false)
	if sprite != null: sprite.modulate = Color(0.5, 0.5, 0.5, 0.8)
	var collision_shape = $CollisionShape2D
	if collision_shape: collision_shape.set_deferred("disabled", true)

func get_current_health() -> int: return current_health
func get_current_max_health() -> int: return current_max_health

# --- NEW: Stat Recalculation ---
func _recalculate_stats():
	current_max_health = base_max_health + health_tier * health_increase_per_tier
	current_move_speed = base_move_speed + float(speed_tier) * speed_increase_per_tier # Use float for speed tier calc
	current_bullet_damage = base_bullet_damage + damage_tier * damage_increase_per_tier
	# Ensure stats don't go below base (shouldn't happen with this logic, but safe)
	current_max_health = max(base_max_health, current_max_health)
	current_move_speed = max(base_move_speed, current_move_speed)
	current_bullet_damage = max(base_bullet_damage, current_bullet_damage)
	
	print("Stats Recalculated: H T%d (%d), D T%d (%d), S T%d (%.1f)" % [health_tier, current_max_health, damage_tier, current_bullet_damage, speed_tier, current_move_speed])

# --- NEW: Upgrade Cost Calculation ---
func _get_cost_for_next_tier(current_tier: int) -> int:
	return upgrade_base_cost + current_tier * upgrade_cost_increase_per_tier

# --- NEW: Function called by Game.gd to add points ---
func add_upgrade_point(stat_type: String):
	match stat_type:
		"health":
			var cost_needed = _get_cost_for_next_tier(health_tier)
			health_upgrade_points += 1 # Always add a point when upgrade is bought
			print("Added health point. Progress: %d/%d" % [health_upgrade_points, cost_needed])
			if health_upgrade_points >= cost_needed:
				health_tier += 1
				health_upgrade_points -= cost_needed # Subtract cost, carry over extra points
				print(">>> HEALTH TIER UP! New Tier: %d <<<" % health_tier)
				_recalculate_stats()
				# Heal player to new max when health tier increases
				current_health = current_max_health 
				# Emit signal immediately after tier up
				emit_signal("stats_updated", current_health, current_max_health)
		"damage":
			var cost_needed = _get_cost_for_next_tier(damage_tier)
			damage_upgrade_points += 1
			print("Added damage point. Progress: %d/%d" % [damage_upgrade_points, cost_needed])
			if damage_upgrade_points >= cost_needed:
				damage_tier += 1
				damage_upgrade_points -= cost_needed
				print(">>> DAMAGE TIER UP! New Tier: %d <<<" % damage_tier)
				_recalculate_stats()
		"speed":
			var cost_needed = _get_cost_for_next_tier(speed_tier)
			speed_upgrade_points += 1
			print("Added speed point. Progress: %d/%d" % [speed_upgrade_points, cost_needed])
			if speed_upgrade_points >= cost_needed:
				speed_tier += 1
				speed_upgrade_points -= cost_needed
				print(">>> SPEED TIER UP! New Tier: %d <<<" % speed_tier)
				_recalculate_stats()

# --- NEW: Function for Game.gd to get stats for UI ---
func get_stats_for_ui() -> Dictionary:
	return {
		"health_tier": health_tier,
		"health_progress": health_upgrade_points,
		"health_needed": _get_cost_for_next_tier(health_tier),
		"damage_tier": damage_tier,
		"damage_progress": damage_upgrade_points,
		"damage_needed": _get_cost_for_next_tier(damage_tier),
		"speed_tier": speed_tier,
		"speed_progress": speed_upgrade_points,
		"speed_needed": _get_cost_for_next_tier(speed_tier),
		# Include current actual stats if needed on UI?
		# "current_max_health": current_max_health,
		# "current_damage": current_bullet_damage,
		# "current_speed": current_move_speed,
	}
