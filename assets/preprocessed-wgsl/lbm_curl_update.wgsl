
struct LbmUniform {
    tau: f32,
    omega: f32,
    fluid_ty: i32,
    soa_offset: i32,
    e_w_max: array<vec4<f32>, 9>,
    inversed_direction: array<vec4<i32>, 9>,
};

struct FieldUniform {
  lattice_size: vec2<i32>,
  lattice_pixel_size: vec2<f32>,
  canvas_size: vec2<i32>,
  proj_ratio: vec2<f32>,
  ndc_pixel: vec2<f32>,
  speed_ty: i32,
};


struct LatticeInfo {
  material: i32,
  block_iter: i32,
  vx: f32,
  vy: f32,
};

@group(0) @binding(0) var<uniform> fluid: LbmUniform;
@group(0) @binding(1) var<uniform> field: FieldUniform;
@group(0) @binding(2) var<storage, read_write> lattice_info: array<LatticeInfo>;
@group(0) @binding(3) var fb: texture_2d<f32>;
@group(0) @binding(4) var curl_info: texture_storage_2d<rgba16float, write>;

@compute @workgroup_size(64, 4)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {
    let uv = vec2<i32>(gid.xy);
    if (uv.x >= field.lattice_size.x || uv.y >= field.lattice_size.y) {
      return;
    }
    var field_index : i32 = uv.x + (uv.y * field.lattice_size.x);
    var info: LatticeInfo = lattice_info[field_index];
    let right = min(vec2<i32>(uv.x + 1, uv.y), field.lattice_size.xy);
    let left = max(vec2<i32>(uv.x - 1, uv.y), vec2<i32>(0, 0));
    let top = max(vec2<i32>(uv.x, uv.y - 1), vec2<i32>(0, 0));
    let bottom = min(vec2<i32>(uv.x, uv.y + 1), field.lattice_size.xy);
    var curl: f32 = textureLoad(fb, right, 0).y - textureLoad(fb, left, 0).y + textureLoad(fb, top, 0).x - textureLoad(fb, bottom, 0).x;

    textureStore(curl_info, uv, vec4<f32>(curl * 3.5 + 0.5, 0.0, 0.0, 0.0));
    
}
