# res://scripts/gameplay/game.gd
extends Node2D

# ... (signals, exports, nodes, internal vars, salvage counts, wave vars) ...
signal salvage_updated(feet, claws, cores)
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
var foot_salvage: int = 0
var claw_salvage: int = 0
var core_salvage: int = 0
var current_wave: int = 0
var enemies_to_spawn_this_wave: int = 0
var enemies_remaining_this_wave: int = 0
var wave_in_progress: bool = false
var base_enemies_per_wave: int = 5
var extra_enemies_per_wave: int = 2


func _ready():
	# ... (Keep existing _ready code) ...
	add_to_group("game_manager") 
	add_to_group("salvage_container") 
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


func spawn_enemy():
	# ... (Keep existing spawn_enemy code) ...
	if game_over_flag or not zomborg_scene or player == null or enemies_container == null:
		printerr("Spawn conditions not met, aborting spawn.")
		return

	var random_angle = randf_range(0, TAU)
	var spawn_offset = Vector2.from_angle(random_angle) * spawn_radius
	var spawn_position = player.global_position + spawn_offset
	var zomborg_instance = zomborg_scene.instantiate()

	if zomborg_instance.has_signal("died"): 
		zomborg_instance.died.connect(_on_enemy_died, CONNECT_ONE_SHOT) 
	else: printerr("Zomborg scene missing 'died' signal!")
	
	zomborg_instance.global_position = spawn_position
	enemies_container.add_child(zomborg_instance)


func start_next_wave():
	# ... (Keep existing start_next_wave logic, including pausing/unpausing) ...
	if game_over_flag: return 

	current_wave += 1
	emit_signal("wave_updated", current_wave)
	print("--- Starting Wave ", current_wave, " ---")

	enemies_to_spawn_this_wave = base_enemies_per_wave + (current_wave - 1) * extra_enemies_per_wave
	enemies_remaining_this_wave = enemies_to_spawn_this_wave
	print("Enemies in wave: ", enemies_remaining_this_wave)

	for i in range(enemies_to_spawn_this_wave):
		spawn_enemy()

	wave_in_progress = true

	if is_instance_valid(upgrade_screen_instance):
		upgrade_screen_instance.hide()
		
	# Unpause the game when starting the wave
	if get_tree().paused:
		print("Game: Starting wave, unpausing tree.")
		get_tree().paused = false 


func _on_enemy_died():
	# ... (Keep existing _on_enemy_died logic) ...
	if not wave_in_progress or game_over_flag: return 

	enemies_remaining_this_wave -= 1
	#print("Enemy died. Remaining in wave: ", enemies_remaining_this_wave) # Reduce spam

	if enemies_remaining_this_wave <= 0:
		wave_cleared()


func wave_cleared():
	# ... (Keep existing wave_cleared logic) ...
	print("--- Wave ", current_wave, " Cleared! ---")
	wave_in_progress = false
	show_upgrade_screen()


func show_upgrade_screen():
	if upgrade_screen_scene == null:
		printerr("Upgrade Screen Scene not assigned in Game Inspector!")
		get_tree().create_timer(2.0).timeout.connect(start_next_wave)
		return

	# Instantiate only if not already valid
	if not is_instance_valid(upgrade_screen_instance):
		print("Game: Instantiating Upgrade Screen") # DEBUG
		upgrade_screen_instance = upgrade_screen_scene.instantiate()
		add_child(upgrade_screen_instance) # Add to Game node

		# --- Connect signals FROM upgrade screen TO this script ---
		var err_code = OK
		if upgrade_screen_instance.has_signal("upgrade_requested"):
			err_code = upgrade_screen_instance.upgrade_requested.connect(_on_upgrade_requested)
			if err_code != OK: printerr("Game Error: Failed connect upgrade_requested: ", err_code)
			else: print("Game: Connected upgrade_requested signal.") # DEBUG
		else: printerr("Upgrade screen missing 'upgrade_requested' signal!")

		if upgrade_screen_instance.has_signal("next_wave_requested"):
			err_code = upgrade_screen_instance.next_wave_requested.connect(start_next_wave)
			if err_code != OK: printerr("Game Error: Failed connect next_wave_requested: ", err_code)
			else: print("Game: Connected next_wave_requested signal.") # DEBUG
		else: printerr("Upgrade screen missing 'next_wave_requested' signal!")
	else:
		print("Game: Re-using existing Upgrade Screen instance.") # DEBUG


	# Update display and show
	if upgrade_screen_instance.has_method("update_display"):
		upgrade_screen_instance.update_display(foot_salvage, claw_salvage, core_salvage)
	else: printerr("Upgrade screen instance missing 'update_display' method!")

	upgrade_screen_instance.show()
	
	# Pause the game tree
	if not get_tree().paused:
		print("Game: Showing upgrade screen, pausing tree.")
		get_tree().paused = true


