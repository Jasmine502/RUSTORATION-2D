# res://scripts/gameplay/game.gd
extends Node2D

signal salvage_updated(feet, claws, cores)
signal rust_coin_updated(new_amount)
signal wave_updated(new_wave)

@export var zomborg_scene: PackedScene
@export var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
@export var game_over_sound: AudioStream
@export var upgrade_screen_scene: PackedScene
@export var salvage_to_rustcoin_rate: int = 2

@onready var enemies_container = $Enemies
@onready var player = $Player
@onready var game_over_sound_player = $GameOverSoundPlayer
@onready var salvage_container = $SalvageItems
var upgrade_screen_instance = null

var min_spawn_distance_from_player: float = 300.0
var game_over_flag: bool = false
var game_over_delay: float = 5.0
var foot_salvage: int = 0; var claw_salvage: int = 0; var core_salvage: int = 0
var rust_coin: int = 0; var total_salvage: int = 0

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
	foot_salvage = 0; claw_salvage = 0; core_salvage = 0; rust_coin = 0; _update_total_salvage()
	emit_signal("salvage_updated", foot_salvage, claw_salvage, core_salvage); emit_signal("rust_coin_updated", rust_coin)
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


func _update_total_salvage():
	total_salvage = foot_salvage + claw_salvage + core_salvage


func spawn_enemy(focus_type: String):
	print("DEBUG: spawn_enemy called with focus: ", focus_type) # DEBUG
	if game_over_flag or not zomborg_scene or player == null or not is_instance_valid(player) or enemies_container == null: return
	var base_stats = zomborg_base_stats.get(focus_type); if base_stats == null: printerr("ERROR: Invalid focus_type '%s'!" % focus_type); return
	var spawn_position = Vector2.ZERO; var attempts = 0; var max_attempts = 20
	var min_dist_sq = min_spawn_distance_from_player * min_spawn_distance_from_player
	while attempts < max_attempts:
		attempts += 1; var random_x = randf_range(map_bounds_min_x, map_bounds_max_x); var random_y = randf_range(map_bounds_min_y, map_bounds_max_y)
		var potential_position = Vector2(random_x, random_y)
		if potential_position.distance_squared_to(player.global_position) >= min_dist_sq: spawn_position = potential_position; break
	if spawn_position == Vector2.ZERO:
		var random_x_fallback = randf_range(map_bounds_min_x, map_bounds_max_x); var random_y_fallback = randf_range(map_bounds_min_y, map_bounds_max_y)
		spawn_position = Vector2(random_x_fallback, random_y_fallback)
	var zomborg_instance = zomborg_scene.instantiate()
	if zomborg_instance.has_method("initialize"): zomborg_instance.initialize(base_stats.health, base_stats.speed, base_stats.damage, focus_type)
	else: printerr("Zomborg instance missing initialize()!"); zomborg_instance.queue_free(); return
	if zomborg_instance.has_signal("died"): zomborg_instance.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
	else: printerr("Zomborg scene missing 'died' signal!")
	zomborg_instance.global_position = spawn_position; enemies_container.add_child(zomborg_instance)


func start_next_wave():
	if game_over_flag: return
	current_wave += 1; emit_signal("wave_updated", current_wave); print("--- Starting Wave ", current_wave, " ---")
	var speed_enemies = 0; var damage_enemies = 0; var health_enemies = 0; var total_enemies = 0
	if current_wave <= wave_definitions.size():
		var definition = wave_definitions[current_wave - 1]; speed_enemies = definition.get("speed", 0); damage_enemies = definition.get("damage", 0); health_enemies = definition.get("health", 0); total_enemies = speed_enemies + damage_enemies + health_enemies
	else:
		total_enemies = base_enemies_per_wave + (current_wave - (wave_definitions.size() + 1)) * extra_enemies_per_wave; total_enemies = max(total_enemies, 1); var remaining_enemies = total_enemies
		speed_enemies = randi_range(0, remaining_enemies); remaining_enemies -= speed_enemies; damage_enemies = randi_range(0, remaining_enemies); remaining_enemies -= damage_enemies; health_enemies = remaining_enemies
	enemies_remaining_this_wave = total_enemies; print("Setting enemies_remaining_this_wave to: ", enemies_remaining_this_wave)
	if total_enemies == 0: print("WARN: Wave %d has 0 enemies." % current_wave); call_deferred("wave_cleared"); return
	for _s in range(speed_enemies): spawn_enemy("speed")
	for _d in range(damage_enemies): spawn_enemy("damage")
	for _h in range(health_enemies): spawn_enemy("health")
	wave_in_progress = true
	if is_instance_valid(upgrade_screen_instance): upgrade_screen_instance.hide()
	if get_tree().paused: get_tree().paused = false


