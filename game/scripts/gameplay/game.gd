# res://scripts/gameplay/game.gd
extends Node2D

# --- EXPORTS ---
@export var zomborg_scene: PackedScene
@export var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
@export var game_over_sound: AudioStream

# --- NODES ---
@onready var spawn_timer = $SpawnTimer
@onready var enemies_container = $Enemies
@onready var player = $Player
@onready var game_over_sound_player = $GameOverSoundPlayer
# Add reference to the salvage container node
@onready var salvage_container = $SalvageItems 

# --- INTERNAL ---
var spawn_radius: float = 600.0
var game_over_flag: bool = false
var game_over_delay: float = 10.0

# --- NEW: Salvage Counts ---
var foot_salvage: int = 0
var claw_salvage: int = 0
var core_salvage: int = 0

func _ready():
	# Add self to the group so salvage items can find it
	add_to_group("game_manager")
	
	# Null check for the new salvage container
	if salvage_container == null:
		printerr("Game Error: SalvageItems node not found!")

	# --- Existing Null checks and Setup ---
	if spawn_timer == null: printerr("ERROR: SpawnTimer node not found!")
	else:
		if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
			spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		if spawn_timer.is_stopped(): spawn_timer.start()

	if enemies_container == null: printerr("ERROR: Enemies container node not found!")
	if game_over_sound_player == null: printerr("WARN: GameOverSoundPlayer node not found!")
	elif game_over_sound == null: printerr("WARN: Game Over Sound not assigned!")
	else: game_over_sound_player.stream = game_over_sound

	if player == null: printerr("ERROR: Player node not found!")
	else:
		if not player.player_died.is_connected(_on_player_died):
			var error_code = player.player_died.connect(_on_player_died)
			if error_code != OK: printerr("ERROR connecting player_died signal: ", error_code)

func _on_spawn_timer_timeout():
	if game_over_flag or not zomborg_scene or player == null or enemies_container == null: return

	var random_angle = randf_range(0, TAU)
	var spawn_offset = Vector2.from_angle(random_angle) * spawn_radius
	var spawn_position = player.global_position + spawn_offset

	var zomborg_instance = zomborg_scene.instantiate()
	zomborg_instance.global_position = spawn_position
	enemies_container.add_child(zomborg_instance)

func _on_player_died():
	if game_over_flag: return
	game_over_flag = true
	print("Game Over!")
	if spawn_timer != null: spawn_timer.stop()
	if game_over_sound_player != null and game_over_sound_player.stream != null:
		game_over_sound_player.play()
	if enemies_container != null:
		for enemy in enemies_container.get_children():
			if enemy.has_method("set_physics_process"): enemy.set_physics_process(false)
	get_tree().create_timer(game_over_delay).timeout.connect(_return_to_main_menu)

func _return_to_main_menu():
	if game_over_sound_player and game_over_sound_player.playing: game_over_sound_player.stop()
	if main_menu_scene_path.is_empty(): printerr("Main menu scene path not set!"); return
	var error_code = get_tree().change_scene_to_file(main_menu_scene_path)
	if error_code != OK: printerr("Error changing scene to main menu: ", error_code)


# --- NEW: Function called by Salvage items ---
func collect_salvage(type: String):
	match type.to_lower():
		"foot":
			foot_salvage += 1
			print("Feet Salvage: ", foot_salvage)
		"claw":
			claw_salvage += 1
			print("Claw Salvage: ", claw_salvage)
		"core":
			core_salvage += 1
			print("Core Salvage: ", core_salvage)
		_:
			printerr("Game Error: Attempted to collect unknown salvage type: ", type)
	
	# TODO: Update HUD with new salvage counts
