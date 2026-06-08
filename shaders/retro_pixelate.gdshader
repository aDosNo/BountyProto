shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec2 virtual_resolution = vec2(426.0, 240.0);
uniform float color_steps = 32.0;
uniform float scanline_strength = 0.16;
uniform float vignette_strength = 0.22;

void fragment() {
	vec2 pixel_uv = floor(SCREEN_UV * virtual_resolution) / virtual_resolution;
	pixel_uv += 0.5 / virtual_resolution;

	vec4 screen_color = texture(screen_texture, pixel_uv);
	screen_color.rgb = floor(screen_color.rgb * color_steps) / color_steps;

	float scanline = step(0.5, fract(SCREEN_UV.y * virtual_resolution.y));
	screen_color.rgb *= mix(1.0, 1.0 - scanline_strength, scanline);

	vec2 centered_uv = SCREEN_UV - vec2(0.5);
	float vignette = smoothstep(0.22, 0.76, length(centered_uv));
	screen_color.rgb *= 1.0 - (vignette * vignette_strength);

	COLOR = screen_color;
}