func _on_enemy_died():
	if not wave_in_progress or game_over_flag: return
	if enemies_remaining_this_wave > 0:
		enemies_remaining_this_wave -= 1
		print("DEBUG: Enemy died. Remaining: %d (Wave %d)" % [enemies_remaining_this_wave, current_wave])
		if enemies_remaining_this_wave == 0:
			print("DEBUG: Wave %d clear condition met." % current_wave)
			call_deferred("wave_cleared")
	else: printerr("WARN: _on_enemy_died called but enemies_remaining was <= 0!")


func wave_cleared():
	print("--- Wave ", current_wave, " Cleared! ---"); wave_in_progress = false;
	call_deferred("show_upgrade_screen")


func show_upgrade_screen():
	if upgrade_screen_scene == null: printerr("Upgrade Screen Scene not assigned!"); get_tree().create_timer(2.0).timeout.connect(start_next_wave); return
	if not is_instance_valid(upgrade_screen_instance):
		upgrade_screen_instance = upgrade_screen_scene.instantiate(); if not upgrade_screen_instance: printerr("Game Error: Failed to instantiate Upgrade Screen!"); get_tree().create_timer(2.0).timeout.connect(start_next_wave); return
		add_child(upgrade_screen_instance); var expected_script_path = "res://scripts/ui/upgrade_screen.gd"
		if upgrade_screen_instance.get_script() != null and upgrade_screen_instance.get_script().resource_path == expected_script_path:
			var err_code = OK
			if not upgrade_screen_instance.upgrade_requested.is_connected(_on_upgrade_requested): err_code = upgrade_screen_instance.upgrade_requested.connect(_on_upgrade_requested); if err_code != OK: printerr("Failed connect upgrade_req: ", err_code)
			if not upgrade_screen_instance.next_wave_requested.is_connected(start_next_wave): err_code = upgrade_screen_instance.next_wave_requested.connect(start_next_wave); if err_code != OK: printerr("Failed connect next_wave_req: ", err_code)
			if upgrade_screen_instance.has_signal("scrap_requested"):
				if not upgrade_screen_instance.scrap_requested.is_connected(scrap_salvage): err_code = upgrade_screen_instance.scrap_requested.connect(scrap_salvage); if err_code != OK: printerr("Failed connect scrap_req: ", err_code)
			else: printerr("WARN: Upgrade screen instance missing 'scrap_requested' signal!")
		else: printerr("Game Error: Upgrade screen instance missing correct script!"); upgrade_screen_instance.visible = false
	var player_stats_placeholder = {}; if player and player.has_method("get_stats_for_ui"): player_stats_placeholder = player.get_stats_for_ui()
	if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.has_method("update_display"): upgrade_screen_instance.update_display(foot_salvage, claw_salvage, core_salvage, rust_coin, player_stats_placeholder)
	else: printerr("Upgrade screen instance invalid or missing 'update_display' method!"); if not is_instance_valid(upgrade_screen_instance): get_tree().create_timer(2.0).timeout.connect(start_next_wave); return
	if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.visible == false: upgrade_screen_instance.show()
	if not get_tree().paused: get_tree().paused = true


