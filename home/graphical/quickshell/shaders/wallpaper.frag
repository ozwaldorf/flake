#version 440

// Wallpaper compositor: crossfades between two images and grades the result
// through a Hald CLUT, both in the one pass.
//
// The grade is done here rather than baked into the files on disk so the
// palette can be changed by regenerating one small CLUT rather than
// reprocessing every wallpaper, and so the originals stay untouched.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // 0 shows `from` alone, 1 shows `to` alone
    float progress;
    // Hald level: the cube holds level*level colors per channel and the image
    // is level^3 square. Passed in rather than derived from the texture size,
    // which the shader cannot query.
    float level;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;
layout(binding = 3) uniform sampler2D clut;

// A Hald CLUT is a continuous buffer indexed i = r + g*N + b*N*N, laid out row
// major into a square. Sampled at texel centres with nearest filtering, since
// the interpolation between entries is done below rather than by the sampler:
// bilinear here would blend across entries that are not neighbours in the cube
// wherever a row wraps.
vec3 clutFetch(vec3 idx, float n, float edge) {
    float i = idx.r + idx.g * n + idx.b * n * n;
    float y = floor(i / edge);
    return texture(clut, (vec2(i - y * edge, y) + 0.5) / edge).rgb;
}

// Trilinear across the eight surrounding entries. Without it the grade posterises
// into visible blocks wherever the source runs through a smooth gradient.
vec3 graded(vec3 c) {
    float n = level * level;
    float edge = n * level;

    vec3 scaled = clamp(c, 0.0, 1.0) * (n - 1.0);
    vec3 lo = floor(scaled);
    vec3 hi = min(lo + 1.0, n - 1.0);
    vec3 f = scaled - lo;

    vec3 c000 = clutFetch(vec3(lo.r, lo.g, lo.b), n, edge);
    vec3 c100 = clutFetch(vec3(hi.r, lo.g, lo.b), n, edge);
    vec3 c010 = clutFetch(vec3(lo.r, hi.g, lo.b), n, edge);
    vec3 c110 = clutFetch(vec3(hi.r, hi.g, lo.b), n, edge);
    vec3 c001 = clutFetch(vec3(lo.r, lo.g, hi.b), n, edge);
    vec3 c101 = clutFetch(vec3(hi.r, lo.g, hi.b), n, edge);
    vec3 c011 = clutFetch(vec3(lo.r, hi.g, hi.b), n, edge);
    vec3 c111 = clutFetch(vec3(hi.r, hi.g, hi.b), n, edge);

    return mix(mix(mix(c000, c100, f.r), mix(c010, c110, f.r), f.g),
               mix(mix(c001, c101, f.r), mix(c011, c111, f.r), f.g), f.b);
}

void main() {
    // Blended before grading, not after: grading each source and then mixing
    // walks the straight line between two graded colors, which leaves the
    // midpoint of the fade off the palette. Grading the blend keeps every
    // frame of the transition on it.
    vec3 blended = mix(texture(fromTex, qt_TexCoord0).rgb,
                       texture(toTex, qt_TexCoord0).rgb,
                       progress);

    fragColor = vec4(graded(blended), 1.0) * qt_Opacity;
}
