extends MeshInstance3D

@export var NUM_WAVES: int = 10

func _ready() -> void:
	var curr_mesh = get_active_material(0)
	if not curr_mesh: return
	
	var directions: Array[Vector2] = []
	var waveparams: Array[Vector4] = []
	
	for i in range(NUM_WAVES):
		var theta = randf_range(0, 2*PI)
		var dir: Vector2 = Vector2(cos(theta), sin(theta))
		var amp = randf_range(0, 0.1)
		var freq = randf_range(0, 10)
		var speed = randf_range(0, 1)
		var phase = randf_range(0, 2*PI)
		
		directions.append(dir)
		waveparams.append(Vector4(amp, freq, speed, phase))
		
		curr_mesh.set_shader_parameter("wave_params", waveparams)
		curr_mesh.set_shader_parameter("wave_directions", directions)
