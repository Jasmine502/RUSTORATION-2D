# res://scripts/ui/hud.gd
extends CanvasLayer

# --- NODES ---
@onready var health_progress_bar: ProgressBar = $HealthProgressBar

# --- EXPORTS ---
# Removed health_textures export

func _ready():
	if health_progress_bar == null:
		printerr("HUD Error: HealthProgressBar node not found!")
		return

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		printerr("HUD Error: Could not find node in group 'player'!")
		if health_progress_bar: health_progress_bar.visible = false
		return

	if player.has_signal("stats_updated"):
		var error_code = player.stats_updated.connect(_on_player_stats_updated)
		if error_code != OK:
			printerr("HUD Error: Failed connect player.stats_updated: ", error_code)
			if health_progress_bar: health_progress_bar.visible = false
	else:
		printerr("HUD Error: Player missing 'stats_updated' signal!")
		if health_progress_bar: health_progress_bar.visible = false

	# --- Initialize Health Bar ---
	if player.has_method("get_current_health") and player.has_method("get_current_max_health"):
		var initial_health = player.get_current_health()
		var initial_max_health = player.get_current_max_health() # Use getter now
		_on_player_stats_updated(initial_health, initial_max_health)
	else:
		printerr("HUD Error: Player missing health getter methods!")
		if health_progress_bar: health_progress_bar.value = 0


# --- Updated Signal Handler Function ---
func _on_player_stats_updated(new_health: int, new_max_health: int):
	if health_progress_bar == null: return

	var max_value = max(1.0, float(new_max_health)) # Ensure max > 0
	health_progress_bar.max_value = max_value

	# --- Refined Value Setting ---
	var current_value = float(new_health)
	# Explicitly set to max if health is full to guarantee 100% look
	if new_health >= new_max_health:
		health_progress_bar.value = max_value
	else:
		health_progress_bar.value = current_value
	
	# Optional: Add text display on or near the bar?
	# health_progress_bar.get_node("Label").text = "%d / %d" % [new_health, new_max_health] 
	# (Requires adding a Label child to the ProgressBar in the scene)

	if not health_progress_bar.visible:
		health_progress_bar.visible = true
