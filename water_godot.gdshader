shader_type spatial;
render_mode cull_back, depth_draw_opaque, world_vertex_coords;

const int MAX_WAVES = 32;
const float EPSILON = 0.000001;

// -----------------------------------------------------------------------------
// Feature switches
// -----------------------------------------------------------------------------
group_uniforms Features;
uniform bool use_vertex_displacement = true;
uniform int wave_mode : hint_enum("Sine", "Steep Sine", "Gerstner") = 2;
uniform bool normals_in_fragment = true;
uniform bool circular_waves = false;
uniform bool use_fbm = true;

// -----------------------------------------------------------------------------
// Explicit waves (used when use_fbm == false)
// -----------------------------------------------------------------------------
group_uniforms Waves;
uniform int wave_count : hint_range(0, 32, 1) = 0;
uniform vec4 wave_direction_origin[32];
uniform vec4 wave_params[32];

// -----------------------------------------------------------------------------
// Vertex FBM
// -----------------------------------------------------------------------------
group_uniforms VertexFBM;
uniform int vertex_wave_count : hint_range(0, 32, 1) = 8;
uniform float vertex_seed = 0.0;
uniform float vertex_seed_iter = 2.4;
uniform float vertex_frequency = 1.0;
uniform float vertex_frequency_mult = 1.18;
uniform float vertex_amplitude = 1.0;
uniform float vertex_amplitude_mult = 0.82;
uniform float vertex_initial_speed = 1.0;
uniform float vertex_speed_ramp = 1.07;
uniform float vertex_drag = 0.2;
uniform float vertex_height = 1.0;
uniform float vertex_max_peak = 1.0;
uniform float vertex_peak_offset = 1.14;

// -----------------------------------------------------------------------------
// Fragment FBM
// -----------------------------------------------------------------------------
group_uniforms FragmentFBM;
uniform int fragment_wave_count : hint_range(0, 32, 1) = 10;
uniform float fragment_seed = 0.0;
uniform float fragment_seed_iter = 2.4;
uniform float fragment_frequency = 1.0;
uniform float fragment_frequency_mult = 1.18;
uniform float fragment_amplitude = 1.0;
uniform float fragment_amplitude_mult = 0.82;
uniform float fragment_initial_speed = 1.0;
uniform float fragment_speed_ramp = 1.07;
uniform float fragment_drag = 0.2;
uniform float fragment_height = 1.0;
uniform float fragment_max_peak = 1.0;
uniform float fragment_peak_offset = 1.14;

// -----------------------------------------------------------------------------
// Lighting / appearance
// -----------------------------------------------------------------------------
group_uniforms Lighting;
uniform vec3 sun_direction = vec3(0.0, -1.0, 0.0);
uniform vec4 light_color : source_color = vec4(1.0);
uniform vec4 sun_color : source_color = vec4(1.0);

uniform vec4 ambient_color : source_color = vec4(0.02, 0.03, 0.04, 1.0);
uniform vec4 diffuse_reflectance : source_color = vec4(0.05, 0.18, 0.24, 1.0);
uniform vec4 specular_reflectance : source_color = vec4(1.0);
uniform vec4 fresnel_color : source_color = vec4(0.35, 0.55, 0.70, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0);

uniform float shininess : hint_range(1.0, 1000.0, 1.0) = 300.0;
uniform float fresnel_bias : hint_range(0.0, 1.0, 0.001) = 0.02;
uniform float fresnel_strength : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float fresnel_shininess : hint_range(0.1, 20.0, 0.1) = 5.0;
uniform float tip_attenuation : hint_range(0.01, 20.0, 0.01) = 1.0;
uniform float normal_strength : hint_range(0.0, 8.0, 0.01) = 1.0;
uniform float fresnel_normal_strength : hint_range(0.0, 8.0, 0.01) = 1.0;
uniform float specular_normal_strength : hint_range(0.0, 8.0, 0.01) = 1.0;

group_uniforms Environment;
uniform bool use_environment_map = false;
uniform samplerCube environment_map;

group_uniforms;

// Values passed from vertex() to fragment(). Because world_vertex_coords is
// enabled, these are directly in world space.
varying vec3 world_position;
varying vec3 world_normal;


// -----------------------------------------------------------------------------
// Explicit wave helpers
// -----------------------------------------------------------------------------

vec2 get_wave_direction(vec3 v, int wi) {
    if (circular_waves) {
        vec2 p = v.xz;
        vec2 origin = wave_direction_origin[wi].zw;
        return normalize(p - origin);
    }

    return wave_direction_origin[wi].xy;
}

