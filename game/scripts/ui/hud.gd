# res://scripts/ui/hud.gd
extends CanvasLayer

# --- NODES ---
# Make sure the node path here matches the HealthProgressBar within your hud.tscn
@onready var health_progress_bar: ProgressBar = $HealthProgressBar

# You might add other HUD elements here later (e.g., Wave Label, RustCoin Label for HUD)
# @onready var wave_label: Label = $WaveLabel
# @onready var hud_rust_coin_label: Label = $RustCoinLabel

func _ready():
	if health_progress_bar == null:
		printerr("HUD Error: HealthProgressBar node not found!")
		# Optionally hide the non-existent bar or return
		return

	# Find the player node using its group
	# Wait for the player to be ready if necessary
	await get_tree().create_timer(0.01).timeout # Short delay to ensure player might be ready
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		printerr("HUD Error: Could not find node in group 'player' after delay!")
		if health_progress_bar: health_progress_bar.visible = false
		return

	# Check if player has the necessary signal and methods BEFORE connecting
	if player.has_signal("stats_updated") and \
	   player.has_method("get_current_health") and \
	   player.has_method("get_current_max_health"):

		# Connect to the player's stats signal
		var error_code = player.stats_updated.connect(_on_player_stats_updated)
		if error_code != Error.OK:
			printerr("HUD Error: Failed connect player.stats_updated: ", error_code)
			if health_progress_bar: health_progress_bar.visible = false
		else:
			# --- Initialize Health Bar ---
			# Get initial values *after* confirming methods exist
			var initial_health = player.get_current_health()
			var initial_max_health = player.get_current_max_health()
			# Call the update function once to set initial state
			_on_player_stats_updated(initial_health, initial_max_health)

	else:
		printerr("HUD Error: Player missing 'stats_updated' signal or health getter methods!")
		if health_progress_bar: health_progress_bar.value = 0; health_progress_bar.visible = false


# --- Signal Handler Function ---
# Called when the player's stats_updated signal is emitted
func _on_player_stats_updated(new_health: int, new_max_health: int):
	if health_progress_bar == null: return # Extra safety check

	# Ensure max_value is at least 1 to avoid division by zero or negative values
	var max_value = max(1.0, float(new_max_health))
	health_progress_bar.max_value = max_value

	# Set the current value, clamping between 0 and max_value
	var current_value = clampf(float(new_health), 0.0, max_value)
	health_progress_bar.value = current_value

	# Ensure the bar is visible if it wasn't
	if not health_progress_bar.visible:
		health_progress_bar.visible = true

# --- Optional: Connect to game signals if you add other HUD elements ---
# func _connect_to_game_signals():
	# var game_manager = get_tree().get_first_node_in_group("game_manager")
	# if game_manager:
		# if wave_label and game_manager.has_signal("wave_updated"):
			# game_manager.wave_updated.connect(_on_wave_updated)
			# # Initialize (You'd need a way to get the initial wave from game_manager)
		# if hud_rust_coin_label and game_manager.has_signal("rust_coin_updated"):
			# game_manager.rust_coin_updated.connect(_on_rust_coin_updated)
			# # Initialize (You'd need a way to get initial coins from game_manager)
	# else:
		# printerr("HUD Error: Could not find game_manager for other signals.")

# func _on_wave_updated(new_wave: int):
	# if wave_label:
		# wave_label.text = "WAVE: %d" % new_wave

# func _on_rust_coin_updated(new_amount: int):
	# if hud_rust_coin_label:
		# hud_rust_coin_label.text = "RC: %d" % new_amount
