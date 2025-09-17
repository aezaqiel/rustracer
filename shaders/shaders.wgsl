const FLT_MAX: f32 = 3.40282346638528859812e+38;

struct Uniforms {
    width: u32,
    height: u32,
    frame_count: u32
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct Rng {
    state: u32
}
var<private> rng: Rng;

fn init_rng(pixel: vec2u) {
    let seed = (pixel.x + pixel.y * uniforms.width) ^ jenkins_hash(uniforms.frame_count);
    rng.state = jenkins_hash(seed);
}

fn jenkins_hash(i: u32) -> u32 {
    var x = i;
    x += x << 10u;
    x ^= x >> 6u;
    x += x << 3u;
    x ^= x >> 11u;
    x += x << 15u;
    return x;
}

fn xorshift32() -> u32 {
    var x = rng.state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    rng.state = x;
    return x;
}

fn rand_f32() -> f32 {
    return bitcast<f32>(0x3f800000u | (xorshift32() >> 9u)) - 1.;
}

struct Intersection {
    normal: vec3f,
    t: f32
}

fn no_intersection() -> Intersection {
    return Intersection(vec3(0.0), -1.0);
}

struct Sphere {
    center: vec3f,
    radius: f32
}

fn intersect_sphere(ray: Ray, sphere: Sphere) -> Intersection {
    let v = ray.origin - sphere.center;

    let a = dot(ray.direction, ray.direction);
    let b = dot(v, ray.direction);
    let c = dot(v, v) - sphere.radius * sphere.radius;

    let d = b * b - a * c;
    if d < 0 {
        return no_intersection();
    }

    let sqrtd = sqrt(d);
    let recip_a = 1.0 / a;
    let mb = -b;

    let t0 = (mb - sqrtd) * recip_a;
    let t1 = (mb + sqrtd) * recip_a;
    let t = select(t1, t0, t0 > 0.0);

    if t < 0.0 {
        return no_intersection();
    }

    let p = point_on_ray(ray, t);
    let N = (p - sphere.center) / sphere.radius;
    return Intersection(N, t);
}

struct Ray {
    origin: vec3f,
    direction: vec3f
}

fn point_on_ray(ray: Ray, t: f32) -> vec3<f32> {
    return ray.origin + t * ray.direction;
}

fn sky_color(ray: Ray) -> vec3f {
    let t = 0.5 * (normalize(ray.direction).y + 1.0);
    return (1.0 - t) * vec3(1.0, 0.5, 0.3) + t * vec3(0.3, 0.5, 1.0);
}

const OBJECT_COUNT: u32 = 2;
alias Scene = array<Sphere, OBJECT_COUNT>;
var<private> scene: Scene = Scene(
    Sphere(vec3(0.0, 0.0, -1.0), 0.5),
    Sphere(vec3(0.0, -100.5, -1.0), 100.0)
);

@group(0) @binding(1) var radiance_samples_old: texture_2d<f32>;
@group(0) @binding(2) var radiance_samples_new: texture_storage_2d<rgba32float, write>;

alias TriangleVertices = array<vec2f, 6>;
var<private> vertices: TriangleVertices = TriangleVertices(
    vec2f(-1.0,  1.0),
    vec2f(-1.0, -1.0),
    vec2f( 1.0,  1.0),
    vec2f( 1.0,  1.0),
    vec2f(-1.0, -1.0),
    vec2f( 1.0, -1.0)
);

@vertex fn display_vs(@builtin(vertex_index) vid: u32) -> @builtin(position) vec4f {
    return vec4f(vertices[vid], 0.0, 1.0);
}

@fragment fn display_fs(@builtin(position) pos: vec4f) -> @location(0) vec4f {
    init_rng(vec2u(pos.xy));

    let origin = vec3(0.0);
    let focus_distance = 1.0;
    let aspect_ratio = f32(uniforms.width) / f32(uniforms.height);

    let offset = vec2(rand_f32() - 0.5, rand_f32() - 0.5);
    var uv = (pos.xy + offset) / vec2f(f32(uniforms.width - 1u), f32(uniforms.height - 1u));
    uv = (2.0 * uv - vec2(1.0)) * vec2(aspect_ratio, -1.0);

    let direction = vec3(uv, -focus_distance);
    let ray = Ray(origin, direction);

    var closest_hit = Intersection(vec3(0.0), FLT_MAX);
    for (var i = 0u; i < OBJECT_COUNT; i += 1u) {
        let sphere = scene[i];
        let hit = intersect_sphere(ray, sphere);
        if hit.t > 0.0 && hit.t < closest_hit.t {
            closest_hit = hit;
        }
    }

    var radiance_samples: vec3f;
    if closest_hit.t < FLT_MAX {
        radiance_samples = vec3(0.5 * closest_hit.normal + vec3(0.5));
    } else {
        radiance_samples = sky_color(ray);
    }

    var old_sum: vec3f;
    if uniforms.frame_count > 1 {
        old_sum = textureLoad(radiance_samples_old, vec2u(pos.xy), 0).xyz;
    } else {
        old_sum = vec3(0.0);
    }

    let new_sum = radiance_samples + old_sum;
    textureStore(radiance_samples_new, vec2u(pos.xy), vec4(new_sum, 0.0));

    return vec4(new_sum / f32(uniforms.frame_count), 1.0);
}
