# res://scripts/gameplay/game.gd
extends Node2D

# --- SIGNALS ---
# Changed signal to emit only total salvage
signal salvage_updated(total_salvage) 
signal wave_updated(new_wave)

# --- EXPORTS ---
@export var zomborg_scene: PackedScene
@export var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
@export var game_over_sound: AudioStream
@export var upgrade_screen_scene: PackedScene

# --- NODES ---
@onready var enemies_container = $Enemies
@onready var player = $Player
@onready var game_over_sound_player = $GameOverSoundPlayer
@onready var salvage_container = $SalvageItems
var upgrade_screen_instance = null

# --- INTERNAL ---
var spawn_radius: float = 600.0
var game_over_flag: bool = false
var game_over_delay: float = 5.0
# --- NEW: Single Salvage Count ---
var total_salvage: int = 0 
# Removed foot_salvage, claw_salvage, core_salvage

var current_wave: int = 0
var enemies_to_spawn_this_wave: int = 0
var enemies_remaining_this_wave: int = 0
var wave_in_progress: bool = false
var base_enemies_per_wave: int = 5
var extra_enemies_per_wave: int = 2
var upgrade_cost: int = 5


func _ready():
	add_to_group("game_manager")
	add_to_group("salvage_container")
	
	# Reset total salvage on start
	total_salvage = 0
	emit_signal("salvage_updated", total_salvage) # Emit initial value
	
	# --- Null Checks ---
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
	# ... (No changes needed) ...
	if game_over_flag or not zomborg_scene or player == null or enemies_container == null: return

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
	# ... (No changes needed) ...
	if game_over_flag: return

	current_wave += 1
	emit_signal("wave_updated", current_wave)
	print("--- Starting Wave ", current_wave, " ---")

	enemies_to_spawn_this_wave = base_enemies_per_wave + (current_wave - 1) * extra_enemies_per_wave
	enemies_remaining_this_wave = enemies_to_spawn_this_wave

	for i in range(enemies_to_spawn_this_wave): spawn_enemy()

	wave_in_progress = true

	if is_instance_valid(upgrade_screen_instance): upgrade_screen_instance.hide()
	if get_tree().paused: get_tree().paused = false

func _on_enemy_died():
	# ... (No changes needed) ...
	if not wave_in_progress or game_over_flag: return
	enemies_remaining_this_wave -= 1
	if enemies_remaining_this_wave <= 0: wave_cleared()

func wave_cleared():
	# ... (No changes needed) ...
	print("--- Wave ", current_wave, " Cleared! ---")
	wave_in_progress = false
	show_upgrade_screen()

func show_upgrade_screen():
	# ... (Signal connections remain the same) ...
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

	# --- Update Call Changed ---
	# Pass only the total salvage count
	if upgrade_screen_instance.has_method("update_display"):
		upgrade_screen_instance.update_display(total_salvage) 
	else: printerr("Upgrade screen instance missing 'update_display' method!")

	upgrade_screen_instance.show()

	if not get_tree().paused: get_tree().paused = true


# --- Updated Upgrade Logic ---
func _on_upgrade_requested(upgrade_type: String):
	if player == null or not player.has_method("upgrade_" + upgrade_type):
		printerr("Cannot apply upgrade: Player invalid or missing method!")
		print("Upgrade failed (Player Error).")
		return

	# --- Check affordability based on total salvage ---
	if total_salvage >= upgrade_cost:
		# Deduct cost
		total_salvage -= upgrade_cost
		print("Upgrade applied! Spent %d Salvage." % upgrade_cost)
		
		# Apply upgrade
		player.call("upgrade_" + upgrade_type)
		
		# Update UI
		emit_signal("salvage_updated", total_salvage) # Emit new total
		if is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.has_method("update_display"):
			upgrade_screen_instance.update_display(total_salvage) # Update with new total
	else:
		# If not affordable
		print("Not enough total salvage for '%s' upgrade (Need %d, Have %d)." % [upgrade_type, upgrade_cost, total_salvage])
		print("Upgrade failed (Insufficient Salvage).")


func _on_player_died():
	# ... (No changes needed) ...
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
	# ... (No changes needed) ...
	if enemies_container != null:
		for enemy in enemies_container.get_children():
			if is_instance_valid(enemy) and enemy.has_method("set_physics_process"):
				enemy.set_physics_process(false)


func _return_to_main_menu():
	# ... (No changes needed) ...
	if game_over_sound_player and game_over_sound_player.playing: game_over_sound_player.stop()
	if get_tree().paused: get_tree().paused = false
	if main_menu_scene_path.is_empty(): printerr("Main menu scene path not set!"); return
	var error_code = get_tree().change_scene_to_file(main_menu_scene_path)
	if error_code != OK: printerr("Error changing scene to main menu: ", error_code)


# --- Updated Salvage Collection ---
func collect_salvage(type: String):
	# Just increment the total salvage, ignore the specific type collected
	total_salvage += 1 
	print("Total Salvage: ", total_salvage)
	# Emit the updated total
	emit_signal("salvage_updated", total_salvage)
