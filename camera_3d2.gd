extends Camera3D

@export var move_speed: float = 1.0
@export var look_sensitivity: float = 0.003
@export var zoom_speed: float = 0.1

var _is_orbiting: bool = false
var _is_panning: bool = false

func _ready() -> void:
	# Ensure the camera can process input
	set_process_input(true)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse Button Press/Release
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Shift + MMB = Pan | MMB = Orbit
			if Input.is_key_pressed(KEY_SHIFT):
				_is_panning = event.pressed
				_is_orbiting = false
			else:
				_is_orbiting = event.pressed
				_is_panning = false

			# Toggle mouse capture mode based on state
			if _is_orbiting or _is_panning:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Scroll Wheel Zooming
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			translate_object_local(Vector3(0, 0, -zoom_speed))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			translate_object_local(Vector3(0, 0, zoom_speed))

	# Mouse Movement
	if event is InputEventMouseMotion:
		if _is_orbiting:
			# Orbiting rotates around local X and global Y
			rotate_y(-event.relative.x * look_sensitivity)
			rotate_object_local(Vector3.RIGHT, -event.relative.y * look_sensitivity)
		elif _is_panning:
			# Panning moves along the camera's local X and Y axes
			translate_object_local(Vector3(
				-event.relative.x * look_sensitivity * move_speed,
				event.relative.y * look_sensitivity * move_speed,
				0
			))

func _process(delta: float) -> void:
	# Fly mode (Right Click + WASD) like the editor
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		var input_dir: Vector3 = Vector3.ZERO
		if Input.is_action_pressed("move_forward"): input_dir.z -= 1
		if Input.is_action_pressed("move_backward"): input_dir.z += 1
		if Input.is_action_pressed("move_left"): input_dir.x -= 1
		if Input.is_action_pressed("move_right"): input_dir.x += 1
		if Input.is_action_pressed("move_up"): input_dir.y += 1
		if Input.is_action_pressed("move_down"): input_dir.y -= 1

		translate_object_local(input_dir.normalized() * move_speed * delta)
	elif not _is_orbiting and not _is_panning:
		# Release mouse control if no camera action is active
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
