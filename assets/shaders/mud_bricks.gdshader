shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.5, 0.35, 0.2, 1.0);
uniform vec4 variation_color : source_color = vec4(0.6, 0.4, 0.25, 1.0);
uniform vec4 seam_color_a : source_color = vec4(0.1, 0.3, 0.1, 1.0); // Green
uniform vec4 seam_color_b : source_color = vec4(0.2, 0.15, 0.1, 1.0); // Dark Brown

uniform sampler2D noise_texture : filter_linear_mipmap;
uniform float noise_scale = 1.0;

uniform float offset_jitter : hint_range(0.0, 1.0) = 0.5;
uniform vec2 brick_scale = vec2(100.0, 100.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float height_scale : hint_range(0.0, 2.0) = 0.0002;

uniform float rotation_jitter : hint_range(0.0, 1.0) = 0.1; // Max rotation in radians approx
uniform float gap_width : hint_range(0.0, 0.2) = 0.05;


varying vec2 tex_position;
varying vec2 brick_id;
varying float brick_height_var;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy,
        vec2(12.9898,78.233))) * 43758.5453123);
}

void vertex() {
	vec2 uv = UV * brick_scale;
	vec2 b_id = floor(uv);
	
	// Random height per brick
	float h = random(b_id);
	
	// Pass to fragment
	brick_height_var = h;
	
	// Displacement
	VERTEX += NORMAL * h * height_scale;
}

vec2 rotate(vec2 uv, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
}

void fragment() {
	vec2 uv = UV * brick_scale;
	vec2 brick_id_global = floor(uv);
	
	// Center UVs for rotation usually -0.5 to 0.5
	vec2 uv_centered = fract(uv) - 0.5;
	
	// Random per brick
	float r = random(brick_id_global);
	
	// Rotation
	float rot_angle = (r * 2.0 - 1.0) * rotation_jitter;
	vec2 uv_rotated = rotate(uv_centered, rot_angle);
	vec2 brick_uv = uv_rotated + 0.5;
	
	// Gap/Seam Logic (replaces "mortar" but with noisy edges or just just gap)
	// We want square bricks with a gap.
	// Step creates sharp edges. 
	vec2 gap_step = step(vec2(gap_width), brick_uv) * step(brick_uv, vec2(1.0 - gap_width));
	float is_brick = gap_step.x * gap_step.y;
	
	// Sample noise for texture WITHIN the brick AND for seams
	vec2 noise_uv = uv / noise_scale; 
	float noise_val = texture(noise_texture, noise_uv).r;
	
	// --- BRICK COLOR ---
	
	// Determine mix factor between the two brown colors based on random value
	vec3 base_mix = mix(base_color.rgb, variation_color.rgb, r);
	
	// Add random brightness variation (Value)
	float brightness_rand = random(brick_id_global + vec2(12.34, 56.78));
	float brightness = 0.8 + 0.4 * brightness_rand; 
	
	vec3 brick_base = base_mix * brightness;
	
	// Apply internal noise as modulation (muddy look)
	brick_base *= (0.8 + 0.4 * noise_val);
	
	// --- SEAM COLOR ---
	// "alternating between green and dark brown" using perlin noise
	// We use the same noise_val sampled globally for continuity in the seams
	float seam_mix = smoothstep(0.3, 0.7, noise_val);
	vec3 seam_color = mix(seam_color_b.rgb, seam_color_a.rgb, seam_mix);
	
	ALBEDO = mix(seam_color, brick_base, is_brick);
	
	ROUGHNESS = roughness;
}	

