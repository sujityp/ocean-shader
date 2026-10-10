extends Node3D

@export var rotation_speed: float = 3.0
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 3.0
@export var max_zoom: float = 30.0

var current_zoom: float = 3.0
@onready var camera: Camera3D = $Camera3D

func _ready():
	# Offset the child camera so it sits away from the origin
	camera.position = Vector3(0, 0, current_zoom)
	# Ensure the camera looks straight down the parent's local Z axis
	camera.rotation = Vector3.ZERO

func _process(delta: float):
	var input_dir = Vector2.ZERO

	# Horizontal rotation (A/D)
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1

	# Vertical rotation (W/S)
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y -= 1
	
	# Apply rotations to the pivot
	# Subtracting the X input orbits the camera smoothly around the Y axis
	rotation.y -= input_dir.x * rotation_speed * delta
	# Subtracting the Y input pitches the camera up and down
	rotation.x -= input_dir.y * rotation_speed * delta

	# Clamp the vertical rotation to prevent the camera from flipping upside down
	rotation.x = clamp(rotation.x, -deg_to_rad(89), deg_to_rad(89))

func _unhandled_input(event: InputEvent):
	# Handle Mouse Wheel for zooming
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom += zoom_speed

		# Clamp the zoom distance so we don't go through the origin or too far away
		current_zoom = clamp(current_zoom, min_zoom, max_zoom)
		
		# Apply the new zoom distance to the child camera
		camera.position.z = current_zoom
