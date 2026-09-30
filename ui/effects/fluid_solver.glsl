#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 0, rgba16f) uniform readonly image2D state_in;
layout(set = 0, binding = 1, rgba16f) uniform writeonly image2D state_out;
layout(set = 0, binding = 2, r32f) uniform readonly image2D pressure_in;
layout(set = 0, binding = 3, r32f) uniform writeonly image2D pressure_out;
layout(set = 0, binding = 4, rgba16f) uniform image2D geometry;
layout(set = 0, binding = 5, std430) readonly buffer Influences { vec4 items[]; };
layout(set = 0, binding = 6) uniform sampler2D domain_mask;
// Density-weighted linear RGB and density-weighted age, advected with state.
layout(set = 0, binding = 7, rgba16f) uniform readonly image2D matter_in;
layout(set = 0, binding = 8, rgba16f) uniform writeonly image2D matter_out;
// Fog has its own resolution: density, signed heat (remaining channels reserved).
layout(set = 0, binding = 9, rg16f) uniform readonly image2D dye_in;
layout(set = 0, binding = 10, rg16f) uniform writeonly image2D dye_out;
layout(push_constant, std430) uniform Params {
    vec4 domain; // local width, height, dt, mode
    vec4 environment; // wind x/y, buoyancy, confinement
    vec4 decay; // velocity, density, heat, clock
    vec4 counts; // source count, obstacle count, mask enabled, turbulence
    vec4 material; // settling, eddy scale, reserved, eddy acceleration
    vec4 detail; // small-scale turbulence strength
} p;

