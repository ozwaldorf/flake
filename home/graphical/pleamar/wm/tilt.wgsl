// Tilt-shift: sharp in an ellipse in the middle, out of focus the further out
// from it. a.x: its half height, a.w: its half width (of the box's height and
// width), a.y: how far past it the blur takes to reach full (of the height),
// a.z: the blur's radius at full, in logical pixels. b.xy: how far its centre
// is moved off the middle (of the box).
fn shade(s: Shader) -> vec4<f32> {
    let p = (s.uv - 0.5 - s.b.xy) * vec2<f32>(s.a.x / s.a.w, 1.0);
    let r = s.a.z * smoothstep(s.a.x, s.a.x + s.a.y, length(p));
    if (r < 0.5) {
        return inside(s, s.pos);
    }
    // a disc of points on a golden-angle spiral, even over its area
    let n = 48;
    var sum = vec4<f32>(0.0);
    for (var i = 0; i < n; i++) {
        let t = f32(i) * 2.39996323;
        let o = vec2<f32>(cos(t), sin(t)) * sqrt((f32(i) + 0.5) / f32(n)) * r;
        let c = inside(s, s.pos + o);
        sum += vec4<f32>(c.rgb * c.a, c.a);
    }
    if (sum.a <= 0.0) {
        return vec4<f32>(0.0);
    }
    return vec4<f32>(sum.rgb / sum.a, sum.a / f32(n));
}
