shader_type spatial;

// The ground: procedural grass with patches of dry grass and bare earth,
// plus faint tile lines. Everything is drawn from world position, so the
// lines always match the logical grid regardless of the mesh's size or UVs,
// and no texture files are needed.

uniform vec3 grass_color : source_color = vec3(0.29, 0.36, 0.19);
uniform vec3 dry_grass_color : source_color = vec3(0.45, 0.42, 0.25);
uniform vec3 dirt_color : source_color = vec3(0.37, 0.30, 0.22);
uniform vec3 line_color : source_color = vec3(0.12, 0.11, 0.08);
uniform vec3 snow_color : source_color = vec3(0.9, 0.92, 0.95);
uniform vec3 water_color : source_color = vec3(0.2, 0.38, 0.5);
uniform vec3 rock_color : source_color = vec3(0.47, 0.45, 0.43);
uniform vec3 seam_color : source_color = vec3(0.13, 0.12, 0.13);
uniform vec3 fertile_color : source_color = vec3(0.25, 0.3, 0.13);
// The terrain of the map, one pixel per tile: red = water, green = rock,
// blue = coal seam, alpha = fertile soil. Only used where terrain_amount
// is above zero, which is the map itself and not the hills around it.
uniform sampler2D terrain_map : filter_linear, repeat_disable;
uniform float terrain_amount : hint_range(0.0, 1.0) = 0.0;
// World size of the area the terrain map covers, from the origin.
uniform float terrain_size = 128.0;
// How much of the ground lies under snow, from 0 (none) to 1 (all of it).
// In between, the snow lies in patches.
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
// How strongly the tile lines show, from 0 (hidden) to 1 (solid).
uniform float line_strength : hint_range(0.0, 1.0) = 0.35;
uniform float tile_size = 2.0;
// Half line width, as a fraction of one tile.
uniform float line_half_width = 0.03;
// Size of the large grass / earth patches, in world units.
uniform float patch_size = 22.0;
// Share of the ground that is bare earth, from 0 to 1.
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, 0 to 1.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Four layers of noise, 0 to 1.
float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amplitude * noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amplitude *= 0.5;
	}
	return total / 0.9375;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 pos = world_pos.xz;
	vec2 coord = pos / tile_size;
	vec2 aa = max(fwidth(coord), vec2(0.0001));
	// 1 up close, 0 when a tile is only a few pixels wide. Fine detail and
	// lines fade out with it, which avoids shimmer when zoomed out.
	float closeness = 1.0 - clamp(max(aa.x, aa.y) * 2.0, 0.0, 1.0);

	// Large patches: lush grass, dry grass, bare earth.
	float dryness = fbm(pos / patch_size);
	float earth = fbm(pos / (patch_size * 0.6) + vec2(40.0, 71.0));
	vec3 color = mix(grass_color, dry_grass_color, smoothstep(0.35, 0.7, dryness));
	color = mix(color, dirt_color, smoothstep(1.0 - dirt_amount, 1.05 - dirt_amount * 0.5, earth));

	// Mottling about a tile across, then fine grain like blades and grit.
	float mottle = noise(pos * 0.9);
	float grain = noise(pos * 9.0);
	color *= 0.88 + 0.24 * mottle;
	color *= 1.0 + (grain - 0.5) * 0.3 * closeness;

	// Terrain: fertile soil, rock and coal seams tint the ground; the river
	// is drawn last, over the snow.
	vec2 terrain_uv = pos / terrain_size;
	float on_map = terrain_amount * step(0.0, terrain_uv.x) * step(terrain_uv.x, 1.0)
			* step(0.0, terrain_uv.y) * step(terrain_uv.y, 1.0);
	vec4 terrain = texture(terrain_map, terrain_uv) * on_map;
	color = mix(color, fertile_color * (0.85 + 0.3 * mottle), terrain.a * 0.8);
	color = mix(color, rock_color * (0.75 + 0.5 * noise(pos * 1.7)), terrain.g);
	color = mix(color, seam_color * (0.6 + 0.9 * noise(pos * 3.1)), terrain.b * 0.85);

	// Snow, settling in patches first and thinning the same way.
	float cover = clamp(snow_amount * 1.3 - (1.0 - snow_amount) * fbm(pos / 8.0) * 1.4, 0.0, 1.0);
	color = mix(color, snow_color * (0.93 + 0.07 * mottle), cover);

	// The river: moving glints in summer, pale ice under winter's snow.
	float glint = 0.5 + 0.5 * sin(TIME * 1.3 + pos.x * 0.9 + pos.y * 0.7 + 4.0 * noise(pos * 0.6));
	vec3 river = mix(water_color * (0.85 + 0.25 * glint), vec3(0.78, 0.85, 0.9), snow_amount * 0.8);
	color = mix(color, river, terrain.r);

	// Distance to the nearest tile boundary, in tiles.
	vec2 dist = abs(fract(coord - 0.5) - 0.5);
	vec2 lines = 1.0 - smoothstep(vec2(line_half_width), vec2(line_half_width) + aa, dist);
	float line = max(lines.x, lines.y) * closeness * line_strength;

	ALBEDO = mix(color, line_color, line);
	ROUGHNESS = mix(1.0, 0.25, terrain.r);
}
