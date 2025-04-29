# res://scripts/ui/upgrade_screen.gd
extends CanvasLayer

# --- SIGNALS ---
signal upgrade_requested(upgrade_type) # For Speed, Damage, Health
signal next_wave_requested
signal scrap_requested(scrap_type) # For Foot, Claw, Core
# Add signals for Buy/Sell later if needed
# signal buy_item_requested(item_id)
# signal sell_item_requested(item_id)

# --- CONSTANTS ---
# Approximate scale: Player width 82px assumed to be ~1m
const PIXELS_PER_METER: float = 82.0
# --- NEW: Damage Scaling Factor ---
const DAMAGE_TO_NEWTON_SCALE: float = 10000.0 # Base damage 1 = 10,000 N

# --- NODES ---
# Top Bar (Adjust paths if needed)
@onready var rust_coin_label: Label = $MainMargins/MainVerticalLayout/TopBar/RustCoinLabel
@onready var foot_count_label: Label = $MainMargins/MainVerticalLayout/TopBar/SalvageCounts/FootCountLabel
@onready var claw_count_label: Label = $MainMargins/MainVerticalLayout/TopBar/SalvageCounts/ClawCountLabel
@onready var core_count_label: Label = $MainMargins/MainVerticalLayout/TopBar/SalvageCounts/CoreCountLabel
@onready var scrap_foot_button: TextureButton = $MainMargins/MainVerticalLayout/TopBar/SalvageCounts/FootCountLabel/ScrapFootButton # Path relative to FootCountLabel
@onready var scrap_claw_button: TextureButton = $MainMargins/MainVerticalLayout/TopBar/SalvageCounts/ClawCountLabel/ScrapClawButton # Path relative to ClawCountLabel
@onready var scrap_core_button: TextureButton = $MainMargins/MainVerticalLayout/TopBar/SalvageCounts/CoreCountLabel/ScrapCoreButton # Path relative to CoreCountLabel
# Left Panel
@onready var item_list: VBoxContainer = $MainMargins/MainVerticalLayout/MainSplit/LeftPanel/LeftLayout/ItemListScroll/ItemList
# Right Panel - Stats (Adjust paths if needed)
@onready var health_tier_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer/HBoxContainer/HealthTierLabel
@onready var health_progress_bar: ProgressBar = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer/HBoxContainer2/HealthProgressBar
@onready var health_progress_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer/HBoxContainer2/HealthProgressLabel
@onready var damage_tier_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer4/HBoxContainer/DamageTierLabel
@onready var damage_progress_bar: ProgressBar = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer4/HBoxContainer3/DamageProgressBar
@onready var damage_progress_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer4/HBoxContainer3/DamageProgressLabel
@onready var speed_tier_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer5/HBoxContainer/SpeedTierLabel
@onready var speed_progress_bar: ProgressBar = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer5/HBoxContainer2/SpeedProgressBar
@onready var speed_progress_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer5/HBoxContainer2/SpeedProgressLabel
# --- NEW: Current Stat Labels ---
@onready var current_core_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer/HBoxContainer/CurrentCoreLabel # Ensure path is correct
@onready var current_damage_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer4/HBoxContainer/CurrentDamageLabel # Ensure path is correct
@onready var current_speed_label: Label = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer5/HBoxContainer/CurrentSpeedLabel # Ensure path is correct
# --- End NEW Labels ---
# Right Panel - Buttons
@onready var upgrade_health_button: Button = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer/UpgradeHealthButton
@onready var upgrade_damage_button: Button = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer4/UpgradeDamageButton
@onready var upgrade_speed_button: Button = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/StatsBox/HBoxContainer5/UpgradeSpeedButton
@onready var buy_button: Button = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/ActionButtons/BuyButton
@onready var install_button: Button = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/ActionButtons/InstallButton
@onready var next_wave_button: Button = $MainMargins/MainVerticalLayout/MainSplit/RightPanel/RightLayout/NextWaveButton

