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

@group(0) @binding(0) var macro_info: texture_2d<f32>;
@group(0) @binding(1) var tex_sampler: sampler;

fn hsv2rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let K = vec4<f32>(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    let p = abs(fract(vec3<f32>(h, h, h) + K.xyz) * 6.0 - vec3<f32>(K.w, K.w, K.w));
    let kx = vec3<f32>(K.x, K.x, K.x);
    let c = clamp(p - kx, vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(1.0, 1.0, 1.0));
    return v * mix(kx, c, vec3<f32>(s, s, s));
}

let PI: f32 = 3.1415926;
let PI_2: f32 = 1.570796;

@fragment
fn fs_main(in : VertexOutput) -> @location(0) vec4<f32> {
  let macro_data: vec4<f32> = textureSample(macro_info, tex_sampler, in.uv);
  let angle = (atan2(macro_data.x, macro_data.y) + PI) / (2.0 * PI);
  return vec4<f32>(hsv2rgb(angle, 0.75, 1.0), 1.0);


}
