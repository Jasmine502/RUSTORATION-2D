# res://scripts/ui/upgrade_screen.gd
extends CanvasLayer

# --- SIGNALS ---
signal upgrade_requested(upgrade_type)
signal next_wave_requested

# --- NODES ---
@onready var total_salvage_label: Label = $UpgradePanel/MainLayout/TotalSalvageLabel 
@onready var speed_button: Button = $UpgradePanel/MainLayout/ButtonLayout/SpeedButton
@onready var damage_button: Button = $UpgradePanel/MainLayout/ButtonLayout/DamageButton
@onready var health_button: Button = $UpgradePanel/MainLayout/ButtonLayout/HealthButton
@onready var next_wave_button: Button = $UpgradePanel/MainLayout/NextWaveButton

# --- INTERNAL ---
var upgrade_cost = 5

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# --- Null Checks & Connections ---
	var error_code = OK
	# Check the NEW label
	if not total_salvage_label: printerr("UpgradeScreen Error: TotalSalvageLabel missing!")

	if speed_button != null:
		if not speed_button.pressed.is_connected(_on_speed_button_pressed):
			error_code = speed_button.pressed.connect(_on_speed_button_pressed)
			if error_code != OK: printerr("Failed connect SpeedButton signal: ", error_code)
	else: printerr("UpgradeScreen Error: SpeedButton node is NULL!")
	if damage_button != null:
		if not damage_button.pressed.is_connected(_on_damage_button_pressed):
			error_code = damage_button.pressed.connect(_on_damage_button_pressed)
			if error_code != OK: printerr("Failed connect DamageButton signal: ", error_code)
	else: printerr("UpgradeScreen Error: DamageButton node is NULL!")
	if health_button != null:
		if not health_button.pressed.is_connected(_on_health_button_pressed):
			error_code = health_button.pressed.connect(_on_health_button_pressed)
			if error_code != OK: printerr("Failed connect HealthButton signal: ", error_code)
	else: printerr("UpgradeScreen Error: HealthButton node is NULL!")
	if next_wave_button != null:
		if not next_wave_button.pressed.is_connected(_on_next_wave_button_pressed):
			error_code = next_wave_button.pressed.connect(_on_next_wave_button_pressed)
			if error_code != OK: printerr("Failed connect NextWaveButton signal: ", error_code)
	else: printerr("UpgradeScreen Error: NextWaveButton node is NULL!")

	# --- Update button text ---
	var cost_text = "(Cost: %d)" % upgrade_cost
	if speed_button: speed_button.text = "Upgrade Speed %s" % cost_text
	if damage_button: damage_button.text = "Upgrade Damage %s" % cost_text
	if health_button: health_button.text = "Upgrade Health %s" % cost_text


# --- Updated update_display function ---
# Now accepts only the total salvage count
func update_display(total_salvage: int):
	if total_salvage_label: 
		total_salvage_label.text = "x%d" % total_salvage
	else: 
		printerr("Cannot update display: total_salvage_label is null")

	# --- Button Disabling Logic (Based on total salvage) ---
	var can_afford_upgrade = (total_salvage >= upgrade_cost)

	if speed_button: speed_button.disabled = not can_afford_upgrade
	if damage_button: damage_button.disabled = not can_afford_upgrade
	if health_button: health_button.disabled = not can_afford_upgrade


# --- Button Press Handlers (No change needed here) ---
func _on_speed_button_pressed():
	emit_signal("upgrade_requested", "speed")

func _on_damage_button_pressed():
	emit_signal("upgrade_requested", "damage")

func _on_health_button_pressed():
	emit_signal("upgrade_requested", "health")

func _on_next_wave_button_pressed():
	emit_signal("next_wave_requested")


func _notification(what):
	# Using the integer value 22 for NOTIFICATION_VISIBILITY_CHANGED
	if what == 22:
		if not visible and get_tree().paused:
			get_tree().paused = false
