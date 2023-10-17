struct Particle {
   pos: vec4<f32>,
   old_pos: vec4<f32>,
   accelerate: vec4<f32>,
   uv_mass: vec4<f32>,
   connect: vec4<i32>,
};


struct ClothUniform {
   num_x: i32,
   num_y: i32,
   gravity: f32,
   damping: f32,
   compliance: f32,
   stiffness: f32,
   dt: f32,
};

struct BendingConstraint {
    v: i32,
    b0: i32,
    b1: i32,
    h0: f32,
};

@group(0) @binding(0) var<uniform> cloth: ClothUniform;
@group(0) @binding(1) var<storage, read_write> particles: array<Particle>;
@group(0) @binding(2) var<storage, read_write> constraints: array<BendingConstraint>;

struct DynamicUniform {
    offset: i32,
    max_num_x: i32,
    group_len: i32,
    invert_iter: f32,
};
@group(1) @binding(0) var<uniform> dy_uniform: DynamicUniform;

fn is_movable_particle(particle: Particle) -> bool {
    if (particle.uv_mass.z < 0.001) {
        return false;
    }
    return true;
}


@compute @workgroup_size(32, 1)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {  
    var field_index = i32(gid.x);
    if (field_index >= dy_uniform.group_len) {
        return;
    }
    field_index = field_index + dy_uniform.offset;
    
    let bending: BendingConstraint = constraints[field_index];
    var v: Particle = particles[bending.v];
    var b0: Particle = particles[bending.b0];
    var b1: Particle = particles[bending.b1];

    let c: vec3<f32> = (b0.pos.xyz + b1.pos.xyz + v.pos.xyz) * 0.33333333;
    let w = b0.uv_mass.z + b1.uv_mass.z + 2.0 * v.uv_mass.z;
    let v_minus_c = v.pos.xyz - c;
    let v_minus_c_len = length(v_minus_c);
    let k = 1.0 - pow(1.0 - cloth.stiffness, dy_uniform.invert_iter);
    let c_triangle = v_minus_c_len - (k + bending.h0);
    if (c_triangle <= 0.0) {
        return;
    }
    let f = v_minus_c * (1.0 - (k + bending.h0) / v_minus_c_len);

    if (is_movable_particle(v)) {
        v.pos = vec4<f32>(v.pos.xyz + (-4.0 * v.uv_mass.z) / w * f, 0.0);
        particles[bending.v] = v;
    }
    if (is_movable_particle(b0)) {
        b0.pos = vec4<f32>(b0.pos.xyz + (2.0 * b0.uv_mass.z) / w * f, 0.0);
        particles[bending.b0] = b0;
    }
    if (is_movable_particle(b1)) {
        b1.pos = vec4<f32>(b1.pos.xyz + (2.0 * b1.uv_mass.z) / w * f, 0.0);
        particles[bending.b1] = b1;
    }
}
