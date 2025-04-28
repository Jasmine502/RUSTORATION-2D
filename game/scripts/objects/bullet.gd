# res://scripts/objects/Bullet.gd
extends Area2D

@export var speed: float = 800.0
# --- NEW: Damage Variable ---
var damage: int = 1 # Default damage, will be set by Player

@onready var visibility_notifier = $VisibilityNotifier
var _velocity: Vector2 = Vector2.ZERO

func _ready():
	if visibility_notifier == null: printerr("ERROR: VisibilityNotifier node missing!")
	else: visibility_notifier.screen_exited.connect(queue_free)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func start(start_position: Vector2, direction: Vector2):
	global_position = start_position
	_velocity = direction.normalized() * speed
	rotation = _velocity.angle()

func _process(delta):
	global_position += _velocity * delta

func _on_area_entered(other_area):
	var parent_node = other_area.get_parent()
	if parent_node != null and parent_node.has_method("take_damage"):
		# Pass the bullet's damage value to the enemy
		parent_node.take_damage(damage)
		queue_free() # Destroy bullet after dealing damage
