shader_type spatial;

// Draws tile lines on the ground from world position, so the lines always
// match the logical grid regardless of the mesh's size or UVs.

uniform vec3 ground_color : source_color = vec3(0.36, 0.33, 0.28);
uniform vec3 line_color : source_color = vec3(0.15, 0.13, 0.11);
uniform float tile_size = 2.0;
// Half line width, as a fraction of one tile.
uniform float line_half_width = 0.03;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_pos.xz / tile_size;
	// Distance to the nearest tile boundary, in tiles.
	vec2 dist = abs(fract(coord - 0.5) - 0.5);
	vec2 aa = max(fwidth(coord), vec2(0.0001));
	vec2 lines = 1.0 - smoothstep(vec2(line_half_width), vec2(line_half_width) + aa, dist);
	float line = max(lines.x, lines.y);
	// Fade lines out when tiles get smaller than a couple of pixels (avoids shimmer).
	line *= 1.0 - clamp(max(aa.x, aa.y) * 2.0, 0.0, 1.0);

	ALBEDO = mix(ground_color, line_color, line);
	ROUGHNESS = 1.0;
}
