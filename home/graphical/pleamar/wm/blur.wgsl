// The frosting behind the window manager's glass: dual kawase, halving the
// picture and doubling it back with a few bilinear taps per pass, then a
// grade. s.a: how far the taps reach (half pixels, times the scale), noise,
// saturation, brightness. Passes and values are set by the scene's blur.

fn down(s: Blur) -> vec4<f32> {
    let o = 0.5 / s.size * s.a.x * max(s.scale, 1.0);
    var sum = prev(s, s.uv) * 4.0;
    sum += prev(s, s.uv - o);
    sum += prev(s, s.uv + o);
    sum += prev(s, s.uv + vec2<f32>(o.x, -o.y));
    sum += prev(s, s.uv - vec2<f32>(o.x, -o.y));
    return sum / 8.0;
}

fn up(s: Blur) -> vec4<f32> {
    let o = 0.5 / s.size * s.a.x * max(s.scale, 1.0);
    var sum = prev(s, s.uv + vec2<f32>(-o.x * 2.0, 0.0));
    sum += prev(s, s.uv + vec2<f32>(-o.x, o.y)) * 2.0;
    sum += prev(s, s.uv + vec2<f32>(0.0, o.y * 2.0));
    sum += prev(s, s.uv + vec2<f32>(o.x, o.y)) * 2.0;
    sum += prev(s, s.uv + vec2<f32>(o.x * 2.0, 0.0));
    sum += prev(s, s.uv + vec2<f32>(o.x, -o.y)) * 2.0;
    sum += prev(s, s.uv + vec2<f32>(0.0, -o.y * 2.0));
    sum += prev(s, s.uv + vec2<f32>(-o.x, -o.y)) * 2.0;
    return sum / 12.0;
}

// Saturation and brightness on the straight colour, and a little noise so
// smooth gradients do not band and the glass reads as a material.
fn grade(s: Blur) -> vec4<f32> {
    let c = prev(s, s.uv);
    if (c.a < 0.0001) {
        return c;
    }
    var rgb = c.rgb / c.a;
    let luma = dot(rgb, vec3<f32>(0.2126, 0.7152, 0.0722));
    rgb = mix(vec3<f32>(luma), rgb, s.a.z) * s.a.w;
    let n = fract(sin(dot(s.pos, vec2<f32>(12.9898, 78.233))) * 43758.5453) - 0.5;
    rgb += vec3<f32>(n * s.a.y);
    return vec4<f32>(clamp(rgb, vec3<f32>(0.0), vec3<f32>(1.0)) * c.a, c.a);
}
