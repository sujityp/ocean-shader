shader_type spatial;

//render_mode cull_disabled;
render_mode diffuse_lambert;

const int NUM_WAVES = 10;
uniform bool active = false;
uniform vec3 surface_color = vec3(0.5, 0.5, 0.5);
uniform float HEIGHT_SCALE = 1.0;
uniform float SHININESS = 300.0;
uniform float MAX_PEAK = 1.0;
uniform float PEAK_OFFSET = 1.14;
uniform float MAX_WAVELENGTH = 6.28;
uniform float FBR_WAVELENGTH = 1.16;
uniform float MAX_AMPLITUDE = 1;
uniform float FBR_AMPLITUDE = 0.83;
uniform float MAX_SPEED = 2;
uniform float FBR_SPEED = 0.9;
uniform vec2 directions[NUM_WAVES];
uniform float phases[NUM_WAVES];

// --- FRAGMENT SETTINGS ---
uniform int NUM_FRAG_WAVES = 10;
uniform float FRAG_MAX_AMPLITUDE = 1.0;
uniform float FRAG_MAX_WAVELENGTH = 6.28; 
uniform float FRAG_MAX_SPEED = 2.0;
uniform float FRAG_FBR_AMPLITUDE = 0.83;
uniform float FRAG_FBR_WAVELENGTH = 1.16;
uniform float FRAG_FBR_SPEED = 1.07;
uniform float NORMAL_STRENGTH = 1.0;

// This passes the local 3D position from vertex to fragment
varying vec2 pos_xz;

// Modified sine wave to be an exponential wave
void vertex() {
	if (active){
		// Save the local XZ coordinates before any displacement
	    pos_xz = VERTEX.xz;
		
		float height = 0.0;
		float dy_dx = 0.0;
		float dy_dz = 0.0;
		
		float frequency = 2.0*PI/MAX_WAVELENGTH;
		float speed = MAX_SPEED;
		float amplitude = MAX_AMPLITUDE;
		
	// Variables to track normalization and stable domain warping
	    float amplitude_sum = 0.0; 
	    vec2 domain_warp = vec2(0.0);
	    float vertex_drag = 0.5;
		
		for (int i = 0; i<NUM_WAVES; i++) {
			float pos_term = dot(directions[i], VERTEX.xz + domain_warp) * frequency;
			float time_term = speed * TIME * frequency;
			float inner = pos_term + time_term + phases[i];
			
			float function = amplitude * exp(MAX_PEAK * sin(inner) - PEAK_OFFSET);
			float cosval = cos(inner);
			height += function;
			
			dy_dx += function * cosval * frequency * directions[i].x;
			dy_dz += function * cosval * frequency * directions[i].y;
			
			// Calculate the stable domain warp shift (NO frequency, scaled by amplitude and drag)
			float warp_shift = MAX_PEAK * function * cosval; 
			domain_warp += directions[i] * -warp_shift * amplitude * vertex_drag;
			
			amplitude_sum += amplitude;
			
			frequency *= FBR_WAVELENGTH;
			speed *= FBR_SPEED;
			amplitude *= FBR_AMPLITUDE;
		}
		//// Normalize the final outputs by the sum of amplitudes
		//VERTEX.y += (height / amplitude_sum) * HEIGHT_SCALE;
		//dy_dx /= amplitude_sum;
		//dy_dz /= amplitude_sum;
		
		VERTEX.y = (height) * HEIGHT_SCALE;

		
		// Optional: The tutorial scales the final normalized height by a master parameter
	    // VERTEX.y *= 1.48;
		
		NORMAL = normalize(vec3(-dy_dx, 1.0, -dy_dz));
	}
}

void fragment() {
	if (active) {
		ALBEDO = surface_color;

		// We only need derivatives here, not the height, because we aren't displacing pixels
		float dy_dx = 0.0;
		float dy_dz = 0.0;

		float current_freq = (2.0 * PI) / FRAG_MAX_WAVELENGTH;
		float current_speed = FRAG_MAX_SPEED;
		float current_amp = FRAG_MAX_AMPLITUDE;

		float amplitude_sum = 0.0;
		vec2 domain_warp = vec2(0.0);
		float frag_drag = 0.5;

		for (int i = 0; i < NUM_FRAG_WAVES; i++) {
			// Use pos_xz passed from the vertex shader
			float pos_term = dot(directions[i], pos_xz + domain_warp) * current_freq;
			float time_term = current_speed * TIME * current_freq;
			float inner = pos_term + time_term + phases[i];

			// Calculate the derivative of the exponential sine wave
			float function = current_amp * exp(MAX_PEAK * sin(inner) - PEAK_OFFSET);
			float cosval = cos(inner);

			dy_dx += MAX_PEAK * function * cosval * current_freq * directions[i].x;
			dy_dz += MAX_PEAK * function * cosval * current_freq * directions[i].y;

			float warp_shift = MAX_PEAK * function * cosval;
			domain_warp += directions[i] * -warp_shift * current_amp * frag_drag;

			amplitude_sum += current_amp;
			
			// Multiply by fractal parameters for the next iteration
			current_freq *= FRAG_FBR_WAVELENGTH;
			current_amp *= FRAG_FBR_AMPLITUDE;
			current_speed *= FRAG_FBR_SPEED;
		}

		// Normalize the fragment derivatives and apply the normal strength
		// Normalize the fragment derivatives
	    //dy_dx /= amplitude_sum;
	    //dy_dz /= amplitude_sum;
		dy_dx *= NORMAL_STRENGTH;
		dy_dz *= NORMAL_STRENGTH;

		// Construct the local normal vector
		vec3 local_normal = normalize(vec3(-dy_dx, 1.0, -dy_dz));
		// Convert the local normal to View Space for Godot's lighting engine
		vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * local_normal);
		NORMAL = normalize(mat3(VIEW_MATRIX) * world_normal);
	}
}




void light() {
	if (active) {
		// Used for all other light types (directional, omni, spot).
		DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * ALBEDO * LIGHT_COLOR / PI;
		float ndoth = max(
		    dot(normalize(VIEW + LIGHT), NORMAL),
		    0.0
		);
		SPECULAR_LIGHT += pow(ndoth, SHININESS) * ATTENUATION * LIGHT_COLOR;
	}
}

/*
// Used for sum of sines
void vertex() {
	float height = 0.0;
	float dy_dx = 0.0;
	float dy_dz = 0.0;
	for (int i = 0; i<NUM_WAVES; i++) {
		float pos_term = dot(directions[i], VERTEX.xz) * frequencies[i];
		float time_term = speeds[i] * TIME * frequencies[i];
		height += amplitudes[i] * sin(pos_term + time_term);
		dy_dx += amplitudes[i] * directions[i].x * frequencies[i] * cos(pos_term + time_term);
		dy_dz += amplitudes[i] * directions[i].y * frequencies[i] * cos(pos_term + time_term);
	}
	VERTEX.y = height;
	NORMAL = normalize(vec3(-dy_dx, 1.0, -dy_dz));
}
*/