ivec2 bounded(ivec2 q) { return clamp(q, ivec2(0), imageSize(state_in) - 1); }
vec4 state(ivec2 q) { return imageLoad(state_in, bounded(q)); }
vec4 boundary(ivec2 q) {
    if (any(lessThan(q, ivec2(0))) || any(greaterThanEqual(q, imageSize(state_in))))
        return vec4(0, 0, 1, 0);
    return imageLoad(geometry, q);
}
vec2 velocity(ivec2 q) { vec4 b = boundary(q); return b.z > 0.5 ? b.xy : state(q).xy; }
float curl(ivec2 q, vec2 h) {
    return (velocity(q + ivec2(1, 0)).y - velocity(q - ivec2(1, 0)).y) / (2.0 * h.x)
         - (velocity(q + ivec2(0, 1)).x - velocity(q - ivec2(0, 1)).x) / (2.0 * h.y);
}
vec4 sample_state(vec2 q) {
    q = clamp(q, vec2(0), vec2(imageSize(state_in) - 1));
    ivec2 a = ivec2(floor(q)); vec2 f = fract(q);
    return mix(mix(state(a), state(a + ivec2(1, 0)), f.x),
               mix(state(a + ivec2(0, 1)), state(a + ivec2(1, 1)), f.x), f.y);
}
vec4 sample_matter(vec2 q) {
    q = clamp(q, vec2(0), vec2(imageSize(matter_in) - 1));
    ivec2 a = ivec2(floor(q)); vec2 f = fract(q);
    ivec2 b = min(a + 1, imageSize(matter_in) - 1);
    return mix(mix(imageLoad(matter_in, a), imageLoad(matter_in, ivec2(b.x, a.y)), f.x),
               mix(imageLoad(matter_in, ivec2(a.x, b.y)), imageLoad(matter_in, b), f.x), f.y);
}
vec2 sample_dye(vec2 q) {
    q = clamp(q, vec2(0), vec2(imageSize(dye_in) - 1));
    ivec2 a = ivec2(floor(q)); vec2 f = fract(q);
    ivec2 b = min(a + 1, imageSize(dye_in) - 1);
    return mix(mix(imageLoad(dye_in, a).rg, imageLoad(dye_in, ivec2(b.x, a.y)).rg, f.x),
               mix(imageLoad(dye_in, ivec2(a.x, b.y)).rg, imageLoad(dye_in, b).rg, f.x), f.y);
}
float distance_shape(vec2 at, int index) {
    vec4 a = items[index * 6]; vec4 c = items[index * 6 + 2];
    vec2 d = at - a.xy;
    d = mat2(cos(c.x), -sin(c.x), sin(c.x), cos(c.x)) * d;
    vec2 e = max(a.zw, vec2(0.001));
    if (c.z < 0.5) return (length(d / e) - 1.0) * min(e.x, e.y);
    if (c.z < 1.5) {
        vec2 q = abs(d) - e;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    }
    d.x -= clamp(d.x, -max(e.x - e.y, 0.0), max(e.x - e.y, 0.0));
    return length(d) - e.y;
}
float neighbor_pressure(ivec2 q, float center) {
    return boundary(q).z > 0.5 ? center : imageLoad(pressure_in, bounded(q)).r;
}
vec2 body_flow(vec2 at, int index, vec2 current, vec2 cell) {
    vec4 a = items[index * 6]; vec4 v = items[index * 6 + 1];
    vec4 c = items[index * 6 + 2]; vec4 body = items[index * 6 + 5];
    vec2 offset = at - a.xy;
    vec2 direction = vec2(cos(c.x), sin(c.x));
    vec2 nearest = offset - direction * clamp(dot(offset, direction), -body.y * 0.5, body.y * 0.5);
    float reach = max(a.z - body.y * 0.5, a.w);
    float q = length(nearest) / reach;
    vec2 metric_gradient = nearest / (reach * reach);
    if (body.z > 0.0) {
        // Rounded diamond streamlines: gradual entry and release along the
        // movement axis, instead of stretching a circular velocity stamp.
        vec2 side = vec2(-direction.y, direction.x);
        vec2 local = vec2(dot(nearest, direction) / body.z, dot(nearest, side)) / reach;
        vec2 rounded = sqrt(local * local + vec2(0.0064));
        q = rounded.x + rounded.y - 0.16;
        vec2 derivative = local / rounded;
        metric_gradient = q * (direction * derivative.x / body.z + side * derivative.y) / reach;
    }
    if (q >= 1.0) return vec2(0);
    float t = max(1.0 - q, 0.0);
    float envelope = t * t * t * t * (1.0 + 4.0 * q);
    vec2 gradient = -20.0 * t * t * t * metric_gradient;
    vec2 carrier = state(ivec2(a.xy / cell)).xy;
    vec2 relative = v.xy - carrier;
    // A projected object occupies only part of the air column. Fast, small
    // objects let most air pass around/over them instead of launching the whole
    // column at projectile speed. Bound displaced distance by body size, not grid.
    // A long swept footprint spreads the same contact over a longer path;
    // compensate its exposure weighting so rapid input still moves each patch.
    float slip_speed = max(max(body.x * 8.0, body.w), length(v.xy) * p.domain.z * 4.0);
    relative *= inversesqrt(1.0 + dot(relative, relative) / (slip_speed * slip_speed));
    // Curl of psi = cross(relative, offset) * envelope. Fade the streamfunction,
    // not its velocity: front displacement and rear refill stay divergence-free
    // through the support boundary, without a sharp circular slip surface.
    float psi = relative.x * offset.y - relative.y * offset.x;
    vec2 change = relative * envelope + psi * vec2(gradient.y, -gradient.x);
    if (c.y != 0.0) {
        vec2 tangent = vec2(-nearest.y, nearest.x);
        float angular = dot(current - carrier, tangent) / max(dot(nearest, nearest), 1.0);
        change += tangent * (c.y - angular) * envelope;
    }
    float amount = c.w > 0.5 ? p.domain.z : 1.0;
    float blend = 1.0 - exp(-items[index * 6 + 3].w * amount);
    return change * blend + offset / max(length(offset), 1.0) * items[index * 6 + 4].x * envelope * amount;
}
float mist_hash(vec2 cell) {
    vec3 v = fract(vec3(cell.xyx) * 0.1031);
    v += dot(v, v.yzx + 33.33);
    return fract((v.x + v.y) * v.z);
}
float mist_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 f = fract(point);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mist_hash(cell), mist_hash(cell + vec2(1, 0)), f.x),
               mix(mist_hash(cell + vec2(0, 1)), mist_hash(cell + vec2(1, 1)), f.x), f.y);
}

