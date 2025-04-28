# res://scripts/gameplay/game.gd
extends Node2D

signal salvage_updated(total_salvage)
signal wave_updated(new_wave)

@export var zomborg_scene: PackedScene
@export var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
@export var game_over_sound: AudioStream
@export var upgrade_screen_scene: PackedScene

@onready var enemies_container = $Enemies
@onready var player = $Player
@onready var game_over_sound_player = $GameOverSoundPlayer
@onready var salvage_container = $SalvageItems
var upgrade_screen_instance = null

var spawn_radius: float = 600.0
var game_over_flag: bool = false
var game_over_delay: float = 5.0
var total_salvage: int = 0
var current_wave: int = 0
var enemies_remaining_this_wave: int = 0
var wave_in_progress: bool = false
# Base/Extra used only for random waves now
var base_enemies_per_wave: int = 8   # Slightly increased base for random waves
var extra_enemies_per_wave: int = 3 # Slightly increased scaling for random waves
var upgrade_cost: int = 5

# --- NEW: Base Stat Definitions ---
var zomborg_base_stats = {
	"speed": {"health": 2, "speed": 200.0, "damage": 8},
	"damage": {"health": 4, "speed": 140.0, "damage": 15},
	"health": {"health": 8, "speed": 120.0, "damage": 10}
}

# Wave definitions remain the same
var wave_definitions = [
	{"speed": 5, "damage": 0, "health": 0}, # W1
	{"speed": 6, "damage": 1, "health": 0}, # W2
	{"speed": 5, "damage": 3, "health": 0}, # W3
	{"speed": 4, "damage": 2, "health": 2}, # W4
	{"speed": 4, "damage": 4, "health": 3}, # W5
	{"speed": 3, "damage": 6, "health": 3}, # W6
	{"speed": 3, "damage": 3, "health": 6}, # W7
	{"speed": 2, "damage": 5, "health": 6}, # W8
	{"speed": 5, "damage": 5, "health": 5}, # W9
	{"speed": 4, "damage": 7, "health": 7}, # W10
]


func _ready():
	# ... (Rest of _ready is unchanged) ...
	add_to_group("game_manager")
	add_to_group("salvage_container")
	total_salvage = 0
	emit_signal("salvage_updated", total_salvage)
	if salvage_container == null: printerr("Game Error: SalvageItems node not found!")
	if enemies_container == null: printerr("ERROR: Enemies container node not found!")
	if game_over_sound_player == null: printerr("WARN: GameOverSoundPlayer node missing!")
	elif game_over_sound == null: printerr("WARN: Game Over Sound not assigned!")
	else: game_over_sound_player.stream = game_over_sound
	if player == null: printerr("ERROR: Player node not found!")
	else:
		if not player.player_died.is_connected(_on_player_died):
			var err = player.player_died.connect(_on_player_died)
			if err != OK: printerr("ERROR connecting player_died signal: ", err)
	call_deferred("start_next_wave")


# --- Updated spawn_enemy call ---
func spawn_enemy(focus_type: String):
	if game_over_flag or not zomborg_scene or player == null or enemies_container == null: return

	# Get base stats for the focus type
	var base_stats = zomborg_base_stats.get(focus_type)
	if base_stats == null:
		printerr("ERROR: Invalid focus_type '%s' passed to spawn_enemy!" % focus_type)
		return # Don't spawn if focus type is wrong

	var random_angle = randf_range(0, TAU)
	var spawn_offset = Vector2.from_angle(random_angle) * spawn_radius
	var spawn_position = player.global_position + spawn_offset

	var zomborg_instance = zomborg_scene.instantiate()

	# Initialize with base stats and focus type
	if zomborg_instance.has_method("initialize"):
		zomborg_instance.initialize(
			base_stats.health,
			base_stats.speed,
			base_stats.damage,
			focus_type
		)
	else:
		printerr("Zomborg instance missing initialize() method!")
		zomborg_instance.queue_free(); return

	if zomborg_instance.has_signal("died"):
		zomborg_instance.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
	else: printerr("Zomborg scene missing the 'died' signal!")

	zomborg_instance.global_position = spawn_position
	enemies_container.add_child(zomborg_instance)


