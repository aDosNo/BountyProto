shader_type spatial;
// High-atmosphere cloud band for the Hesperus skyline backdrop.
// Soft volumetric *look* without volumetrics: FBM value-noise drives both the
// color and the alpha, the alpha falls to zero toward the quad edges so the
// rectangular silhouette dissolves, and the noise scrolls over time so the
// cloud roils. Unshaded + transparent + no depth-write so it reads as vapor,
// not geometry. Cheap: a couple of big quads, no marching.

render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Tint of the cloud body and its faint glow, set from the scene fog by the
// driver script so the deck matches the atmosphere.
uniform vec3 cloud_color : source_color = vec3(0.62, 0.55, 0.70);
uniform vec3 cloud_shadow : source_color = vec3(0.12, 0.10, 0.18);
// Overall opacity ceiling and how hard the noise threshold bites (wispiness).
uniform float density : hint_range(0.0, 2.0) = 0.9;
uniform float coverage : hint_range(0.0, 1.0) = 0.5;   // higher = more sky filled
uniform float softness : hint_range(0.01, 1.0) = 0.45; // edge of the alpha ramp
// Feature scale and drift.
uniform float noise_scale : hint_range(0.5, 12.0) = 3.0;
uniform vec2 scroll_speed = vec2(0.012, 0.005);
uniform float roil_speed : hint_range(0.0, 1.0) = 0.04; // internal evolution
// How aggressively alpha fades toward the UV borders (kills the square edge).
uniform float edge_fade : hint_range(0.5, 6.0) = 2.2;

// --- value noise + fbm -------------------------------------------------------
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
	float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 5; i++) {
		v += amp * vnoise(p * freq);
		freq *= 2.02;
		amp *= 0.5;
	}
	return v * 0.5 + 0.5; // -> 0..1
}

void fragment() {
	vec2 uv = UV;

	// Scroll + slowly evolve the noise field so the cloud drifts and roils.
	vec2 p = uv * noise_scale + scroll_speed * TIME;
	// domain-warp a touch for a more billowy, less grid-aligned look
	vec2 warp = vec2(fbm(p + vec2(0.0, TIME * roil_speed)),
					 fbm(p + vec2(5.2, 1.3 - TIME * roil_speed)));
	float n = fbm(p + warp * 1.5);

	// Coverage threshold: remap noise so only the denser lumps are opaque,
	// leaving wispy gaps — this is what makes it read as cloud not a sheet.
	float a = smoothstep(coverage, coverage + softness, n);

	// Radial-ish edge fade toward UV borders so the quad outline dissolves.
	vec2 d = abs(uv - 0.5) * 2.0;          // 0 center -> 1 edge
	float edge = 1.0 - max(d.x, d.y);
	edge = clamp(edge, 0.0, 1.0);
	edge = pow(edge, edge_fade);

	float alpha = a * edge * density;

	// Shade: darker in the dense cores, lighter at the thin fringes, for volume.
	float shade = smoothstep(0.2, 0.9, n);
	vec3 col = mix(cloud_color, cloud_shadow, shade * 0.6);
	// lift the thin edges slightly (backlit vapor)
	col += cloud_color * (1.0 - a) * 0.15;

	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
