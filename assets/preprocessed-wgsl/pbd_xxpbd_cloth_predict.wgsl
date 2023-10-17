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

const ball_pos: vec4<f32> = vec4<f32>(0.0, 0.0, 0.0, 0.0);

@compute @workgroup_size(32, 1, 1)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {
    let total = arrayLength(&particles);
    let field_index = gid.x;
    if (field_index >= total) {
      return;
    }
    var particle: Particle = particles[field_index];
    if (is_movable_particle(particle)) {
      let temp_pos = particle.pos;

      particle.pos += (particle.pos - particle.old_pos)*(1.0 - cloth.damping) + vec4<f32>(0.0, cloth.gravity, 0.0, 0.0) * particle.uv_mass.z * cloth.dt * cloth.dt ;
      particle.old_pos = temp_pos;
      particles[field_index] = particle;
    }
}
