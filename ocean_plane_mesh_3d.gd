extends MeshInstance3D

@export var NUM_WAVES: int = 10
# The prevailing wind direction (e.g., traveling along the X axis)
@export var WIND_DIRECTION: Vector2 = Vector2(1.0, 0.0) 
# How much the waves vary from the wind direction (0.0 = perfect grid, 1.0 = chaotic)
@export_range(0.0, 1.0) var DIRECTION_SPREAD: float = 2

func _ready() -> void:
	var curr_mesh = get_active_material(0)
	if not curr_mesh: return
	
	var directions: Array[Vector2] = []
	var phases: Array[float] = []
	
	# Get the base angle of the wind in radians
	var base_angle = WIND_DIRECTION.normalized().angle()
	
	for i in range(NUM_WAVES):
		# Calculate a random angle spread based on the DIRECTION_SPREAD factor
		# PI * spread means at 0.5 spread, waves vary up to 90 degrees left or right
		var max_variance = PI * DIRECTION_SPREAD
		var spread = randf_range(-max_variance, max_variance)
		
		# Optional: Make higher-frequency ripples (higher 'i') more chaotic than base swells
		# spread *= 1.0 + (float(i) / float(NUM_WAVES)) 
		
		var final_angle = base_angle + spread
		directions.append(Vector2(cos(final_angle), sin(final_angle)))
		
		# Phases remain entirely random to prevent wave stacking
		phases.append(randf_range(0.0, TAU))
	
	curr_mesh.set_shader_parameter("directions", directions)
	curr_mesh.set_shader_parameter("phases", phases)
	curr_mesh.set_shader_parameter("active", true)
