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

struct Constraint {
   rest_length: f32,
   lambda: f32,
   particle0: i32,
   particle1: i32,
};

@group(0) @binding(0) var<uniform> cloth: ClothUniform;
@group(0) @binding(1) var<storage, read_write> particles: array<Particle>;
@group(0) @binding(2) var<storage, read_write> constraints: array<Constraint>;

const EPSILON: f32 = 0.0000001;

fn is_movable_particle(particle: Particle) -> bool {
  if (particle.uv_mass.z < 0.001) {
    return false;
  }
  return true;
}

struct DynamicUniform {
  offset: i32,
  max_num_x: i32,
  max_num_y: i32,
  group_len: i32,
};

@group(1) @binding(0) var<uniform> dy_uniform: DynamicUniform;

@compute @workgroup_size(32, 1)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {  
    var field_index = i32(gid.x);
    if (field_index >= dy_uniform.group_len) {
        return;
    }
    field_index += dy_uniform.offset;

    var constraint = constraints[field_index];
    let particle0_index = constraint.particle0;
    var particle = particles[particle0_index];
    let invert_mass0 = particle.uv_mass.z;

    var particle1 = particles[constraint.particle1];
    let invert_mass1 = particle1.uv_mass.z;
    let sum_mass = invert_mass0 + invert_mass1;
    if (sum_mass < 0.01) {
        return;
    }
    let p0_minus_p1 = particle.pos - particle1.pos;
    let dis = length(p0_minus_p1.xyz);
    let distance = dis - constraint.rest_length;

    var correction_vector: vec4<f32>;
    let dlambda = -distance / (sum_mass + cloth.compliance);
    correction_vector = dlambda * p0_minus_p1 / (dis + EPSILON);

    if (is_movable_particle(particle)) {
        particle.pos = particle.pos + invert_mass0 * correction_vector;
        particles[particle0_index] = particle;
    }
    if (is_movable_particle(particle1)) {
        particle1.pos = particle1.pos + (-invert_mass1) * correction_vector;
        particles[constraint.particle1] = particle1;
    }
}
