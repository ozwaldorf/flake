// The frosting behind the window manager's glass, Apple's CABackdropLayer:
// clamp to SDR, then a gaussian (inputRadius is sigma, in points) at a
// quarter of the size with its edges normalised, back at full size with
// grain. Saturation and tone are the glass's own (`vivid:`, `smoke:`,
// `milk:`). Chain: down 0.5 repeat 2, h 1, v 1, grain 4. s.a: sigma, grain.

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
// One axis of the gaussian, two texels a tap through the bilinear filter.
// Taps past the picture are left out and the weights renormalised, so the
// edge neither darkens nor smears. 24 pairs cover 48 texels: past 3 sigma
// at 30pt up to a scale of 2.
fn gauss(s: Blur, axis: vec2<f32>) -> vec4<f32> {
    let sigma = max(s.a.x * s.scale / 4.0, 0.5);
    let k = -0.5 / (sigma * sigma);
    let t = axis / s.source;
    var sum = prev(s, s.uv);
    var total = 1.0;
    for (var i = 0; i < 24; i++) {
        let o1 = f32(2 * i + 1);
        let o2 = o1 + 1.0;
        let w1 = exp(k * o1 * o1);
        let w2 = exp(k * o2 * o2);
        let w = w1 + w2;
        let o = (o1 * w1 + o2 * w2) / w;
        let p = s.uv + t * o;
        let n = s.uv - t * o;
        let wp = w * f32(all(p >= vec2<f32>(0.0)) && all(p <= vec2<f32>(1.0)));
        let wn = w * f32(all(n >= vec2<f32>(0.0)) && all(n <= vec2<f32>(1.0)));
        sum += prev(s, p) * wp + prev(s, n) * wn;
        total += wp + wn;
    }
    return sum / total;
}

fn h(s: Blur) -> vec4<f32> {
    return gauss(s, vec2<f32>(1.0, 0.0));
}

fn v(s: Blur) -> vec4<f32> {
    return gauss(s, vec2<f32>(0.0, 1.0));
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