# --- Updated start_next_wave ---
func start_next_wave():
	if game_over_flag: return

	current_wave += 1
	emit_signal("wave_updated", current_wave)
	print("--- Starting Wave ", current_wave, " ---")

	var speed_enemies = 0
	var damage_enemies = 0
	var health_enemies = 0
	var total_enemies = 0

	if current_wave <= wave_definitions.size():
		var definition = wave_definitions[current_wave - 1]
		speed_enemies = definition.get("speed", 0)
		damage_enemies = definition.get("damage", 0)
		health_enemies = definition.get("health", 0)
		total_enemies = speed_enemies + damage_enemies + health_enemies
		print("Wave Def: %d Speed, %d Damage, %d Health" % [speed_enemies, damage_enemies, health_enemies])
	else:
		# Random wave generation (uses base/extra per wave)
		total_enemies = base_enemies_per_wave + (current_wave - (wave_definitions.size() + 1)) * extra_enemies_per_wave # Scale based on waves *after* defined ones
		total_enemies = max(total_enemies, 1) # Ensure at least 1 enemy
		# Distribute total enemies randomly among types
		var remaining_enemies = total_enemies
		speed_enemies = randi_range(0, remaining_enemies)
		remaining_enemies -= speed_enemies
		damage_enemies = randi_range(0, remaining_enemies)
		remaining_enemies -= damage_enemies
		health_enemies = remaining_enemies # Assign the rest to health
		print("Random Wave: %d Speed, %d Damage, %d Health" % [speed_enemies, damage_enemies, health_enemies])


	enemies_remaining_this_wave = total_enemies
	if total_enemies == 0:
		print("WARN: Wave %d has 0 enemies defined. Starting next wave." % current_wave)
		call_deferred("wave_cleared") # Use call_deferred for safety
		return

	# --- Spawn enemies with correct focus type ---
	for _i in range(speed_enemies): spawn_enemy("speed")
	for _i in range(damage_enemies): spawn_enemy("damage")
	for _i in range(health_enemies): spawn_enemy("health")

	wave_in_progress = true

	if is_instance_valid(upgrade_screen_instance): upgrade_screen_instance.hide()
	if get_tree().paused: get_tree().paused = false


# --- Unchanged Functions Below ---

func _on_enemy_died():
	if not wave_in_progress or game_over_flag: return
	enemies_remaining_this_wave -= 1
	if enemies_remaining_this_wave <= 0:
		if enemies_remaining_this_wave < 0:
			printerr("WARN: enemies_remaining_this_wave went below zero!")
			enemies_remaining_this_wave = 0
		wave_cleared()

func wave_cleared():
	print("--- Wave ", current_wave, " Cleared! ---")
	wave_in_progress = false
	show_upgrade_screen()

func show_upgrade_screen():
	if upgrade_screen_scene == null:
		printerr("Upgrade Screen Scene not assigned!")
		get_tree().create_timer(2.0).timeout.connect(start_next_wave)
		return
	if not is_instance_valid(upgrade_screen_instance):
		upgrade_screen_instance = upgrade_screen_scene.instantiate()
		add_child(upgrade_screen_instance)
		var err_code = OK
		if upgrade_screen_instance.has_signal("upgrade_requested"):
			err_code = upgrade_screen_instance.upgrade_requested.connect(_on_upgrade_requested)
			if err_code != OK: printerr("Game Error: Failed connect upgrade_requested: ", err_code)
		else: printerr("Upgrade screen missing 'upgrade_requested' signal!")
		if upgrade_screen_instance.has_signal("next_wave_requested"):
			err_code = upgrade_screen_instance.next_wave_requested.connect(start_next_wave)
			if err_code != OK: printerr("Game Error: Failed connect next_wave_requested: ", err_code)
		else: printerr("Upgrade screen missing 'next_wave_requested' signal!")
	if upgrade_screen_instance.has_method("update_display"):
		upgrade_screen_instance.update_display(total_salvage)
	else: printerr("Upgrade screen instance missing 'update_display' method!")
	upgrade_screen_instance.show()
	if not get_tree().paused: get_tree().paused = true


func _on_upgrade_requested(upgrade_type: String):
	if player == null or not player.has_method("upgrade_" + upgrade_type):
		printerr("Cannot apply upgrade: Player invalid or missing method!")
		print("Upgrade failed (Player Error).")
		return
	if total_salvage >= upgrade_cost:
		total_salvage -= upgrade_cost
		print("Upgrade applied! Spent %d Salvage." % upgrade_cost)
		player.call("upgrade_" + upgrade_type)
		emit_signal("salvage_updated", total_salvage)
		if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.has_method("update_display"):
			upgrade_screen_instance.update_display(total_salvage)
	else:
		print("Not enough total salvage for '%s' upgrade (Need %d, Have %d)." % [upgrade_type, upgrade_cost, total_salvage])
		print("Upgrade failed (Insufficient Salvage).")


func _on_player_died():
	if game_over_flag: return
	game_over_flag = true
	print("Game Over!")
	wave_in_progress = false
	if game_over_sound_player != null and game_over_sound_player.stream != null:
		game_over_sound_player.play()
	call_deferred("_stop_all_enemies")
	if is_instance_valid(upgrade_screen_instance): upgrade_screen_instance.hide()
	if get_tree().paused: get_tree().paused = false
	get_tree().create_timer(game_over_delay).timeout.connect(_return_to_main_menu)


func _stop_all_enemies():
	if enemies_container != null:
		for enemy in enemies_container.get_children():
			if is_instance_valid(enemy) and enemy.has_method("set_physics_process"):
				enemy.set_physics_process(false)


func _return_to_main_menu():
	if game_over_sound_player and game_over_sound_player.playing: game_over_sound_player.stop()
	if get_tree().paused: get_tree().paused = false
	if main_menu_scene_path.is_empty(): printerr("Main menu scene path not set!"); return
	var error_code = get_tree().change_scene_to_file(main_menu_scene_path)
	if error_code != OK: printerr("Error changing scene to main menu: ", error_code)


# Fix Unused Parameter Warning
func collect_salvage(_type: String): # Added underscore
	total_salvage += 1
	#print("Total Salvage: ", total_salvage)
	emit_signal("salvage_updated", total_salvage)
