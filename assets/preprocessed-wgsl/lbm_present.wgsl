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
@group(0) @binding(3) var macro_info: texture_2d<f32>;
@group(0) @binding(4) var cur_info: texture_2d<f32>;
@group(0) @binding(5) var tex_sampler: sampler;

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
    let xx = particle_uniform.color;
    let pixel_coord = min(vec2<i32>(floor(in.position.xy)), field.canvas_size.xy - 1);
    let p_index = pixel_coord.x + pixel_coord.y * field.canvas_size.x;
    var p: Pixel = canvas[p_index];
    let macro_data: vec4<f32> = textureSample(macro_info, tex_sampler, in.uv);

    let curl: vec4<f32> = textureSample(cur_info, tex_sampler, in.uv);

    var frag_color: vec4<f32>;
    let speed = abs(macro_data.x) + abs(macro_data.y);

    let angle = (atan2(macro_data.y, macro_data.x) + PI) / (2.0 * PI);
    frag_color = vec4<f32>(hsv2rgb(curl.x , 0.6 + speed * 1.4, 0.6 + macro_data.z * 0.33), macro_data.z);

    return frag_color;
}

