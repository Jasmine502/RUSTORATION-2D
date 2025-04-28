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

var min_spawn_distance_from_player: float = 300.0
var game_over_flag: bool = false
var game_over_delay: float = 5.0
var total_salvage: int = 0
var current_wave: int = 0
var enemies_remaining_this_wave: int = 0
var wave_in_progress: bool = false
var base_enemies_per_wave: int = 8
var extra_enemies_per_wave: int = 3
var upgrade_cost: int = 5

var map_bounds_min_x: float = -1150.0; var map_bounds_max_x: float = 1150.0
var map_bounds_min_y: float = -750.0; var map_bounds_max_y: float = 750.0
var map_play_area: Rect2

var zomborg_base_stats = {
	"speed": {"health": 2, "speed": 200.0, "damage": 8},
	"damage": {"health": 4, "speed": 140.0, "damage": 15},
	"health": {"health": 8, "speed": 120.0, "damage": 10}
}
var wave_definitions = [
	{"speed": 5, "damage": 0, "health": 0}, {"speed": 6, "damage": 1, "health": 0},
	{"speed": 5, "damage": 3, "health": 0}, {"speed": 4, "damage": 2, "health": 2},
	{"speed": 4, "damage": 4, "health": 3}, {"speed": 3, "damage": 6, "health": 3},
	{"speed": 3, "damage": 3, "health": 6}, {"speed": 2, "damage": 5, "health": 6},
	{"speed": 5, "damage": 5, "health": 5}, {"speed": 4, "damage": 7, "health": 7},
]


func _ready():
	map_play_area = Rect2(map_bounds_min_x, map_bounds_min_y, map_bounds_max_x - map_bounds_min_x, map_bounds_max_y - map_bounds_min_y)
	add_to_group("game_manager"); add_to_group("salvage_container")
	total_salvage = 0; emit_signal("salvage_updated", total_salvage)
	# Null checks... (Keep as before)
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


func spawn_enemy(focus_type: String):
	# ... (Keep spawn_enemy as before) ...
	if game_over_flag or not zomborg_scene or player == null or not is_instance_valid(player) or enemies_container == null: return
	var base_stats = zomborg_base_stats.get(focus_type)
	if base_stats == null: printerr("ERROR: Invalid focus_type '%s'!" % focus_type); return
	var spawn_position = Vector2.ZERO; var attempts = 0; var max_attempts = 20
	var min_dist_sq = min_spawn_distance_from_player * min_spawn_distance_from_player
	while attempts < max_attempts:
		attempts += 1; var random_x = randf_range(map_bounds_min_x, map_bounds_max_x); var random_y = randf_range(map_bounds_min_y, map_bounds_max_y)
		var potential_position = Vector2(random_x, random_y)
		if potential_position.distance_squared_to(player.global_position) >= min_dist_sq: spawn_position = potential_position; break
	if spawn_position == Vector2.ZERO:
		printerr("WARN: Could not find suitable spawn pos after %d attempts." % max_attempts)
		var random_x_fallback = randf_range(map_bounds_min_x, map_bounds_max_x); var random_y_fallback = randf_range(map_bounds_min_y, map_bounds_max_y)
		spawn_position = Vector2(random_x_fallback, random_y_fallback)
	var zomborg_instance = zomborg_scene.instantiate()
	if zomborg_instance.has_method("initialize"): zomborg_instance.initialize(base_stats.health, base_stats.speed, base_stats.damage, focus_type)
	else: printerr("Zomborg instance missing initialize()!"); zomborg_instance.queue_free(); return
	if zomborg_instance.has_signal("died"): zomborg_instance.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
	else: printerr("Zomborg scene missing 'died' signal!")
	zomborg_instance.global_position = spawn_position; enemies_container.add_child(zomborg_instance)


func start_next_wave():
	# ... (Keep start_next_wave as before) ...
	if game_over_flag: return
	current_wave += 1; emit_signal("wave_updated", current_wave); print("--- Starting Wave ", current_wave, " ---")
	var speed_enemies = 0; var damage_enemies = 0; var health_enemies = 0; var total_enemies = 0
	if current_wave <= wave_definitions.size():
		var definition = wave_definitions[current_wave - 1]
		speed_enemies = definition.get("speed", 0); damage_enemies = definition.get("damage", 0); health_enemies = definition.get("health", 0); total_enemies = speed_enemies + damage_enemies + health_enemies
	else:
		total_enemies = base_enemies_per_wave + (current_wave - (wave_definitions.size() + 1)) * extra_enemies_per_wave; total_enemies = max(total_enemies, 1); var remaining_enemies = total_enemies
		speed_enemies = randi_range(0, remaining_enemies); remaining_enemies -= speed_enemies; damage_enemies = randi_range(0, remaining_enemies); remaining_enemies -= damage_enemies; health_enemies = remaining_enemies
	enemies_remaining_this_wave = total_enemies
	if total_enemies == 0: print("WARN: Wave %d has 0 enemies." % current_wave); call_deferred("wave_cleared"); return
	for _i in range(speed_enemies): spawn_enemy("speed")
	for _i in range(damage_enemies): spawn_enemy("damage")
	for _i in range(health_enemies): spawn_enemy("health")
	wave_in_progress = true
	if is_instance_valid(upgrade_screen_instance): upgrade_screen_instance.hide()
	if get_tree().paused: get_tree().paused = false