float get_wave_coord(vec3 v, vec2 d, int wi) {
    if (circular_waves) {
        vec2 p = v.xz;
        vec2 origin = wave_direction_origin[wi].zw;
        return length(p - origin);
    }

    return v.x * d.x + v.z * d.y;
}

float get_wave_time(int wi) {
    float phase = wave_params[wi].z;
    if (circular_waves) {
        return -TIME * phase;
    }
    return TIME * phase;
}

float sine_wave(vec3 v, int wi) {
    vec2 d = get_wave_direction(v, wi);
    float xz = get_wave_coord(v, d, wi);
    float frequency = wave_params[wi].x;
    float amplitude = wave_params[wi].y;
    float t = get_wave_time(wi);

    return amplitude * sin(xz * frequency + t);
}

vec3 sine_normal(vec3 v, int wi) {
    vec2 d = get_wave_direction(v, wi);
    float xz = get_wave_coord(v, d, wi);
    float frequency = wave_params[wi].x;
    float amplitude = wave_params[wi].y;
    float t = get_wave_time(wi);

    vec2 n = frequency * amplitude * d * cos(xz * frequency + t);
    return vec3(n.x, n.y, 0.0);
}

float steep_sine_wave(vec3 v, int wi) {
    vec2 d = get_wave_direction(v, wi);
    float xz = get_wave_coord(v, d, wi);
    float frequency = wave_params[wi].x;
    float amplitude = wave_params[wi].y;
    float steepness = wave_params[wi].w;
    float t = get_wave_time(wi);

    return 2.0 * amplitude * pow(
        (sin(xz * frequency + t) + 1.0) / 2.0,
        steepness
    );
}

vec3 steep_sine_normal(vec3 v, int wi) {
    vec2 d = get_wave_direction(v, wi);
    float xz = get_wave_coord(v, d, wi);
    float frequency = wave_params[wi].x;
    float amplitude = wave_params[wi].y;
    float steepness = wave_params[wi].w;
    float t = get_wave_time(wi);

    float h = pow(
        (sin(xz * frequency + t) + 1.0) / 2.0,
        max(1.0, steepness - 1.0)
    );

    vec2 n = d * steepness * frequency * amplitude * h * cos(xz * frequency + t);
    return vec3(n.x, n.y, 0.0);
}

vec3 gerstner_wave(vec3 v, int wi) {
    vec2 d = get_wave_direction(v, wi);
    float xz = get_wave_coord(v, d, wi);
    float frequency = wave_params[wi].x;
    float amplitude = wave_params[wi].y;
    float steepness = wave_params[wi].w;
    float t = get_wave_time(wi);

    float angle = frequency * xz + t;

    vec3 g = vec3(0.0);
    g.x = steepness * amplitude * d.x * cos(angle);
    g.z = steepness * amplitude * d.y * cos(angle);
    g.y = amplitude * sin(angle);
    return g;
}

vec3 gerstner_normal(vec3 v, int wi) {
    vec2 d = get_wave_direction(v, wi);
    float xz = get_wave_coord(v, d, wi);
    float frequency = wave_params[wi].x;
    float amplitude = wave_params[wi].y;
    float phase = wave_params[wi].z;
    float steepness = wave_params[wi].w;

    float wa = frequency * amplitude;

    // This intentionally preserves the supplied Unity shader's normal phase,
    // which uses +TIME * phase here even when circular_waves is enabled.
    float s = sin(frequency * xz + TIME * phase);
    float c = cos(frequency * xz + TIME * phase);

    vec3 n = vec3(0.0);
    n.x = d.x * wa * c;
    n.z = d.y * wa * c;
    n.y = steepness * wa * s;
    return n;
}

vec3 calculate_offset(vec3 v, int wi) {
    if (wave_mode == 0) {
        return vec3(0.0, sine_wave(v, wi), 0.0);
    }
    if (wave_mode == 1) {
        return vec3(0.0, steep_sine_wave(v, wi), 0.0);
    }
    if (wave_mode == 2) {
        return gerstner_wave(v, wi);
    }

    return vec3(0.0);
}

vec3 calculate_normal(vec3 v, int wi) {
    if (wave_mode == 0) {
        return sine_normal(v, wi);
    }
    if (wave_mode == 1) {
        return steep_sine_normal(v, wi);
    }
    if (wave_mode == 2) {
        return gerstner_normal(v, wi);
    }

    return vec3(0.0);
}


// -----------------------------------------------------------------------------
// FBM wave fields
// -----------------------------------------------------------------------------

