
struct LbmUniform {
    tau: f32,
    omega: f32,
    fluid_ty: i32,
    soa_offset: i32,
    e_w_max: array<vec4<f32>, 9>,
    inversed_direction: array<vec4<i32>, 9>,
};

struct LatticeInfo {
  material: i32,
  block_iter: i32,
  vx: f32,
  vy: f32,
};

struct FieldUniform {
  lattice_size: vec2<i32>,
  lattice_pixel_size: vec2<f32>,
  canvas_size: vec2<i32>,
  proj_ratio: vec2<f32>,
  ndc_pixel: vec2<f32>,
  speed_ty: i32,
};



struct StoreFloat {
    data: array<f32>,
};

@group(0) @binding(0) var<uniform> fluid: LbmUniform;
@group(0) @binding(1) var<uniform> field: FieldUniform;
@group(0) @binding(2) var<storage, read_write> collide_cell: StoreFloat;
@group(0) @binding(3) var<storage, read_write> stream_cell: StoreFloat;
@group(0) @binding(4) var<storage, read_write> lattice_info: array<LatticeInfo>;
@group(0) @binding(5) var macro_info: texture_storage_2d<rgba16float, write>;


const Cs2: f32 = 0.333333;

fn isPoiseuilleFlow() -> bool { return fluid.fluid_ty == 0; }

fn e(direction: i32) -> vec2<f32> { return fluid.e_w_max[direction].xy; }
fn w(direction: i32) -> f32 { return fluid.e_w_max[direction].z; }
fn max_value(direction: i32) -> f32 { return fluid.e_w_max[direction].w; }

fn fieldIndex(uv: vec2<i32>) -> i32 { return uv.x + (uv.y * field.lattice_size.x); }
fn soaOffset(direction: i32) -> i32 { return direction * fluid.soa_offset; }
fn latticeIndex(uv: vec2<i32>, direction: i32) -> i32 {
  return fieldIndex(uv) + soaOffset(direction);
}

fn isBoundaryCell(material: i32) -> bool { return material == 2; }
fn isNotBoundaryCell(material: i32) -> bool { return material != 2; }
fn isInletCell(material: i32) -> bool { return material == 3; }
fn isObstacleCell(material: i32) -> bool { return material == 4; }
fn isOutletCell(material: i32) -> bool { return material == 5; }
fn isAccelerateCell(material: i32) -> bool { return material == 3 || material == 6; }

fn isBulkFluidCell(material: i32) -> bool { return material == 1 || material == 3 || material == 5; }

@compute @workgroup_size(64, 4)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let uv = vec2<i32>(gid.xy);
  if (uv.x >= field.lattice_size.x || uv.y >= field.lattice_size.y) {
    return;
  }
  let field_index = fieldIndex(uv);
  
  var info: LatticeInfo = lattice_info[field_index];
  if (isBoundaryCell(info.material) || isObstacleCell(info.material)) {
    for (var i : i32 = 0; i < 9; i = i + 1) {
      collide_cell.data[field_index + soaOffset(i)] =  0.0;
      stream_cell.data[field_index + soaOffset(i)] = 0.0;
    }
  } else if (isPoiseuilleFlow()) {
    for (var i: i32 = 0; i < 9; i = i + 1) {
      collide_cell.data[field_index + soaOffset(i)] =  w(i);
      stream_cell.data[field_index + soaOffset(i)] = 0.0;
    }
    let temp = w(3) * 0.5;
    collide_cell.data[field_index + soaOffset(1)] = w(1) + temp;
    collide_cell.data[field_index + soaOffset(3)] = temp;
    stream_cell.data[field_index + soaOffset(1)] =  w(1) + temp;
    stream_cell.data[field_index + soaOffset(3)] = temp;
  } else {
    for (var i: i32 = 0; i < 9; i = i + 1) {
      collide_cell.data[field_index + soaOffset(i)] =  w(i);
      stream_cell.data[field_index + soaOffset(i)] =  0.0;
    }
  }

  if (isAccelerateCell(info.material)) {
    if (info.block_iter > 0) {
        info.block_iter = 0;
        info.material = 1;
        info.vx = 0.0;
        info.vy = 0.0;
        lattice_info[field_index] = info;
      }
  }

  textureStore(macro_info, vec2<i32>(uv), vec4<f32>(0.0, 0.0, 0.0, 1.0));
}
