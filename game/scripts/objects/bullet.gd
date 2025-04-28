# res://Scripts/Objects/Bullet.gd
extends Area2D # Make sure the root node is Area2D

@export var speed: float = 800.0 

@onready var visibility_notifier = $VisibilityNotifier

var _velocity: Vector2 = Vector2.ZERO 

func _ready():
	if visibility_notifier == null:
		printerr("ERROR: VisibilityNotifier node not found in Bullet scene!")
		return 
	visibility_notifier.screen_exited.connect(queue_free)
	
	# --- CHANGE THIS ---
	# Connect the bullet's own area_entered signal to handle hitting Zomborg HitboxArea
	area_entered.connect(_on_area_entered)
	# -----------------

func start(start_position: Vector2, direction: Vector2):
	global_position = start_position
	_velocity = direction.normalized() * speed
	rotation = _velocity.angle() 

func _process(delta):
	global_position += _velocity * delta

# --- ADD THIS FUNCTION ---
# This function is called when another Area2D enters the bullet's Area2D
func _on_area_entered(other_area):
	# Check if the area we hit belongs to a Zomborg
	# We access the parent of the area (which should be the Zomborg CharacterBody2D)
	var parent_node = other_area.get_parent()
	
	# Check if the parent exists and has the take_damage method (meaning it's likely our Zomborg)
	if parent_node != null and parent_node.has_method("take_damage"):
		# Optionally, you could also check if parent_node is in the "enemies" group
		print("Bullet hit Zomborg hitbox: ", other_area.name, " Parent: ", parent_node.name)
		parent_node.take_damage(1) # Call the Zomborg's take_damage function
		queue_free() # Destroy the bullet
	# else:
		# Optional: Print if we hit something else that wasn't a Zomborg hitbox
		# print("Bullet hit UNKNOWN area: ", other_area.name)
