
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


fn diffuse_feq(velocity: vec2<f32>, rho: f32, direction: i32) -> f32 {
  return rho * w(direction);
}

fn diffuse_feq2(velocity: vec2<f32>, rho: f32, direction: i32, usqr: f32) -> f32 {
  let e_dot_u = dot(e(direction), velocity);
  let psi = smoothstep(0.01, 0.2, rho) * rho;
  return w(direction) * (rho + psi * (3.0 * e_dot_u + 4.5 * (e_dot_u * e_dot_u) - usqr));
}

fn equilibrium(velocity: vec2<f32>, rho: f32, direction: i32, usqr: f32) -> f32 {
  let e_dot_u = dot(e(direction), velocity);
  return rho * w(direction) * (1.0 + 3.0 * e_dot_u + 4.5 * (e_dot_u * e_dot_u) - usqr);
}


@compute @workgroup_size(64, 4)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {
    let uv = vec2<i32>(gid.xy);
    if (uv.x >= field.lattice_size.x || uv.y >= field.lattice_size.y) {
      return;
    }
    var field_index : i32 = fieldIndex(uv);
    var info: LatticeInfo = lattice_info[field_index];
    if (isBoundaryCell(info.material) || isObstacleCell(info.material)) {
      textureStore(macro_info, vec2<i32>(uv), vec4<f32>(0.0, 0.0, 0.0, 0.0));
      return;
    }
    
    var f_i : array<f32, 9>;
    var velocity : vec2<f32> = vec2<f32>(0.0, 0.0);
    var rho : f32 = 0.0;
    for (var i : i32 = 0; i < 9; i = i + 1) {
      f_i[i] = collide_cell.data[streaming_in(uv, i)];
      rho = rho + f_i[i];
      velocity = velocity + e(i) * f_i[i];
    }
    rho = clamp(rho, 0.8, 1.2);

    velocity = velocity / rho;
    var F : array<f32, 9> = array<f32, 9>(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    if (isAccelerateCell(info.material)) {
      if (info.block_iter > 0) {
        info.block_iter = info.block_iter - 1;
        if (info.block_iter == 0) {
          info.material = 1;
        }
      }
      lattice_info[field_index] = info;

      let force = vec2<f32>(info.vx, info.vy);
      velocity = force * 0.5 / rho;

      for (var i : i32 = 0; i < 9; i = i + 1) {
        F[i] = w(i) * 3.0 * dot(e(i), force);
      }
    }
   
    textureStore(macro_info, vec2<i32>(uv), vec4<f32>(velocity.x, velocity.y, rho, 1.0));

    let usqr = 1.5 * dot(velocity, velocity);
    for (var i : i32 = 0; i < 9; i = i + 1) {
      var temp_val: f32 = f_i[i] - fluid.omega * (f_i[i] - equilibrium(velocity, rho, i, usqr)) + F[i];
      if (temp_val > max_value(i)) {
        temp_val = max_value(i);
      } else if (temp_val < 0.0) {
        temp_val = 0.0;
      }
      stream_cell.data[field_index + soaOffset(i)] = temp_val;
    }
}