vec3 vertex_fbm(vec3 v) {
    float f = vertex_frequency;
    float a = vertex_amplitude;
    float speed = vertex_initial_speed;
    float seed = vertex_seed;
    vec3 p = v;

    float amplitude_sum = 0.0;
    float h = 0.0;

    // Preserved from the source: the vertex FBM routine never accumulates n.
    // With normals_in_fragment enabled, fragment_fbm supplies the detailed normal.
    vec2 n = vec2(0.0);

    int count = min(vertex_wave_count, MAX_WAVES);
    for (int wi = 0; wi < MAX_WAVES; wi++) {
        if (wi >= count) {
            break;
        }

        vec2 d = normalize(vec2(cos(seed), sin(seed)));
        float x = dot(d, p.xz) * f + TIME * speed;
        float wave = a * exp(vertex_max_peak * sin(x) - vertex_peak_offset);
        float dx = vertex_max_peak * wave * cos(x);

        h += wave;

        vec2 drag_offset = d * (-dx * a * vertex_drag);
        p.x += drag_offset.x;
        p.z += drag_offset.y;

        amplitude_sum += a;
        f *= vertex_frequency_mult;
        a *= vertex_amplitude_mult;
        speed *= vertex_speed_ramp;
        seed += vertex_seed_iter;
    }

    float inv_sum = 1.0 / max(abs(amplitude_sum), EPSILON);
    vec3 output_value = vec3(h, n.x, n.y) * inv_sum;
    output_value.x *= vertex_height;
    return output_value;
}

vec3 fragment_fbm(vec3 v) {
    float f = fragment_frequency;
    float a = fragment_amplitude;
    float speed = fragment_initial_speed;
    float seed = fragment_seed;
    vec3 p = v;

    float h = 0.0;
    vec2 n = vec2(0.0);
    float amplitude_sum = 0.0;

    int count = min(fragment_wave_count, MAX_WAVES);
    for (int wi = 0; wi < MAX_WAVES; wi++) {
        if (wi >= count) {
            break;
        }

        vec2 d = normalize(vec2(cos(seed), sin(seed)));
        float x = dot(d, p.xz) * f + TIME * speed;
        float wave = a * exp(fragment_max_peak * sin(x) - fragment_peak_offset);
        vec2 dw = f * d * (fragment_max_peak * wave * cos(x));

        h += wave;

        vec2 drag_offset = -dw * a * fragment_drag;
        p.x += drag_offset.x;
        p.z += drag_offset.y;

        n += dw;

        amplitude_sum += a;
        f *= fragment_frequency_mult;
        a *= fragment_amplitude_mult;
        speed *= fragment_speed_ramp;
        seed += fragment_seed_iter;
    }

    float inv_sum = 1.0 / max(abs(amplitude_sum), EPSILON);
    vec3 output_value = vec3(h, n.x, n.y) * inv_sum;
    output_value.x *= fragment_height;
    return output_value;
}

vec3 central_difference_normal(vec3 v, float epsilon) {
    float h = fragment_fbm(v).x;
    vec3 a = vec3(v.x, h, v.z);

    vec3 x_sample = v - vec3(epsilon, 0.0, 0.0);
    vec3 z_sample = v + vec3(0.0, 0.0, epsilon);

    vec3 b = a - vec3(v.x - epsilon, fragment_fbm(x_sample).x, v.z);
    vec3 c = a - vec3(v.x, fragment_fbm(z_sample).x, v.z + epsilon);

    return normalize(cross(b, c));
}


// -----------------------------------------------------------------------------
// Vertex stage
// -----------------------------------------------------------------------------

void vertex() {
    world_position = VERTEX;
    world_normal = normalize(NORMAL);

    if (use_vertex_displacement) {
	    vec3 offset = vec3(0.0);
	    vec3 normal_accum = vec3(0.0);

	    if (use_fbm) {
	        vec3 fbm = vertex_fbm(world_position);
	        offset.y = fbm.x;
	        normal_accum.xy = fbm.yz;
	    } else {
	        int count = min(wave_count, MAX_WAVES);
	        for (int wi = 0; wi < MAX_WAVES; wi++) {
	            if (wi >= count) {
	                break;
	            }

	            offset += calculate_offset(world_position, wi);

	            if (wave_mode != 2 && !normals_in_fragment) {
	                normal_accum += calculate_normal(world_position, wi);
	            }
	        }
	    }

	    // world_vertex_coords makes this a world-space displacement.
	    VERTEX += offset;
	    world_position = VERTEX;

	    if (!normals_in_fragment) {
	        if (!use_fbm && wave_mode == 2) {
	            normal_accum = vec3(0.0);

	            int count = min(wave_count, MAX_WAVES);
	            for (int wi = 0; wi < MAX_WAVES; wi++) {
	                if (wi >= count) {
	                    break;
	                }
	                normal_accum += calculate_normal(world_position, wi);
	            }

	            world_normal = normalize(vec3(
	                -normal_accum.x,
	                1.0 - normal_accum.y,
	                -normal_accum.z
	            ));
	        } else {
	            world_normal = normalize(vec3(
	                -normal_accum.x,
	                1.0,
	                -normal_accum.y
	            ));
	        }

	        // Also update Godot's vertex normal for consistency, even though this
	        // shader performs its final lighting manually in fragment().
	        NORMAL = world_normal;
	    }
	}
}


