// The frosting behind the window manager's glass, a lens blur: clamp to SDR,
// then a disc (radius in points) at a quarter of the size with its edges
// normalised, bright texels weighted up so highlights open into discs,
// softened, back at full size with grain. Saturation and tone are the
// glass's own (`vivid:`, `smoke:`, `milk:`). Chain: down 0.5 repeat 2,
// disc 1, soft 1, grain 4. s.a: radius, grain, highlight boost.

// Clamped to SDR on the straight colour, before the blur.
fn sdr(c: vec4<f32>) -> vec4<f32> {
    if (c.a < 0.0001) {
        return c;
    }
    return vec4<f32>(clamp(c.rgb / c.a, vec3<f32>(0.0), vec3<f32>(1.0)) * c.a, c.a);
}

// A 2x2 box, one tap on each source pixel; the first clamps them.
fn down(s: Blur) -> vec4<f32> {
    let t = 0.5 / s.source;
    let a = prev(s, s.uv + vec2<f32>(-t.x, -t.y));
    let b = prev(s, s.uv + vec2<f32>(t.x, -t.y));
    let c = prev(s, s.uv + vec2<f32>(-t.x, t.y));
    let d = prev(s, s.uv + vec2<f32>(t.x, t.y));
    if (f32(s.step) > 0.5) {
        return (a + b + c + d) * 0.25;
    }
    return (sdr(a) + sdr(b) + sdr(c) + sdr(d)) * 0.25;
}

// A flat disc, 160 taps on a golden-angle (Vogel) spiral, so they cover it
// evenly with no rings. Each tap is weighted by 1 + boost * luma^4, which
// stands in for the HDR an SDR backdrop lacks: lit points dominate their
// disc instead of averaging away. Taps past the picture are left out and the
// weights renormalised, so the edge neither darkens nor smears.
fn disc(s: Blur) -> vec4<f32> {
    let radius = max(s.a.x * s.scale / 4.0, 0.5);
    var sum = vec4<f32>(0.0);
    var total = 0.0;
    for (var i = 0; i < 160; i++) {
        let f = f32(i);
        let r = sqrt((f + 0.5) / 160.0) * radius;
        let th = f * 2.39996323;
        let p = s.uv + vec2<f32>(cos(th), sin(th)) * r / s.source;
        let inside = f32(all(p >= vec2<f32>(0.0)) && all(p <= vec2<f32>(1.0)));
        let c = prev(s, p);
        let l = dot(c.rgb / max(c.a, 0.0001), vec3<f32>(0.2126, 0.7152, 0.0722));
        let w = inside * (1.0 + s.a.z * l * l * l * l);
        sum += c * w;
        total += w;
    }
    return sum / max(total, 0.0001);
}

// A 3x3 tent through the bilinear filter, smoothing what the spiral's gaps
// leave between taps.
fn soft(s: Blur) -> vec4<f32> {
    let t = 0.5 / s.source;
    let a = prev(s, s.uv + vec2<f32>(-t.x, -t.y));
    let b = prev(s, s.uv + vec2<f32>(t.x, -t.y));
    let c = prev(s, s.uv + vec2<f32>(-t.x, t.y));
    let d = prev(s, s.uv + vec2<f32>(t.x, t.y));
    return (a + b + c + d) * 0.25;
}

// PCG2D (Jarzynski and Olano): integer hashing without the patterns a sin
// hash shows at large coordinates.
fn pcg2d(p: vec2<u32>) -> vec2<u32> {
    var v = p * 1664525u + 1013904223u;
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> vec2<u32>(16u));
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> vec2<u32>(16u));
    return v;
}

// Back at full size, grain on each real pixel: blown up from the quarter
// size it would be blotches. Triangular (two uniforms summed), the shape
// that hides banding without lifting the noise floor; s.a.y is its peak.
fn grain(s: Blur) -> vec4<f32> {
    let c = prev(s, s.uv);
    if (c.a < 0.0001) {
        return c;
    }
    let u = vec2<f32>(pcg2d(vec2<u32>(s.pos)) >> vec2<u32>(8u)) / 16777216.0;
    let n = (u.x + u.y - 1.0) * s.a.y;
    return vec4<f32>(clamp(c.rgb / c.a + vec3<f32>(n), vec3<f32>(0.0), vec3<f32>(1.0)) * c.a, c.a);
}