void main() {
    ivec2 q = ivec2(gl_GlobalInvocationID.xy);
    int mode = int(p.domain.w);
    ivec2 n = (mode == 5 || mode == 6) ? imageSize(dye_in) : imageSize(state_in);
    if (any(greaterThanEqual(q, n))) return;
    vec2 h = p.domain.xy / vec2(imageSize(state_in));
    vec2 at = (vec2(q) + 0.5) * p.domain.xy / vec2(n);
    float dt = p.domain.z;
    if (mode == 6) {
        imageStore(dye_out, q, imageLoad(dye_in, q));
        imageStore(matter_out, q, imageLoad(matter_in, q));
        return;
    }
    if (mode == 7) {
        vec4 s = state(q);
        s.zw = sample_dye(at / p.domain.xy * vec2(imageSize(dye_in)) - 0.5);
        imageStore(state_out, q, s);
        return;
    }
    if (mode == 5) {
        vec2 fog_h = p.domain.xy / vec2(n);
        vec2 vq = at / h - 0.5;
        vec2 flow = sample_state(vq).xy;
        flow = sample_state(vq - flow * dt * 0.5 / h).xy;
        vec2 back = vec2(q) - flow * dt / fog_h;
        for (int i = 1; i <= 4; i++) {
            if (boundary(ivec2(round(vq - flow * dt / h * float(i) * 0.25))).z > 0.5) { back = vec2(q); break; }
        }
        vec2 dye = sample_dye(back) * exp(-p.decay.yz * dt);
        vec4 matter = sample_matter(back) * exp(-p.decay.y * dt);
        // Mist is a passive concentration in incompressible air. Residual
        // projection error must not amplify it into a bright compression ring.
        matter.a = min(matter.a + dye.x * dt, dye.x * 12.0);
        for (int i = 0; i < int(p.counts.x); i++) {
            vec4 a = items[i * 6]; vec4 v = items[i * 6 + 1]; vec4 c = items[i * 6 + 2];
            if (v.z == 0.0 && v.w == 0.0) continue;
            float weight = 1.0 - smoothstep(-min(a.z, a.w), 0.0, distance_shape(at, i));
            if (weight <= 0.0) continue;
            vec4 pigment = items[i * 6 + 3]; vec4 detail = items[i * 6 + 4];
            float amount = (c.w > 0.5 ? dt : 1.0) * weight;
            if (detail.y > 0.0) {
                vec2 drift = vec2(p.decay.w * 0.025, -p.decay.w * 0.016);
                float cloud = mist_noise(at / max(detail.z, 1.0) + drift) * 0.8
                            + mist_noise(at / max(detail.z * 0.43, 1.0) - drift) * 0.2;
                amount *= mix(1.0, 2.2 * smoothstep(0.28, 0.8, cloud), detail.y);
            }
            float added = max(v.z, 0.0) * amount;
            dye += vec2(added, v.w * amount);
            matter += vec4(pigment.rgb, detail.w) * added;
        }
        matter *= min(1.0, 4.0 / max(dye.x, 0.00001));
        dye = clamp(dye, vec2(0, -4), vec2(4));
        if (boundary(ivec2(round(vq))).z > 0.5) { dye = vec2(0); matter = vec4(0); }
        imageStore(dye_out, q, vec4(dye, 0, 0));
        imageStore(matter_out, q, matter);
        return;
    }
    if (mode == 4) {
        vec4 b = vec4(0);
        if (p.counts.z > 0.5 && texture(domain_mask, (vec2(q) + 0.5) / vec2(n)).r < 0.5) b.z = 1.0;
        for (int i = int(p.counts.x); i < int(p.counts.x + p.counts.y); i++) {
            if (distance_shape(at, i) <= 0.0) {
                vec4 a = items[i * 6]; vec4 v = items[i * 6 + 1];
                vec2 d = at - a.xy;
                b = vec4(v.xy + vec2(-d.y, d.x) * items[i * 6 + 2].y, 1, 0);
            }
        }
        imageStore(geometry, q, b);
        return;
    }
    vec4 b = boundary(q);
    if (mode == 0) {
        vec2 back = vec2(q) - state(q).xy * dt / h;
        // Do not pull density through a solid on the characteristic segment.
        for (int i = 1; i <= 4; i++) {
            if (boundary(ivec2(round(mix(vec2(q), back, float(i) * 0.25)))).z > 0.5) { back = vec2(q); break; }
        }
        vec4 s = state(q);
        s.xy = sample_state(back).xy * exp(-p.decay.x * dt);
        s.xy += (p.environment.xy + vec2(0, p.material.x * s.z - p.environment.z * s.w)) * dt;
        float w = curl(q, h);
        vec2 grad = vec2(abs(curl(q + ivec2(1, 0), h)) - abs(curl(q - ivec2(1, 0), h)),
                         abs(curl(q + ivec2(0, 1), h)) - abs(curl(q - ivec2(0, 1), h))) / (2.0 * h);
        grad /= max(length(grad), 0.0001);
        s.xy += vec2(grad.y, -grad.x) * w * min(h.x, h.y) * p.environment.w * dt;
        // Air exists without pigment. Small background accelerations accumulate
        // over time; a newly deposited fast trail bends gradually, not by age gates.
        vec2 phase = at * (6.283185 / max(p.material.y, 1.0)) + vec2(p.decay.w * 0.23, -p.decay.w * 0.19);
        vec2 eddy = vec2(sin(phase.x) * cos(phase.y), -cos(phase.x) * sin(phase.y));
        eddy += vec2(cos(phase.y * 1.71), sin(phase.x * 1.71)) * 0.35;
        s.xy += eddy * p.counts.w * p.material.w * 0.35 * dt;
        // Resolved curl waves at two smaller scales. They stir transported mist,
        // never modulate its rendered alpha. Grid spacing limits each wavelength.
        vec2 axes = vec2(0.8, 0.6);
        vec2 cross_axis = vec2(-axes.y, axes.x);
        vec2 flowing = at - s.xy * dt;
        float small_scale = max(p.material.y * 0.16, max(h.x, h.y) * 6.0);
        float fine_scale = max(p.material.y * 0.065, max(h.x, h.y) * 4.0);
        vec2 small_phase = vec2(dot(flowing, axes), dot(flowing, cross_axis)) * (6.283185 / small_scale);
        small_phase += vec2(p.decay.w * 0.47, -p.decay.w * 0.39);
        vec2 small = axes * sin(small_phase.x) * cos(small_phase.y)
                   - cross_axis * cos(small_phase.x) * sin(small_phase.y);
        vec2 fine_phase = flowing * (6.283185 / fine_scale) + vec2(-p.decay.w * 0.61, p.decay.w * 0.53);
        small += vec2(sin(fine_phase.y), cos(fine_phase.x)) * 0.38;
        float shear = min(abs(w) * small_scale * 0.16, 45.0);
        s.xy += small * (p.material.w * 0.22 + shear) * p.detail.x * p.counts.w * dt;
        for (int i = 0; i < int(p.counts.x); i++) {
            vec4 a = items[i * 6]; vec4 v = items[i * 6 + 1]; vec4 c = items[i * 6 + 2];
            vec4 pigment = items[i * 6 + 3]; vec4 detail = items[i * 6 + 4];
            if (items[i * 6 + 5].x > 0.0) {
                s.xy += body_flow(at, i, s.xy, h);
                continue;
            }
            float weight = 1.0 - smoothstep(-min(a.z, a.w), 0.0, distance_shape(at, i));
            if (weight <= 0.0) continue;
            vec2 d = at - a.xy;
            float amount = c.w > 0.5 ? dt : 1.0;
            vec2 drive = v.xy;
            drive += vec2(-d.y, d.x) * c.y;
            if (pigment.w > 0.0) {
                vec2 relative = drive - s.xy;
                s.xy += relative * (1.0 - exp(-pigment.w * weight * amount));
            } else s.xy += drive * weight * amount;
            s.xy += d / max(length(d), 1.0) * detail.x * weight * amount;
        }
        // Bound characteristic length, independent of display scale and frame stalls.
        s.xy = clamp(s.xy, -h * (3.0 / dt), h * (3.0 / dt));
        if (b.z > 0.5) s = vec4(b.xy, 0, 0);
        imageStore(state_out, q, s);
    } else if (mode == 1) {
        float div = (velocity(q + ivec2(1, 0)).x - velocity(q - ivec2(1, 0)).x) / (2.0 * h.x)
                  + (velocity(q + ivec2(0, 1)).y - velocity(q - ivec2(0, 1)).y) / (2.0 * h.y);
        b.w = b.z > 0.5 ? 0.0 : div;
        imageStore(geometry, q, b);
        imageStore(pressure_out, q, vec4(0));
    } else if (mode == 2) {
        float c = imageLoad(pressure_in, q).r;
        vec2 k = 1.0 / (h * h);
        float value = ((neighbor_pressure(q + ivec2(1, 0), c) + neighbor_pressure(q - ivec2(1, 0), c)) * k.x
                     + (neighbor_pressure(q + ivec2(0, 1), c) + neighbor_pressure(q - ivec2(0, 1), c)) * k.y - b.w)
                     / (2.0 * (k.x + k.y));
        imageStore(pressure_out, q, vec4(b.z > 0.5 ? 0.0 : value));
    } else {
        float c = imageLoad(pressure_in, q).r;
        vec4 s = state(q);
        s.xy -= vec2(neighbor_pressure(q + ivec2(1, 0), c) - neighbor_pressure(q - ivec2(1, 0), c),
                     neighbor_pressure(q + ivec2(0, 1), c) - neighbor_pressure(q - ivec2(0, 1), c)) / (2.0 * h);
        vec4 right = boundary(q + ivec2(1, 0)); vec4 left = boundary(q - ivec2(1, 0));
        vec4 down = boundary(q + ivec2(0, 1)); vec4 up = boundary(q - ivec2(0, 1));
        if (right.z > 0.5) s.x = right.x; else if (left.z > 0.5) s.x = left.x;
        if (down.z > 0.5) s.y = down.y; else if (up.z > 0.5) s.y = up.y;
        if (b.z > 0.5) s = vec4(b.xy, 0, 0);
        imageStore(state_out, q, s);
    }
}
