shader_type spatial;
render_mode cull_disabled; // Removed unshaded to allow writing to normal/roughness buffer

uniform vec3 color : source_color = vec3(0.1, 0.5, 0.1);
uniform vec3 color_tip : source_color = vec3(0.5, 0.8, 0.2);

uniform float sway_speed = 1.0;
uniform float sway_strength = 0.1;

uniform sampler2D alpha_texture : source_color, filter_linear_mipmap, repeat_disable;

uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform float noise_scale = 1.0;
uniform float variation_strength : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	// Slight Y rotation offset per mesh
	float y_rot = (fract(sin(NODE_POSITION_WORLD.x * 43.758 + NODE_POSITION_WORLD.z * 92.567) * 43758.5453) - 0.5) * 0.7;
	float cos_y = cos(y_rot);
	float sin_y = sin(y_rot);
	VERTEX.xz = vec2(VERTEX.x * cos_y - VERTEX.z * sin_y, VERTEX.x * sin_y + VERTEX.z * cos_y);
	
	// Sample noise for randomized wind direction (separate from color noise)
	vec2 wind_uv = NODE_POSITION_WORLD.xz * 0.005 + TIME * sway_speed * 0.02;
	float wind_noise = textureLod(noise_texture, wind_uv, 0.0).r;
	
	// Pulse wind sway - base movement + pulse gusts
	float wind_wave = sin(TIME * sway_speed + wind_noise * 6.28);
	float base_sway = sin(TIME * sway_speed * 0.5 + NODE_POSITION_WORLD.x * 0.5) * 0.3;
	float pulse = pow(wind_wave * 0.5 + 0.5, 3.0);
	float sway = (base_sway + pulse) * sway_strength * UV.y;
	
	// Apply sway in X and Z based on noise for varied direction
	// Add per-mesh rotation offset based on world position
	float mesh_offset = fract(NODE_POSITION_WORLD.x * 12.9898 + NODE_POSITION_WORLD.z * 78.233) * 6.28;
	float angle = wind_noise * 6.28 + mesh_offset;
	VERTEX.x += sway * cos(angle);
	VERTEX.z += sway * sin(angle);
	
	// Sample noise texture based on world position for coherent color patches
	// We use textureLod because explicit LOD is required in vertex shaders
	float noise_val = textureLod(noise_texture, NODE_POSITION_WORLD.xz * noise_scale, 0.0).r;
	
	// Apply variation strength:
	// If strength is 0, value is 0.5 (perfect mix). If 1, full noise range.
	// Actually, let's map it so 0 means "use color", 1 means "use color_tip" or mix?
	// User said "color variation less prominent".
	// Let's assume color and color_tip are the palette.
	// We mix them based on noise.
	// We clamp/dampen the noise around 0.5.
	
	float mix_factor = mix(0.5, noise_val, variation_strength);
	
	COLOR.rgb = vec3(mix_factor);
}

void fragment() {
	vec4 tex_color = texture(alpha_texture, UV);
	
	// Get noise-based mix factor from vertex shader
	float mix_factor = COLOR.r;
	
	// Mix colors based on noise
	vec3 final_color = mix(color, color_tip, mix_factor);
	
	// Support both Alpha-channel transparency (Standard) and Grayscale Mask (Red channel)
	float alpha_val = tex_color.a;
	if (alpha_val >= 0.99) {
		// If alpha is fully opaque, assume it might be a grayscale mask on black background
		alpha_val = tex_color.r;
	}
	
	ALPHA = alpha_val;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	
	// Edge Detection Exclusion Trick:
	// The edge detection shader uses the Normal/Roughness buffer's Alpha channel (Roughness) as a mask.
	// We set ROUGHNESS to 0.0 to effectively mask this object out of the edge detection.
	// Since we removed 'unshaded' to write to the buffer, we use EMISSION to mimic the unshaded look.
	ALBEDO = vec3(0.0);
	EMISSION = final_color;
	ROUGHNESS = 0.0;
	SPECULAR = 0.0;
}
