shader_type spatial;
render_mode cull_back;

global uniform float wind_scale;
global uniform float wind_speed;
global uniform float wind_strength;
global uniform vec3 wind_direction;
global uniform sampler2D wind_noise : filter_linear_mipmap;

uniform vec4 grass_color : source_color;
uniform sampler2D grass_alpha : source_color;
uniform float grass_bend_amount = 1.0;
uniform float sway_back : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float light_steps = 3.0;

varying vec3 node_pos_view;
varying vec3 node_pos_world;

vec4 CalculateWind(vec4 uv, float speed, vec3 rotate_direction, float uv_scale, float mip_level){

	// Scrolling Wind Noise
	vec3 noise_texture = textureLod(wind_noise, (uv.xz * uv_scale) - (speed * wind_direction.xz), mip_level).rgb;
	noise_texture = noise_texture * (1. + sway_back) - sway_back;

	// Vertex Displacement
	vec4 displace = vec4((noise_texture * rotate_direction) , 0.0);
	return displace;
}

void vertex() {
	// Varyings
	node_pos_view = NODE_POSITION_VIEW;
	node_pos_world = NODE_POSITION_WORLD;

	// Wind Animation
	vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float speed = TIME * wind_speed;
	float displace_ammount = wind_strength * grass_bend_amount;
	
	// Use wind direction directly in world space (no view matrix transform)
	vec3 direction = normalize(wind_direction);

	vec4 displace = CalculateWind(world_pos, speed, direction, wind_scale, 2.0);
	float uv_mask = 1. - UV.y;
	displace *= displace_ammount * uv_mask;

	VERTEX += displace.rgb;
}

void fragment() {
	// Color Variation - sample noise based on world position for patchy grass
	float noise = texture(wind_noise, node_pos_world.xz * 0.04).r;
	noise = (noise + 2.5) / 3.5;
	noise = ceil(noise * 5.0) / 5.0;
	
	// Hue variation - sample at different scale for varied patches
	float hue_noise = texture(wind_noise, node_pos_world.xz * 0.02 + vec2(0.5, 0.3)).r;
	// Step the noise to create distinct patches (3 levels)
	hue_noise = floor(hue_noise * 3.0) / 2.0 - 0.5; // Range -0.5 to 1.0 in steps
	
	// Define blue and yellow tints
	vec3 blue_tint = vec3(0.85, 0.95, 1.1);  // Cooler, bluer green
	vec3 yellow_tint = vec3(1.15, 1.1, 0.85); // Warmer, yellower green
	
	// Mix between blue and yellow based on stepped noise
	vec3 hue_shift = mix(blue_tint, yellow_tint, hue_noise + 0.5);
	
	// Apply both brightness variation and hue shift
	vec3 varied_color = grass_color.rgb * noise * hue_shift;
	
	ALBEDO = varied_color;
	ALPHA = texture(grass_alpha, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.75;

	SPECULAR = 0.0;
	ROUGHNESS = 0.0; // roughness is being used as a mask for the outline
	LIGHT_VERTEX = node_pos_view; // shade the entire mesh based on the object position(pivot) instead of the pixel position
}

void light(){
	//Diffuse lighting
	float light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += light * (LIGHT_COLOR / PI) * ATTENUATION;
}