func _on_upgrade_requested(upgrade_type: String):
	print("Game: Received upgrade_requested signal for: ", upgrade_type) # DEBUG
	var cost = 5
	var success = false

	match upgrade_type:
		"speed":
			if foot_salvage >= cost:
				foot_salvage -= cost
				if player and player.has_method("upgrade_speed"): player.upgrade_speed(); success = true
				else: printerr("Cannot apply speed upgrade!")
			else: print("Not enough foot salvage.")
		"damage":
			if claw_salvage >= cost:
				claw_salvage -= cost
				if player and player.has_method("upgrade_damage"): player.upgrade_damage(); success = true
				else: printerr("Cannot apply damage upgrade!")
			else: print("Not enough claw salvage.")
		"health":
			if core_salvage >= cost:
				core_salvage -= cost
				if player and player.has_method("upgrade_health"): player.upgrade_health(); success = true
				else: printerr("Cannot apply health upgrade!")
			else: print("Not enough core salvage.")
		_: printerr("Unknown upgrade type requested: ", upgrade_type)

	if success:
		print("Upgrade applied!")
		emit_signal("salvage_updated", foot_salvage, claw_salvage, core_salvage)
		if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.has_method("update_display"):
			upgrade_screen_instance.update_display(foot_salvage, claw_salvage, core_salvage)
	else:
		print("Upgrade failed.")


func _on_player_died():
	# ... (Keep existing _on_player_died logic) ...
	if game_over_flag: return
	game_over_flag = true
	print("Game Over!")
	wave_in_progress = false 
	if game_over_sound_player != null and game_over_sound_player.stream != null:
		game_over_sound_player.play()
	call_deferred("_stop_all_enemies")
	if is_instance_valid(upgrade_screen_instance):
		upgrade_screen_instance.hide()
	if get_tree().paused: get_tree().paused = false 
	get_tree().create_timer(game_over_delay).timeout.connect(_return_to_main_menu)


func _stop_all_enemies():
	# ... (Keep existing _stop_all_enemies) ...
	if enemies_container != null:
		for enemy in enemies_container.get_children():
			if is_instance_valid(enemy) and enemy.has_method("set_physics_process"):
				enemy.set_physics_process(false)


func _return_to_main_menu():
	# ... (Keep existing _return_to_main_menu) ...
	if game_over_sound_player and game_over_sound_player.playing: game_over_sound_player.stop()
	if get_tree().paused: get_tree().paused = false 
	if main_menu_scene_path.is_empty(): printerr("Main menu scene path not set!"); return
	var error_code = get_tree().change_scene_to_file(main_menu_scene_path)
	if error_code != OK: printerr("Error changing scene to main menu: ", error_code)


func collect_salvage(type: String):
	# ... (Keep existing collect_salvage) ...
	match type.to_lower():
		"foot": foot_salvage += 1
		"claw": claw_salvage += 1
		"core": core_salvage += 1
		_: printerr("Game Error: Collected unknown salvage type: ", type); return
	print("Salvage Counts: Feet=", foot_salvage, " Claws=", claw_salvage, " Cores=", core_salvage)
	emit_signal("salvage_updated", foot_salvage, claw_salvage, core_salvage)
