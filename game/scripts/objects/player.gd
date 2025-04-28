# res://scripts/objects/Player.gd
extends CharacterBody2D

# --- SIGNALS ---
signal health_updated(new_health)
signal player_died

# --- EXPORTS ---
@export var move_speed: float = 300.0
@export var acceleration: float = 1500.0 # How quickly the player speeds up (pixels/sec^2)
@export var friction: float = 1200.0     # How quickly the player slows down (pixels/sec^2)
@export var shoot_cooldown: float = 0.2
@export var bullet_scene: PackedScene
@export var max_health: int = 100
@export var damage_cooldown_time: float = 0.5
@export var hurt_sound: AudioStream
@export var shoot_sound: AudioStream
@export var normal_texture: Texture2D
@export var shooting_texture: Texture2D
@export var hurt_texture: Texture2D

# --- INTERNAL VARIABLES ---
var can_shoot: bool = true
var current_health: int
var can_take_damage: bool = true

# --- NODES ---
@onready var sprite: Sprite2D = $PlayerSprite
@onready var muzzle = $Muzzle
@onready var shoot_timer = $ShootTimer
@onready var damage_cooldown_timer = $DamageCooldownTimer
@onready var hurt_sound_player = $HurtSoundPlayer
@onready var shoot_sound_player = $ShootSoundPlayer
@onready var shoot_sprite_timer = $ShootSpriteTimer

func _ready():
	current_health = max_health
	emit_signal("health_updated", current_health)

	if sprite and normal_texture:
		sprite.texture = normal_texture
	elif sprite:
		printerr("WARN: Player Normal Texture not assigned in Inspector!")

	# --- Null Checks and Setup ---
	if shoot_timer == null: printerr("ERROR: ShootTimer node not found!")
	else:
		shoot_timer.wait_time = shoot_cooldown
		shoot_timer.timeout.connect(_on_shoot_timer_timeout)

	if damage_cooldown_timer == null: printerr("ERROR: DamageCooldownTimer node not found!")
	else:
		damage_cooldown_timer.wait_time = damage_cooldown_time
		damage_cooldown_timer.one_shot = true
		damage_cooldown_timer.timeout.connect(_on_damage_cooldown_timer_timeout)

	if shoot_sprite_timer == null: printerr("ERROR: ShootSpriteTimer node not found!")
	else:
		shoot_sprite_timer.wait_time = 0.1
		shoot_sprite_timer.one_shot = true
		shoot_sprite_timer.timeout.connect(_on_shoot_sprite_timer_timeout)

	if hurt_sound_player == null: printerr("WARN: HurtSoundPlayer node not found!")
	elif hurt_sound == null: printerr("WARN: Hurt Sound not assigned!")
	else: hurt_sound_player.stream = hurt_sound

	if shoot_sound_player == null: printerr("WARN: ShootSoundPlayer node not found!")
	elif shoot_sound == null: printerr("WARN: Shoot Sound not assigned!")
	else: shoot_sound_player.stream = shoot_sound


func _physics_process(delta):
	if current_health <= 0:
		if is_physics_processing(): set_physics_process(false)
		return

	if sprite == null or muzzle == null:
		printerr("ERROR: Player nodes missing in _physics_process!")
		if is_physics_processing(): set_physics_process(false)
		return

	# --- Aiming ---
	look_at(get_global_mouse_position())

	# --- Smooth Movement ---
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity = input_direction * move_speed
	# Removed unused 'current_acceleration' variable here
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	# --- Shooting ---
	if shoot_timer != null and Input.is_action_pressed("shoot") and can_shoot:
		if shoot_sound_player != null and shoot_sound_player.stream != null:
			shoot_sound_player.pitch_scale = randf_range(0.9, 1.1)
			shoot_sound_player.play()

		if sprite and shooting_texture:
			sprite.texture = shooting_texture
			if shoot_sprite_timer: shoot_sprite_timer.start()
		elif sprite: printerr("WARN: Player Shooting Texture not assigned!")

		_shoot()
		can_shoot = false
		shoot_timer.start()

func _shoot():
	if muzzle == null: printerr("ERROR: Muzzle node null in _shoot!"); return
	if not bullet_scene: printerr("Bullet scene not set!"); return

	var bullet_instance = bullet_scene.instantiate()
	if bullet_instance.has_method("start"):
		bullet_instance.start(muzzle.global_position, transform.x)
	else:
		printerr("Bullet instance missing start() method.")
		bullet_instance.global_position = muzzle.global_position

	if get_parent() == null: printerr("ERROR: Player has no parent!"); return
	get_parent().call_deferred("add_child", bullet_instance)


func _on_shoot_timer_timeout():
	can_shoot = true

func _on_shoot_sprite_timer_timeout():
	if sprite and normal_texture and can_take_damage:
		sprite.texture = normal_texture
	elif sprite and not normal_texture: printerr("WARN: Player Normal Texture not assigned!")

func take_damage(amount: int):
	if not can_take_damage: return

	current_health -= amount
	current_health = max(current_health, 0)
	emit_signal("health_updated", current_health)

	can_take_damage = false
	if damage_cooldown_timer != null: damage_cooldown_timer.start()
	else: printerr("Damage cooldown timer missing!")

	if sprite and hurt_texture: sprite.texture = hurt_texture
	elif sprite: printerr("WARN: Player Hurt Texture not assigned!")

	if hurt_sound_player != null and hurt_sound_player.stream != null:
		hurt_sound_player.pitch_scale = randf_range(0.95, 1.05)
		hurt_sound_player.play()

	if current_health <= 0: die()

func _on_damage_cooldown_timer_timeout():
	can_take_damage = true
	if sprite and normal_texture: sprite.texture = normal_texture

func die():
	print("Player Died!")
	emit_signal("player_died")

	if is_physics_processing(): set_physics_process(false)
	if is_processing(): set_process(false)

	if sprite != null: sprite.modulate = Color(0.5, 0.5, 0.5, 0.8)

	var collision_shape = $CollisionShape2D
	if collision_shape:
		# Use set_deferred for physics properties changed outside _physics_process
		collision_shape.set_deferred("disabled", true)

func get_current_health() -> int:
	return current_health