func _on_upgrade_requested(upgrade_type: String):
	if player == null or not is_instance_valid(player) or not player.has_method("add_upgrade_point"): printerr("Upgrade Error: Player invalid/missing method!"); print("Upgrade failed (Player Error)."); return
	var player_stats = player.get_stats_for_ui(); var cost_needed = player_stats.get(upgrade_type + "_needed", 999)
	_update_total_salvage()
	if total_salvage >= cost_needed:
		total_salvage -= cost_needed # Needs refinement if individual counts used elsewhere
		print("Upgrade applied! Spent %d Total Salvage for %s point." % [cost_needed, upgrade_type])
		player.add_upgrade_point(upgrade_type)
		emit_signal("salvage_updated", foot_salvage, claw_salvage, core_salvage); emit_signal("rust_coin_updated", rust_coin)
		if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.has_method("update_display"):
			var updated_player_stats = player.get_stats_for_ui()
			upgrade_screen_instance.update_display(foot_salvage, claw_salvage, core_salvage, rust_coin, updated_player_stats)
	else: print("Not enough total salvage for '%s' upgrade (Need %d, Have %d)." % [upgrade_type, cost_needed, total_salvage]); print("Upgrade failed (Insufficient Salvage).")


func _on_player_died():
	if game_over_flag: return; game_over_flag = true; print("Game Over!"); wave_in_progress = false
	if game_over_sound_player != null and game_over_sound_player.stream != null: game_over_sound_player.play()
	call_deferred("_stop_all_enemies")
	if is_instance_valid(upgrade_screen_instance): upgrade_screen_instance.hide()
	get_tree().create_timer(game_over_delay).timeout.connect(_return_to_main_menu)


func _stop_all_enemies():
	if enemies_container != null:
		for enemy in enemies_container.get_children():
			if is_instance_valid(enemy) and enemy.has_method("set_physics_process"): enemy.set_physics_process(false)


func _return_to_main_menu():
	if game_over_sound_player and game_over_sound_player.playing: game_over_sound_player.stop()
	if get_tree().paused: get_tree().paused = false
	if main_menu_scene_path.is_empty(): printerr("Main menu scene path not set!"); return
	var error_code = get_tree().change_scene_to_file(main_menu_scene_path)
	if error_code != OK: printerr("Error changing scene to main menu: ", error_code)


# --- Corrected collect_salvage ---
func collect_salvage(_type: String):
	# Use proper match structure
	match _type.to_lower():
		"foot":
			foot_salvage += 1
		"claw":
			claw_salvage += 1
		"core":
			core_salvage += 1
		_:
			printerr("Game Error: Collected unknown salvage type: ", _type)
			return # Exit if type is unknown

	_update_total_salvage()
	emit_signal("salvage_updated", foot_salvage, claw_salvage, core_salvage)


# --- Corrected scrap_salvage ---
func scrap_salvage(type: String):
	var scrap_type = type.to_lower()
	var salvaged_amount = 0
	# Use proper match structure
	match scrap_type:
		"foot":
			if foot_salvage > 0:
				foot_salvage -= 1
				salvaged_amount = 1
		"claw":
			if claw_salvage > 0:
				claw_salvage -= 1
				salvaged_amount = 1
		"core":
			if core_salvage > 0:
				core_salvage -= 1
				salvaged_amount = 1
		_: # Default case for unknown type
			printerr("Game Error: Attempted to scrap unknown type: ", type)

	if salvaged_amount > 0:
		var coins_gained = salvaged_amount * salvage_to_rustcoin_rate
		rust_coin += coins_gained
		print("Scrapped 1 %s for %d RustCoin. Total RC: %d" % [scrap_type, coins_gained, rust_coin])
		_update_total_salvage()
		emit_signal("salvage_updated", foot_salvage, claw_salvage, core_salvage); emit_signal("rust_coin_updated", rust_coin)
		if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.visible and upgrade_screen_instance.has_method("update_display"):
			var current_player_stats = {} # Default empty dict
			if player and player.has_method("get_stats_for_ui"): current_player_stats = player.get_stats_for_ui()
			upgrade_screen_instance.update_display(foot_salvage, claw_salvage, core_salvage, rust_coin, current_player_stats)
	else:
		# Only print if the type was known but count was zero
		if scrap_type in ["foot", "claw", "core"]:
			print("Cannot scrap %s: None available." % scrap_type)
