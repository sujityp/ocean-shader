shader_type spatial;


const int MAX_WAVES = 64;

group_uniforms Sum_of_sines;
uniform int wave_count = 10;
uniform vec4 wave_params[MAX_WAVES];
uniform vec4 wave_directions[MAX_WAVES];

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
