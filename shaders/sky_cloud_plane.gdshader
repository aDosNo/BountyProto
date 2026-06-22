shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 cloud_color : source_color = vec4(1.0, 0.5, 0.22, 0.14);
uniform float cloud_scale = 2.6;
uniform float cloud_threshold = 0.58;
uniform float cloud_softness = 0.24;
uniform float seed = 0.0;
uniform float warp_strength = 0.35;
uniform vec2 shape_stretch = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec2 shaped = centered * shape_stretch;
	float edge_fade = smoothstep(0.52, 0.25, length(shaped));
	vec2 seed_offset = vec2(seed * 1.37, seed * 2.11);
	vec2 warped_uv = UV + uv_offset + seed_offset;
	warped_uv.x += sin((UV.y + seed) * 8.0) * warp_strength * 0.035;
	warped_uv.y += sin((UV.x + seed * 0.7) * 5.0) * warp_strength * 0.025;
	float n = fbm(warped_uv * cloud_scale);
	float breakup = fbm((warped_uv.yx + seed_offset * 0.37) * cloud_scale * 1.7);
	n = mix(n, n * breakup, 0.32);
	float cloud = smoothstep(cloud_threshold, cloud_threshold + cloud_softness, n);
	ALBEDO = cloud_color.rgb;
	EMISSION = cloud_color.rgb * 0.25;
	ALPHA = cloud_color.a * cloud * edge_fade;
}