// -----------------------------------------------------------------------------
// Fragment stage
// -----------------------------------------------------------------------------

void fragment() {
    vec3 normal_value;
    float height = 0.0;

    if (normals_in_fragment) {
        vec3 normal_accum = vec3(0.0);

        if (use_fbm) {
            vec3 fbm = fragment_fbm(world_position);
            height = fbm.x;
            normal_accum.xy = fbm.yz;

            // FBM stores dH/dx and dH/dz in y/z of its return value.
            normal_value = normalize(vec3(
                -normal_accum.x,
                1.0,
                -normal_accum.y
            ));
        } else {
            int count = min(wave_count, MAX_WAVES);
            for (int wi = 0; wi < MAX_WAVES; wi++) {
                if (wi >= count) {
                    break;
                }
                normal_accum += calculate_normal(world_position, wi);
            }

            if (wave_mode == 2) {
                normal_value = normalize(vec3(
                    -normal_accum.x,
                    1.0 - normal_accum.y,
                    -normal_accum.z
                ));
            } else {
                normal_value = normalize(vec3(
                    -normal_accum.x,
                    1.0,
                    -normal_accum.y
                ));
            }
        }
    } else {
        normal_value = normalize(world_normal);
    }

    normal_value.xz *= normal_strength;
    normal_value = normalize(normal_value);

    vec3 light_dir = -normalize(sun_direction);
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
    vec3 halfway_dir = normalize(light_dir + view_dir);

    float ndotl = max(dot(light_dir, normal_value), 0.0);

    vec3 diffuse = light_color.rgb
        * ndotl
        * (diffuse_reflectance.rgb / PI);

    // Schlick-style Fresnel from the source shader.
    vec3 fresnel_normal = normal_value;
    fresnel_normal.xz *= fresnel_normal_strength;
    fresnel_normal = normalize(fresnel_normal);

    float fresnel_base = 1.0 - dot(view_dir, fresnel_normal);
    float fresnel_exponential = pow(fresnel_base, fresnel_shininess);
    float reflectance = fresnel_exponential
        + fresnel_bias * (1.0 - fresnel_exponential);
    reflectance *= fresnel_strength;

    vec3 fresnel = fresnel_color.rgb * reflectance;

    if (use_environment_map) {
        vec3 reflected_dir = reflect(-view_dir, normal_value);
        vec3 sky_color = texture(environment_map, reflected_dir).rgb;
        vec3 reflected_sun = sun_color.rgb
            * pow(max(dot(reflected_dir, light_dir), 0.0), 500.0);

        fresnel = sky_color * reflectance;
        fresnel += reflected_sun * reflectance;
    }

    vec3 spec_normal = normal_value;
    spec_normal.xz *= specular_normal_strength;
    spec_normal = normalize(spec_normal);

    float specular_term = pow(
        max(dot(spec_normal, halfway_dir), 0.0),
        shininess
    ) * ndotl;

    vec3 specular = light_color.rgb
        * specular_reflectance.rgb
        * specular_term;

    // Schlick Fresnel again for the specular term, matching the Unity shader.
    fresnel_base = 1.0 - max(dot(view_dir, halfway_dir), 0.0);
    fresnel_exponential = pow(fresnel_base, 5.0);
    reflectance = fresnel_exponential
        + fresnel_bias * (1.0 - fresnel_exponential);

    specular *= reflectance;

    vec3 wave_tip_color = tip_color.rgb
        * pow(max(height, 0.0), tip_attenuation);

    vec3 output_color = ambient_color.rgb
        + diffuse
        + specular
        + fresnel
        + wave_tip_color;

    ALBEDO = output_color;
}


void light() {
    if (LIGHT_IS_AREA) {
        // Area light GGX shading.
        DIFFUSE_LIGHT += LIGHT_AREA_DIFFUSE_MULTIPLIER * ATTENUATION * LIGHT_COLOR;
        SPECULAR_LIGHT += LIGHT_AREA_SPECULAR_MULTIPLIER * ATTENUATION * LIGHT_COLOR * SPECULAR_AMOUNT;
    } else {
        // Used for all other light types (directional, omni, spot).
        DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
    }
}
