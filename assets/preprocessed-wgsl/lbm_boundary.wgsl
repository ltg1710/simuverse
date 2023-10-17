
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
@group(0) @binding(2) var<storage, read> collide_cell: StoreFloat;
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

fn streaming_out(uv: vec2<i32>, direction: i32) -> i32 {
    var target_uv : vec2<i32> = uv + vec2<i32>(e(direction));
    if (target_uv.x < 0) {
      target_uv.x = field.lattice_size.x - 1;
    } else if (target_uv.x >= field.lattice_size.x) {
      target_uv.x = 0;
    }
    if (target_uv.y < 0) {
      target_uv.y = field.lattice_size.y - 1;
    } else if (target_uv.y >= field.lattice_size.y) {
      target_uv.y = 0;
    }
    return latticeIndex(target_uv, direction);
}

fn streaming_in(uv: vec2<i32>, direction: i32) -> i32 {
    var target_uv : vec2<i32> = uv + vec2<i32>(e(fluid.inversed_direction[direction].x));  
    if (target_uv.x < 0) {
      target_uv.x = field.lattice_size.x - 1;
    } else if (target_uv.x >= field.lattice_size.x) {
      target_uv.x = 0;
    }
    if (target_uv.y < 0) {
      target_uv.y = field.lattice_size.y - 1;
    } else if (target_uv.y >= field.lattice_size.y) {
      target_uv.y = 0;
    } 
    return latticeIndex(target_uv, direction);
}

@compute @workgroup_size(64, 4)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {
    let uv = vec2<i32>(gid.xy);
    if (uv.x >= field.lattice_size.x || uv.y >= field.lattice_size.y) {
      return;
    }
    var field_index : i32 = fieldIndex(uv);
    let info: LatticeInfo = lattice_info[field_index];
    if (isBoundaryCell(info.material) || isObstacleCell(info.material)) {
        
        for (var i : i32 = 0; i < 9; i = i + 1) {
            let new_uv : vec2<i32> = uv - vec2<i32>(e(i));
            if (new_uv.x <= 0 || new_uv.y <= 0 || new_uv.x >= (field.lattice_size.x - 1) || new_uv.y >= (field.lattice_size.y - 1)) {
                continue;
            } else {

                let val = stream_cell.data[latticeIndex(new_uv, i)];
                let lattice_index = field_index + soaOffset(fluid.inversed_direction[i].x);
                stream_cell.data[lattice_index] = val;
                stream_cell.data[latticeIndex(new_uv, i)] = 0.0;
            }
        }
    }
}
