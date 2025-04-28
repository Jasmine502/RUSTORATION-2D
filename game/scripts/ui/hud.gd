# res://scripts/ui/hud.gd
extends CanvasLayer

# --- NODES ---
@onready var health_bar_display: TextureRect = $HealthBarDisplay

# --- EXPORTS ---
# In Inspector: Set Size to 11. Drag HP0.png to [0], HP10.png to [1], ..., HP100.png to [10]
@export var health_textures: Array[Texture2D]

func _ready():
	# --- Null Checks ---
	if health_bar_display == null:
		printerr("HUD Error: HealthBarDisplay node not found!")
		return # Cannot proceed without the display node

	if health_textures == null or health_textures.size() != 11:
		printerr("HUD Error: Health Textures array not assigned correctly in Inspector! Expected 11 textures.")
		health_bar_display.visible = false # Hide bar if textures aren't set up
		return

	# --- Find Player ---
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		printerr("HUD Error: Could not find node in group 'player'!")
		health_bar_display.visible = false
		return

	# --- Connect Signal ---
	if player.has_signal("health_updated"):
		var error_code = player.health_updated.connect(_on_player_health_updated)
		if error_code != OK:
			printerr("HUD Error: Failed to connect to player.health_updated signal: ", error_code)
			health_bar_display.visible = false
	else:
		printerr("HUD Error: Player node does not have the 'health_updated' signal!")
		health_bar_display.visible = false

	# --- Initialize Health Bar ---
	# Get initial health using the getter method
	if player.has_method("get_current_health"):
		# Call update function immediately with initial health
		_on_player_health_updated(player.get_current_health())
	else:
		printerr("HUD Error: Player missing get_current_health() method! Cannot set initial health bar.")
		# Set to full health sprite as a fallback?
		if health_textures.size() == 11 and health_textures[10] != null:
			health_bar_display.texture = health_textures[10]
		else:
			health_bar_display.visible = false


# Called when the player's 'health_updated' signal is emitted
func _on_player_health_updated(new_health: int):
	# --- Safety Checks ---
	if health_bar_display == null: return
	if health_textures == null or health_textures.size() != 11:
		# Ensure visibility is false if textures become invalid later
		if health_bar_display.visible: health_bar_display.visible = false
		printerr("HUD Error: Health Textures array invalid in _on_player_health_updated.")
		return

	# Ensure bar is visible if textures are valid
	if not health_bar_display.visible: health_bar_display.visible = true

	# --- Calculate Texture Index ---
	# Clamp health between 0 and 100 for safety
	var clamped_health = clamp(new_health, 0, 100)
	
	# Calculate the index corresponding to the health range (0-10)
	# Index 0: 0 health (HP0.png)
	# Index 1: 1-10 health (HP10.png)
	# Index 2: 11-20 health (HP20.png)
	# ...
	# Index 10: 91-100 health (HP100.png)
	var texture_index = 0 # Default to index 0 for 0 health
	if clamped_health > 0:
		texture_index = int(ceil(float(clamped_health) / 10.0))
		
	# Ensure index is within the array bounds [0, 10]
	texture_index = clamp(texture_index, 0, 10) # Max index is 10 for 11 elements

	# --- Set Texture ---
	# Check if the texture at the calculated index actually exists
	if health_textures[texture_index] != null:
		health_bar_display.texture = health_textures[texture_index]
	else:
		printerr("HUD Error: Missing health texture at index: ", texture_index)
		# Optionally hide the bar or show a default "error" texture
		health_bar_display.visible = false
