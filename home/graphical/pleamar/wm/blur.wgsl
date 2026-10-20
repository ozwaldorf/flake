// The frosting behind the window manager's glass, Apple's CABackdropLayer:
// clamp to SDR, saturate, then a gaussian (inputRadius is sigma, in points)
// at a quarter of the size with its edges normalised, shown scaled up.
// Chain: down 0.5 repeat 2, h 1, v 1. s.a: sigma, saturation, brightness
// (added). s.b: lighten floor, darken ceiling (the tint layers' blends).

// Clamped and saturated on the straight colour, before the blur.
fn saturate(s: Blur, c: vec4<f32>) -> vec4<f32> {
    if (c.a < 0.0001) {
        return c;
    }
    let rgb = clamp(c.rgb / c.a, vec3<f32>(0.0), vec3<f32>(1.0));
    let luma = dot(rgb, vec3<f32>(0.2126, 0.7152, 0.0722));
    return vec4<f32>(clamp(mix(vec3<f32>(luma), rgb, s.a.y), vec3<f32>(0.0), vec3<f32>(1.0)) * c.a, c.a);
}

// A 2x2 box, one tap on each source pixel; the first saturates them.
fn down(s: Blur) -> vec4<f32> {
    let t = 0.5 / s.source;
    let a = prev(s, s.uv + vec2<f32>(-t.x, -t.y));
    let b = prev(s, s.uv + vec2<f32>(t.x, -t.y));
    let c = prev(s, s.uv + vec2<f32>(-t.x, t.y));
    let d = prev(s, s.uv + vec2<f32>(t.x, t.y));
    if (f32(s.step) > 0.5) {
        return (a + b + c + d) * 0.25;
    }
    return (saturate(s, a) + saturate(s, b) + saturate(s, c) + saturate(s, d)) * 0.25;
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

// The second axis, then brightness and the lighten / darken blends.
fn v(s: Blur) -> vec4<f32> {
    let c = gauss(s, vec2<f32>(0.0, 1.0));
    if (c.a < 0.0001) {
        return c;
    }
    let rgb = clamp(c.rgb / c.a + vec3<f32>(s.a.z), vec3<f32>(s.b.x), vec3<f32>(s.b.y));
    return vec4<f32>(rgb * c.a, c.a);
}
