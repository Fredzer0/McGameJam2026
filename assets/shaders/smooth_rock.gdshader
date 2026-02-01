shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.4, 0.4, 0.4, 1.0); // Darker grey rock
uniform vec4 variation_color : source_color = vec4(0.5, 0.5, 0.55, 1.0); // Slightly bluish grey
uniform vec4 scratch_color : source_color = vec4(0.7, 0.7, 0.7, 1.0); // Light scratches

uniform sampler2D noise_texture : filter_linear_mipmap;
uniform float noise_scale = 1.0;

uniform float scratch_scale = 1.0;
uniform float scratch_intensity : hint_range(0.0, 1.0) = 0.1;

uniform float roughness : hint_range(0.0, 1.0) = 0.4; // Somewhat smooth
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // 1. Color Noise
    vec2 noise_uv = UV * noise_scale;
    float n = texture(noise_texture, noise_uv).r;
    
    vec3 rock_color = mix(base_color.rgb, variation_color.rgb, n);
    
    // 2. Scratches
    // We simulate scratches by stretching the noise in two directions
    // to create cross-hatching or random line patterns.
    
    vec2 scratch_uv = UV * scratch_scale;
    
    // Stretch X
    vec2 uvs_1 = scratch_uv * vec2(1.0, 0.02) + vec2(0.0, n); // Add offset to randomize
    // Stretch Y
    vec2 uvs_2 = scratch_uv * vec2(0.02, 1.0) + vec2(n, 0.0);
    
    float n1 = texture(noise_texture, uvs_1).r;
    float n2 = texture(noise_texture, uvs_2).r;
    
    // Threshold to extract thin lines
    // "Peaks" in the noise become scratches
    float scratch_mask_1 = smoothstep(0.65, 0.75, n1);
    float scratch_mask_2 = smoothstep(0.65, 0.75, n2);
    
    float scratch_mask = max(scratch_mask_1, scratch_mask_2) * scratch_intensity;
    
    // Apply scratch color
    vec3 final_color = mix(rock_color, scratch_color.rgb, scratch_mask);
    
    ALBEDO = final_color;
    
    // Scratches are rougher than the smooth rock surface
    ROUGHNESS = mix(roughness, 0.9, scratch_mask);
    METALLIC = metallic;
}
