#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer Params {
	vec2 raster_size;
	vec2 reserved;
	mat4 inv_proj_mat;
} params;

layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;

// We don't necessarily need depth/normal for simple color quantization, 
// but keeping bindings consistent with the compositor script might be easier 
// or allows for future expansion (e.g. depth based fog or normal based lighting tweaks).
layout(set = 0, binding = 2) uniform sampler2D depth_texture;
layout(set = 0, binding = 3) uniform sampler2D normal_texture;

const float COLOR_LEVELS = 8.0; // Number of color bands

void main() {
	vec2 size = params.raster_size;
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	vec4 color = imageLoad(color_image, uv);
	
	// Simple quantization
	vec3 quantized = floor(color.rgb * COLOR_LEVELS) / COLOR_LEVELS;
	
	// Optional: You could do luminance based quantization or something fancier,
	// but direct RGB quantization is the simplest "cel" look.
	
	imageStore(color_image, uv, vec4(quantized, color.a));
}
