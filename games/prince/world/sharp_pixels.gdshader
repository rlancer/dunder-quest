shader_type canvas_item;

// Sharp pixels for art drawn smaller than its texture: the Prince, the
// Vizier, the door and the tiles are painted at two texels to a room pixel.
// Each texel stays a crisp square and only the seam between two texels is
// blended, across one screen pixel, so at a window scale where a texel is
// 1.5 screen pixels they don't come out as uneven one- and two-pixel
// stripes. At 4x (1080p) it is exactly nearest. It filters by hand with
// texelFetch, so the node keeps nearest filtering and its children aren't
// softened. Art at one texel to a room pixel (the backdrops) comes out as
// plain nearest at any whole-number scale.

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	vec2 at = UV * vec2(size) - 0.5;
	vec2 base = floor(at);
	vec2 across = max(fwidth(at), vec2(1e-4));
	vec2 blend = clamp((at - base - 0.5) / across + 0.5, 0.0, 1.0);
	ivec2 top = size - 1;
	ivec2 a = clamp(ivec2(base), ivec2(0), top);
	ivec2 b = clamp(ivec2(base) + 1, ivec2(0), top);
	vec4 row0 = mix(texelFetch(TEXTURE, a, 0), texelFetch(TEXTURE, ivec2(b.x, a.y), 0), blend.x);
	vec4 row1 = mix(texelFetch(TEXTURE, ivec2(a.x, b.y), 0), texelFetch(TEXTURE, b, 0), blend.x);
	COLOR = mix(row0, row1, blend.y) * tint;
}
