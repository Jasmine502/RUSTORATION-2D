# res://scripts/ui/upgrade_screen.gd
extends CanvasLayer

# --- SIGNALS ---
signal upgrade_requested(upgrade_type)
signal next_wave_requested

# --- NODES ---
@onready var foot_count_label: Label = $UpgradePanel/MainLayout/SalvageDisplay/FootCountLabel
@onready var claw_count_label: Label = $UpgradePanel/MainLayout/SalvageDisplay/ClawCountLabel
@onready var core_count_label: Label = $UpgradePanel/MainLayout/SalvageDisplay/CoreCountLabel
@onready var speed_button: Button = $UpgradePanel/MainLayout/ButtonLayout/SpeedButton
@onready var damage_button: Button = $UpgradePanel/MainLayout/ButtonLayout/DamageButton
@onready var health_button: Button = $UpgradePanel/MainLayout/ButtonLayout/HealthButton
@onready var next_wave_button: Button = $UpgradePanel/MainLayout/NextWaveButton

# --- INTERNAL ---
var speed_cost = 5
var damage_cost = 5
var health_cost = 5

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("UpgradeScreen Ready. Process Mode set to Always.")

	# --- Explicit Null Checks Before Connecting ---
	var error_code = OK

	if speed_button != null:
		print("SpeedButton Found.")
		if not speed_button.pressed.is_connected(_on_speed_button_pressed):
			error_code = speed_button.pressed.connect(_on_speed_button_pressed)
			if error_code != OK: printerr("Failed connect SpeedButton signal: ", error_code)
			else: print("SpeedButton connected.")
	else:
		printerr("UpgradeScreen Error: SpeedButton node is NULL!")

	if damage_button != null:
		print("DamageButton Found.")
		if not damage_button.pressed.is_connected(_on_damage_button_pressed):
			error_code = damage_button.pressed.connect(_on_damage_button_pressed)
			if error_code != OK: printerr("Failed connect DamageButton signal: ", error_code)
			else: print("DamageButton connected.")
	else:
		printerr("UpgradeScreen Error: DamageButton node is NULL!")

	if health_button != null:
		print("HealthButton Found.")
		if not health_button.pressed.is_connected(_on_health_button_pressed):
			error_code = health_button.pressed.connect(_on_health_button_pressed)
			if error_code != OK: printerr("Failed connect HealthButton signal: ", error_code)
			else: print("HealthButton connected.")
	else:
		printerr("UpgradeScreen Error: HealthButton node is NULL!")

	if next_wave_button != null:
		print("NextWaveButton Found.")
		if not next_wave_button.pressed.is_connected(_on_next_wave_button_pressed):
			error_code = next_wave_button.pressed.connect(_on_next_wave_button_pressed)
			if error_code != OK: printerr("Failed connect NextWaveButton signal: ", error_code)
			else: print("NextWaveButton connected.")
	else:
		printerr("UpgradeScreen Error: NextWaveButton node is NULL!")


	# --- Null checks for labels (less critical for signals but good practice) ---
	if not foot_count_label: printerr("UpgradeScreen Error: FootCountLabel missing!")
	if not claw_count_label: printerr("UpgradeScreen Error: ClawCountLabel missing!")
	if not core_count_label: printerr("UpgradeScreen Error: CoreCountLabel missing!")


	# Update button text
	if speed_button: speed_button.text = "Upgrade Speed (%d Feet)" % speed_cost
	if damage_button: damage_button.text = "Upgrade Damage (%d Claws)" % damage_cost
	if health_button: health_button.text = "Upgrade Health (%d Cores)" % health_cost


func update_display(feet: int, claws: int, cores: int):
	if foot_count_label: foot_count_label.text = "x %d" % feet
	else: printerr("Cannot update display: foot_count_label is null")
	if claw_count_label: claw_count_label.text = "x %d" % claws
	else: printerr("Cannot update display: claw_count_label is null")
	if core_count_label: core_count_label.text = "x %d" % cores
	else: printerr("Cannot update display: core_count_label is null")

	if speed_button: speed_button.disabled = (feet < speed_cost)
	if damage_button: damage_button.disabled = (claws < damage_cost)
	if health_button: health_button.disabled = (cores < health_cost)


# --- Button Press Handlers (with Debug Prints) ---
func _on_speed_button_pressed():
	print("UpgradeScreen: Speed button pressed.") # DEBUG
	emit_signal("upgrade_requested", "speed")

func _on_damage_button_pressed():
	print("UpgradeScreen: Damage button pressed.") # DEBUG
	emit_signal("upgrade_requested", "damage")

func _on_health_button_pressed():
	print("UpgradeScreen: Health button pressed.") # DEBUG
	emit_signal("upgrade_requested", "health")

func _on_next_wave_button_pressed():
	print("UpgradeScreen: Next Wave button pressed.") # DEBUG
	emit_signal("next_wave_requested")


func _notification(what):
	# Using the integer value 22 for NOTIFICATION_VISIBILITY_CHANGED as a workaround
	if what == 22:
		if not visible and get_tree().paused:
			print("Upgrade screen hidden (Notification 22), unpausing tree.") # Debug print
			get_tree().paused = false