# --- INTERNAL ---


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("--- UpgradeScreen _ready() CALLED ---")
	# --- Null Checks ---
	# KEEP null checks for the nodes themselves, this is important!
	if not rust_coin_label: printerr("UpgradeScreen Error: RustCoinLabel missing!")
	if not foot_count_label: printerr("UpgradeScreen Error: FootCountLabel missing!")
	if not claw_count_label: printerr("UpgradeScreen Error: ClawCountLabel missing!")
	if not core_count_label: printerr("UpgradeScreen Error: CoreCountLabel missing!")
	if not scrap_foot_button: printerr("UpgradeScreen Error: ScrapFootButton missing!")
	if not scrap_claw_button: printerr("UpgradeScreen Error: ScrapClawButton missing!")
	if not scrap_core_button: printerr("UpgradeScreen Error: ScrapCoreButton missing!")
	if not item_list: printerr("UpgradeScreen Error: ItemList VBoxContainer missing!")
	if not health_tier_label: printerr("UpgradeScreen Error: HealthTierLabel missing!")
	if not health_progress_bar: printerr("UpgradeScreen Error: HealthProgressBar missing!")
	if not health_progress_label: printerr("UpgradeScreen Error: HealthProgressLabel missing!")
	if not damage_tier_label: printerr("UpgradeScreen Error: DamageTierLabel missing!")
	if not damage_progress_bar: printerr("UpgradeScreen Error: DamageProgressBar missing!")
	if not damage_progress_label: printerr("UpgradeScreen Error: DamageProgressLabel missing!")
	if not speed_tier_label: printerr("UpgradeScreen Error: SpeedTierLabel missing!")
	if not speed_progress_bar: printerr("UpgradeScreen Error: SpeedProgressBar missing!")
	if not speed_progress_label: printerr("UpgradeScreen Error: SpeedProgressLabel missing!")
	if not current_core_label: printerr("UpgradeScreen Error: CurrentCoreLabel missing!")
	if not current_damage_label: printerr("UpgradeScreen Error: CurrentDamageLabel missing!")
	if not current_speed_label: printerr("UpgradeScreen Error: CurrentSpeedLabel missing!")
	if not upgrade_health_button: printerr("UpgradeScreen Error: UpgradeHealthButton missing!")
	if not upgrade_damage_button: printerr("UpgradeScreen Error: UpgradeDamageButton missing!")
	if not upgrade_speed_button: printerr("UpgradeScreen Error: UpgradeSpeedButton missing!")
	if not next_wave_button: printerr("UpgradeScreen Error: NextWaveButton missing!")

	# --- CONNECTIONS WITHOUT CHECKS ---
	# Remove the err_code variable and the if checks
	if upgrade_health_button: upgrade_health_button.pressed.connect(_on_health_button_pressed)
	if upgrade_damage_button: upgrade_damage_button.pressed.connect(_on_damage_button_pressed)
	if upgrade_speed_button: upgrade_speed_button.pressed.connect(_on_speed_button_pressed)
	if scrap_foot_button: scrap_foot_button.pressed.connect(_on_scrap_foot_button_pressed)
	if scrap_claw_button: scrap_claw_button.pressed.connect(_on_scrap_claw_button_pressed)
	if scrap_core_button: scrap_core_button.pressed.connect(_on_scrap_core_button_pressed)
	if next_wave_button: next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	# --- END CONNECTIONS ---

	_populate_weapon_list()
	_set_shop_mode("buy")