func _on_enemy_died():
	# ... (Keep _on_enemy_died as before) ...
	if not wave_in_progress or game_over_flag: return
	enemies_remaining_this_wave -= 1
	if enemies_remaining_this_wave <= 0:
		if enemies_remaining_this_wave < 0: printerr("WARN: enemies_remaining < 0!"); enemies_remaining_this_wave = 0
		wave_cleared()

func wave_cleared():
	# ... (Keep wave_cleared as before) ...
	print("--- Wave ", current_wave, " Cleared! ---"); wave_in_progress = false; show_upgrade_screen()

# --- Modified show_upgrade_screen ---
func show_upgrade_screen():
	if upgrade_screen_scene == null:
		printerr("Upgrade Screen Scene not assigned!"); get_tree().create_timer(2.0).timeout.connect(start_next_wave); return

	# Instantiate only if not already valid
	if not is_instance_valid(upgrade_screen_instance):
		#print("Game: Instantiating Upgrade Screen") # Less spam
		upgrade_screen_instance = upgrade_screen_scene.instantiate()
		if not upgrade_screen_instance: # Check if instantiation failed
			printerr("Game Error: Failed to instantiate Upgrade Screen Scene!")
			get_tree().create_timer(2.0).timeout.connect(start_next_wave) # Fallback
			return
			
		add_child(upgrade_screen_instance)

		# --- Connect signals AFTER ensuring instance is valid AND has script ---
		# Check if the correct script is attached (more robust than just has_signal)
		var expected_script_path = "res://scripts/ui/upgrade_screen.gd" # Adjust if your path differs
		if upgrade_screen_instance.get_script() == null or upgrade_screen_instance.get_script().resource_path != expected_script_path:
			printerr("Game Error: Upgrade screen instance does not have the correct script attached! Expected: ", expected_script_path)
		else:
			# Now attempt connections, checking return codes
			var err_code = OK
			if not upgrade_screen_instance.upgrade_requested.is_connected(_on_upgrade_requested):
				err_code = upgrade_screen_instance.upgrade_requested.connect(_on_upgrade_requested)
				if err_code != OK: printerr("Game Error: Failed connect upgrade_requested: ", err_code)
				#else: print("Game: Connected upgrade_requested signal.") # Less spam

			if not upgrade_screen_instance.next_wave_requested.is_connected(start_next_wave):
				err_code = upgrade_screen_instance.next_wave_requested.connect(start_next_wave)
				if err_code != OK: printerr("Game Error: Failed connect next_wave_requested: ", err_code)
				#else: print("Game: Connected next_wave_requested signal.") # Less spam
	#else: print("Game: Re-using existing Upgrade Screen instance.") # Less spam

	# Update display and show (Check instance validity again)
	if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.has_method("update_display"):
		upgrade_screen_instance.update_display(total_salvage)
	else:
		printerr("Upgrade screen instance invalid or missing 'update_display' method!")
		# Don't show or pause if screen is broken
		if not is_instance_valid(upgrade_screen_instance):
			get_tree().create_timer(2.0).timeout.connect(start_next_wave) # Fallback
			return

	if is_instance_valid(upgrade_screen_instance): upgrade_screen_instance.show()
	if not get_tree().paused: get_tree().paused = true


func _on_upgrade_requested(upgrade_type: String):
	# ... (Keep _on_upgrade_requested as before) ...
	if player == null or not player.has_method("upgrade_" + upgrade_type): printerr("Cannot apply upgrade: Player invalid/missing method!"); print("Upgrade failed (Player Error)."); return
	if total_salvage >= upgrade_cost:
		total_salvage -= upgrade_cost; print("Upgrade applied! Spent %d Salvage." % upgrade_cost)
		player.call("upgrade_" + upgrade_type); emit_signal("salvage_updated", total_salvage)
		if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.has_method("update_display"): upgrade_screen_instance.update_display(total_salvage)
	else: print("Not enough total salvage for '%s' upgrade (Need %d, Have %d)." % [upgrade_type, upgrade_cost, total_salvage]); print("Upgrade failed (Insufficient Salvage).")


# --- Modified _on_player_died ---
func _on_player_died():
	if game_over_flag: return
	game_over_flag = true
	print("Game Over!")
	wave_in_progress = false
	if game_over_sound_player != null and game_over_sound_player.stream != null:
		game_over_sound_player.play()
	call_deferred("_stop_all_enemies")
	if is_instance_valid(upgrade_screen_instance): upgrade_screen_instance.hide()
	# Unpausing is handled by _return_to_main_menu or hiding the upgrade screen notification
	# if get_tree().paused: get_tree().paused = false # Remove this line
	get_tree().create_timer(game_over_delay).timeout.connect(_return_to_main_menu)


func _stop_all_enemies():
	# ... (Keep _stop_all_enemies as before) ...
	if enemies_container != null:
		for enemy in enemies_container.get_children():
			if is_instance_valid(enemy) and enemy.has_method("set_physics_process"): enemy.set_physics_process(false)


# --- Modified _return_to_main_menu ---
func _return_to_main_menu():
	if game_over_sound_player and game_over_sound_player.playing: game_over_sound_player.stop()
	# Ensure tree is unpaused BEFORE changing scenes
	if get_tree().paused: 
		print("Returning to menu, unpausing tree.")
		get_tree().paused = false 
	if main_menu_scene_path.is_empty(): printerr("Main menu scene path not set!"); return
	var error_code = get_tree().change_scene_to_file(main_menu_scene_path)
	if error_code != OK: printerr("Error changing scene to main menu: ", error_code)


func collect_salvage(_type: String):
	# ... (Keep collect_salvage as before) ...
	total_salvage += 1
	emit_signal("salvage_updated", total_salvage)
