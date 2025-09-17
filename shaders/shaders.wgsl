const FLT_MAX: f32 = 3.40282346638528859812e+38;

struct Uniforms {
    width: u32,
    height: u32
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;

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
    let origin = vec3(0.0);
    let focus_distance = 1.0;
    let aspect_ratio = f32(uniforms.width) / f32(uniforms.height);

    var uv = pos.xy / vec2f(f32(uniforms.width - 1u), f32(uniforms.height - 1u));
    uv = (2.0 * uv - vec2(1.0)) * vec2(aspect_ratio, -1.0);

    let direction = vec3(uv, -focus_distance);
    let ray = Ray(origin, direction);

    var closest_hit = Intersection(vec3(0.0), FLT_MAX);
    for (var i = 0u; i < OBJECT_COUNT; i += 1u) {
        let hit = intersect_sphere(ray, scene[i]);
        if hit.t > 0.0 && hit.t < closest_hit.t {
            closest_hit = hit;
        }
    }

    if closest_hit.t < FLT_MAX {
        return vec4(0.5 * closest_hit.normal + vec3(0.5), 1.0);
    }

    return vec4(sky_color(ray), 1.0);
}
