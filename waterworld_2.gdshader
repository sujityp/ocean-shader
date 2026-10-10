shader_type spatial;


const int MAX_WAVES = 64;

group_uniforms Sum_of_sines;
uniform int wave_count = 4;

// Wave params stored as (amplitude, positional frequency, speed, phase)
uniform vec4 wave_params[MAX_WAVES];
uniform vec2 wave_directions[MAX_WAVES];

void vertex() {
	float height = 0.0;
	for (int i = 0; i<MAX_WAVES; i++) {
		if (i>=wave_count) break;
		
		float amp = wave_params[i].x;
		float xfreq = wave_params[i].y;
		float speed = wave_params[i].z;
		float phase = wave_params[i].w;
		vec2 dir = wave_directions[i];
		
		height += amp * sin(xfreq*dot(dir, VERTEX.xz) + speed*TIME + phase);
	}
	VERTEX.y = height;
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