# --- Updated update_display function ---
func update_display(p_feet: int, p_claws: int, p_cores: int, p_rust_coin: int, p_stats: Dictionary):
	# Update Counts
	if foot_count_label: foot_count_label.text = "x %d" % p_feet
	if claw_count_label: claw_count_label.text = "x %d" % p_claws
	if core_count_label: core_count_label.text = "x %d" % p_cores
	if rust_coin_label: rust_coin_label.text = "%d" % p_rust_coin

	# --- Update Stat Tiers/Progress ---
	var health_tier = p_stats.get("health_tier", 0)
	var health_progress = p_stats.get("health_progress", 0)
	var health_needed = p_stats.get("health_needed", 5)
	if health_tier_label: health_tier_label.text = "TIER %d" % health_tier
	if health_progress_bar: health_progress_bar.max_value = health_needed; health_progress_bar.value = health_progress
	if health_progress_label: health_progress_label.text = "%d/%d" % [health_progress, health_needed]

	var damage_tier = p_stats.get("damage_tier", 0)
	var damage_progress = p_stats.get("damage_progress", 0)
	var damage_needed = p_stats.get("damage_needed", 5)
	if damage_tier_label: damage_tier_label.text = "TIER %d" % damage_tier
	if damage_progress_bar: damage_progress_bar.max_value = damage_needed; damage_progress_bar.value = damage_progress
	if damage_progress_label: damage_progress_label.text = "%d/%d" % [damage_progress, damage_needed]

	var speed_tier = p_stats.get("speed_tier", 0)
	var speed_progress = p_stats.get("speed_progress", 0)
	var speed_needed = p_stats.get("speed_needed", 5)
	if speed_tier_label: speed_tier_label.text = "TIER %d" % speed_tier
	if speed_progress_bar: speed_progress_bar.max_value = speed_needed; speed_progress_bar.value = speed_progress
	if speed_progress_label: speed_progress_label.text = "%d/%d" % [speed_progress, speed_needed]

	# --- Update Current Stat Labels ---
	var current_health = p_stats.get("current_health", 0)
	var current_max_health = p_stats.get("current_max_health", 100)
	var current_damage = p_stats.get("current_damage", 1)
	var current_speed = p_stats.get("current_speed", 300.0)

	if current_core_label:
		current_core_label.text = "(%d/%d)" % [current_health, current_max_health]

	# --- MODIFIED DAMAGE LABEL ---
	if current_damage_label:
		# Scale the damage value and cast to int
		var scaled_damage = int(round(float(current_damage) * DAMAGE_TO_NEWTON_SCALE))
		current_damage_label.text = "(%d N)" % scaled_damage
	# --- END MODIFICATION ---

	if current_speed_label:
		var speed_mps = (current_speed / PIXELS_PER_METER)
		# Round m/s to 1 decimal place
		var speed_mps_rounded = round(speed_mps * 10.0) / 10.0
		current_speed_label.text = "(%.1f m/s)" % speed_mps_rounded

	# --- Button Disabling Logic ---
	var current_total_salvage = p_feet + p_claws + p_cores

	if upgrade_health_button: upgrade_health_button.disabled = (current_total_salvage < health_needed); upgrade_health_button.text = "Upgrade (%d)" % health_needed
	if upgrade_damage_button: upgrade_damage_button.disabled = (current_total_salvage < damage_needed); upgrade_damage_button.text = "Upgrade (%d)" % damage_needed
	if upgrade_speed_button: upgrade_speed_button.disabled = (current_total_salvage < speed_needed); upgrade_speed_button.text = "Upgrade (%d)" % speed_needed

	if scrap_foot_button: scrap_foot_button.disabled = (p_feet <= 0)
	if scrap_claw_button: scrap_claw_button.disabled = (p_claws <= 0)
	if scrap_core_button: scrap_core_button.disabled = (p_cores <= 0)


# --- Button Press Handlers ---
func _on_speed_button_pressed(): emit_signal("upgrade_requested", "speed")
func _on_damage_button_pressed(): emit_signal("upgrade_requested", "damage")
func _on_health_button_pressed(): emit_signal("upgrade_requested", "health")

func _on_scrap_foot_button_pressed(): emit_signal("scrap_requested", "foot")
func _on_scrap_claw_button_pressed(): emit_signal("scrap_requested", "claw")
func _on_scrap_core_button_pressed(): emit_signal("scrap_requested", "core")

func _on_next_wave_button_pressed(): emit_signal("next_wave_requested")


func _populate_weapon_list():
	if item_list == null: printerr("Cannot populate weapon list: item_list node not found!"); return
	for child in item_list.get_children(): child.queue_free()
	var temp_label = Label.new(); temp_label.text = "Weapon List (TODO)"; item_list.add_child(temp_label)


func _set_shop_mode(mode: String):
	if mode == "buy":
		if buy_button: buy_button.visible = true; if install_button: install_button.visible = false
	elif mode == "sell":
		if buy_button: buy_button.visible = false; if install_button: install_button.visible = false
	else: printerr("Unknown shop mode: ", mode)


# --- Use Integer Value for Notification ---
func _notification(what):
	# Use 22 directly, which is the value for NOTIFICATION_VISIBILITY_CHANGED
	# This is a workaround if Node.NOTIFICATION_VISIBILITY_CHANGED isn't resolving
	if what == 22:
		if not visible and get_tree().paused:
			# Game.gd should handle unpausing correctly when the next wave starts.
			# No action needed here typically.
			pass
