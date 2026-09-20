shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// Showcase twin of teleport_shred.gdshader, for standalone tutorial scenes.
// It reads the quad's own UV instead of SCREEN_UV: the real shader paints a
// capture back onto a camera-facing quad so the character lands exactly where
// he already was on screen, which is meaningless standalone. source_scale is
// the other showcase-only control; it frames a loose texture inside the quad
// the way a live capture frames a character inside the viewport. The shred
// math stays identical, so a look authored here is reproduced by copying its
// frame numbers.
uniform sampler2D src_tex : source_color, filter_linear, repeat_disable;

// The character's centre of mass in quad UV, and the direction he is
// travelling in, aspect-corrected and normalised. Rows stack across scan_dir
// and stretch along it.
uniform vec2 centroid = vec2(0.5);
// Where that centre of mass was in the capture at the moment src_tex was
// taken. Equal to centroid for a live capture; they only come apart for a
// frozen one.
uniform vec2 src_centroid = vec2(0.5);
uniform vec2 scan_dir = vec2(1.0, 0.0);
// Half the character's height in the aspect-corrected frame, so the
// concentration weighting means the same thing however tight the camera is.
uniform float half_extent = 0.15;
uniform float row_count = 64.0;
// Re-roll this to redraw the stagger, which is what every held step of the
// real effect does.
uniform float step_seed = 0.0;
// The quad's width / height, standing in for VIEWPORT_SIZE's aspect
// correction: the working frame below is the quad, and this is what keeps
// the rows square and the stretch lengths meaningful.
uniform float frame_aspect = 1.7777778;
// Standalone textures often fill their image. Scale them around src_centroid
// to leave the same surrounding frame a live character capture would have.
uniform float source_scale : hint_range(0.05, 1.0, 0.05) = 1.0;

uniform float density = 1.0;
uniform float stretch = 0.0;
uniform float stagger = 0.0;
uniform float line_width = 1.0;
uniform float concentration = 0.0;
uniform float anchor = 0.0;
uniform float alpha_gain = 1.0;

// Per-row randomness. Cheap and stable: the same row and the same step always
// produce the same value, so a row does not flicker within its own drawing.
float row_random(float row, float salt) {
	return fract(sin(row * 78.233 + step_seed * 12.9898 + salt * 39.425) * 43758.5453123);
}

void fragment() {
	vec2 aspect = vec2(frame_aspect, 1.0);
	vec2 perp = vec2(-scan_dir.y, scan_dir.x);
	vec2 q = (UV - centroid) * aspect;
	float s = dot(q, scan_dir);
	float t = dot(q, perp);
	// The grid tiles the character's extent, not the quad: row_count is rows
	// across the figure.
	float rows = max(row_count / max(half_extent * 2.0, 1e-4), 4.0);
	float row = floor(t * rows);

	// Whole rows die, weighted toward the edges so the survivors collapse onto
	// the centre of mass as concentration rises.
	float t_norm = clamp(abs(t) / max(half_extent, 1e-4), 0.0, 1.0);
	float keep_prob = density * mix(1.0, 1.0 - t_norm, concentration);
	if (row_random(row, 0.0) > keep_prob) {
		discard;
	}

	// Surviving rows draw only part of their band. This is what reads as
	// sparse; killing rows alone just reads as dim.
	if (fract(t * rows) > line_width) {
		discard;
	}

	// Sampling a compressed source produces elongated output. anchor moves the
	// pivot so the smear can trail behind instead of growing both ways.
	float k = 1.0 + stretch * (0.5 + row_random(row, 1.0));
	float s2 = (s - anchor) / k + anchor + (row_random(row, 2.0) - 0.5) * stagger;

	// t passes through untouched: rows stretch and vanish, they never drift
	// across each other.
	vec2 uv2 = src_centroid + (s2 * scan_dir + t * perp) / aspect;
	vec2 sample_uv = src_centroid + (uv2 - src_centroid) / max(source_scale, 1e-4);
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0
			|| sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		discard;
	}

	vec4 src = texture(src_tex, sample_uv);
	if (src.a <= 0.001) {
		discard;
	}
	ALBEDO = src.rgb;
	// Fading in proportion to the stretch is what keeps a long row reading as
	// a smear rather than a solid ribbon.
	ALPHA = src.a * alpha_gain / k;
}
