// Inspired/Using snippets of code for shaders from Eduardo Schildt
shader_type spatial;
render_mode specular_disabled, cull_back;


global uniform float wind_scale;
global uniform float wind_speed;
global uniform float wind_strength;
global uniform vec3 wind_direction;
global uniform sampler2D wind_noise : filter_linear_mipmap;

uniform vec4 color: source_color;
uniform sampler2D alpha;
uniform float leaves_scale = 1.0;
uniform float leaf_bend_amount = 0.7;
uniform float light_steps = 5.0;
uniform float animation_distance = 20.0;

varying vec4 view_pos;
varying vec4 world_pos;
varying float color_variation;

float random(vec2 uv) {
	return fract(sin(dot(uv.xy,
		vec2(12.9898,78.233))) * 43758.5453123);
}

void vertex() {
	world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float speed = TIME * wind_speed;
	
	// Distance fading logic
	float dist = length(view_pos);
	float animation_fade = 0.0;
	
	if (animation_distance > 0.1) {
		animation_fade = 1.0 - smoothstep(animation_distance * 0.8, animation_distance, dist);
	}

	// Noise for animation
	float noise_texture = textureLod(wind_noise, (world_pos.xz * wind_scale) - (speed * wind_direction.xz), 1.0).r;
	noise_texture = (noise_texture * 2. - 1.) * (wind_strength * leaf_bend_amount * animation_fade);

	//Leaves Billboard
	vec4 new_position = vec4(UV.y, UV.x, 0.0, 1.0);
	new_position = new_position *2. - 1.;
	new_position = normalize(new_position);
	new_position *= leaves_scale;

	// Leaves animation
	// Apply fade to the offset as well just in case, though fading noise_texture is enough.
	new_position += noise_texture * vec4(1.0, 0.0, 0.0, 0.0) * (UV.x * 2.0 - 1.0) - noise_texture * vec4(0.0, 1.0, 0.0, 0.0) * (UV.y * 2.0 - 1.0);

	new_position *= MODELVIEW_MATRIX;

	// Color Variation (per-leaf using VERTEX as seed)
	float rand_val = random(VERTEX.xz);
	color_variation = 0.7 + rand_val * 0.6;

	VERTEX += new_position.xyz;
}

void fragment() {
	ALBEDO = color.rgb * color_variation;
	ALPHA = texture(alpha, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.0;
	SPECULAR = 0.0;
	LIGHT_VERTEX = view_pos.xyz;
}

void light() {
	// Cel shaded diffuse lighting
	float light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	light = ceil(light * light_steps) / light_steps;
	DIFFUSE_LIGHT += light * (LIGHT_COLOR / PI) * ATTENUATION;

	// Rim Lighting
	float rim = 1.0 - dot(NORMAL, VIEW);
	rim *= light;
	rim = round(rim * light_steps) / light_steps;
	rim = rim * rim;
	DIFFUSE_LIGHT += rim * ATTENUATION * LIGHT_COLOR / PI;
	
}
