struct VertexOutput {
    @location(0) uv: vec2<f32>,
    @builtin(position) position: vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
    let uv: vec2<f32> = vec2<f32>(f32((vertexIndex << 1u) & 2u), f32(vertexIndex & 2u));
    var out: VertexOutput;
    out.position = vec4<f32>(uv * 2.0 - 1.0, 0.1, 1.0);
    out.uv = vec2<f32>(uv.x, (uv.y - 1.0) *  (-1.0));
    return out;
}


struct FieldUniform {
  lattice_size: vec2<i32>,
  lattice_pixel_size: vec2<f32>,
  canvas_size: vec2<i32>,
  proj_ratio: vec2<f32>,
  ndc_pixel: vec2<f32>,
  speed_ty: i32,
};


struct ParticleUniform {
    color: vec4<f32>,
    num: vec2<i32>,
    point_size: i32,
    life_time: f32,
    fade_out_factor: f32,
    speed_factor: f32,
    color_ty: i32,
    is_only_update_pos: i32,
};

struct TrajectoryParticle {
    pos: vec2<f32>,
    pos_initial: vec2<f32>,
    life_time: f32,
    fade: f32,
};
struct Pixel {
    alpha: f32,
    velocity_x: f32,
    velocity_y: f32,
};

@group(0) @binding(0) var<uniform> field: FieldUniform;
@group(0) @binding(1) var<uniform> particle_uniform: ParticleUniform;
@group(0) @binding(2) var<storage, read_write> canvas: array<Pixel>;

fn hsv2rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let K = vec4<f32>(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    let p = abs(fract(vec3<f32>(h, h, h) + K.xyz) * 6.0 - vec3<f32>(K.w, K.w, K.w));
    let kx = vec3<f32>(K.x, K.x, K.x);
    let c = clamp(p - kx, vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(1.0, 1.0, 1.0));
    return v * mix(kx, c, vec3<f32>(s, s, s));
}

const PI: f32 = 3.1415926535;

@fragment 
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let pixel_coord = min(vec2<i32>(floor(in.position.xy)), field.canvas_size - 1);
    let p_index = pixel_coord.x + pixel_coord.y * field.canvas_size.x;
    var p: Pixel = canvas[p_index];

    var frag_color: vec4<f32>;
    if (p.alpha > 0.001) {
        if (particle_uniform.color_ty == 1) {
            let velocity = length(vec2<f32>(p.velocity_x, p.velocity_y));
            var speed: f32;
            if (field.speed_ty == 0) {
                speed = velocity;
            } else {
                speed =  min(velocity / 0.25, 1.15);
            }
            frag_color = vec4<f32>(hsv2rgb(0.05 + speed * 0.75, 0.9, 1.0), p.alpha);
        } else if (particle_uniform.color_ty == 0) {
            let angle = atan2(p.velocity_y, p.velocity_x) / (2.0 * PI);
            frag_color = vec4<f32>(hsv2rgb(angle, 0.9, 1.0), p.alpha);
        } else {
            frag_color = vec4<f32>(particle_uniform.color.rgb, p.alpha);
        }

        if (p.alpha >= 0.2) {
            p.alpha = p.alpha * particle_uniform.fade_out_factor;
        } else {
            p.alpha = p.alpha * 0.5;
        }
        canvas[p_index] = p;
    } else {
        frag_color = vec4<f32>(0.0);
    }
    return frag_color;
}

