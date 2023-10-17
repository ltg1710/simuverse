
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
@group(0) @binding(2) var<storage, read_write> field_buf: array<vec4<f32>>;
@group(0) @binding(3) var<storage, read_write> particle_buf: array<TrajectoryParticle>;
@group(0) @binding(4) var<storage, read_write> canvas: array<Pixel>;

fn src_2f(u: i32, v: i32) -> vec2<f32> {
  let new_u = clamp(u, 0, field.lattice_size.x - 1);
  let new_v = clamp(v, 0, field.lattice_size.y - 1);
  let index = new_v * field.lattice_size.x + new_u;

  return field_buf[index].xy;
}
fn bilinear_interpolate_2f(uv: vec2<f32>) -> vec2<f32> {
  let minX: i32 = i32(floor(uv.x));
  let minY: i32 = i32(floor(uv.y));

  let fx: f32 = uv.x - f32(minX);
  let fy: f32 = uv.y - f32(minY);
  return src_2f(minX, minY) * ((1.0 - fx) * (1.0 - fy)) +
         src_2f(minX, minY + 1) * ((1.0 - fx) * fy) +
         src_2f(minX + 1, minY) * (fx * (1.0 - fy)) +
         src_2f(minX + 1, minY + 1) * (fx * fy);
}

fn field_index(uv: vec2<i32>) -> i32 {
   return uv.x + (uv.y * field.lattice_size.x);
}

fn particle_index(uv: vec2<i32>) -> i32 {
   return uv.x + (uv.y * particle_uniform.num.x);
}

fn update_canvas(particle: TrajectoryParticle, velocity: vec2<f32>) {
    let pixel_coords = vec2<i32>(particle.pos);
    let px = pixel_coords.x - particle_uniform.point_size / 2;
    let py = pixel_coords.y - particle_uniform.point_size / 2;
    let info = Pixel(particle.fade, velocity.x, velocity.y);
    for (var x: i32 = 0; x < particle_uniform.point_size; x = x + 1) {
        for (var y: i32 = 0; y < particle_uniform.point_size; y = y + 1) {
            let coords = vec2<i32>(px + x, py + y);
            if (coords.x >= 0 && coords.x < field.canvas_size.x 
                && coords.y >= 0 && coords.y < field.canvas_size.y) {
                canvas[coords.x + field.canvas_size.x * coords.y] = info;
            }
        }
    }
}

@compute @workgroup_size(16, 16)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let uv = vec2<i32>(gid.xy);
  if (uv.x >= particle_uniform.num.x || uv.y >= particle_uniform.num.y) {
    return;
  }
  let p_index: i32 = particle_index(uv);
  var particle: TrajectoryParticle = particle_buf[p_index];
  if (particle.life_time <= 0.1) {
    particle.fade = 0.0;
    particle.pos = particle.pos_initial;
    particle.life_time = particle_uniform.life_time;
  } else {
    particle.life_time = particle.life_time - 1.0;
    if (particle.fade < 0.9) {
      particle.fade = particle.fade + 0.1;
    } else {
      particle.fade = 1.0;
    }

    let ij = (particle.pos / field.lattice_pixel_size) - 0.5;
    let velocity = bilinear_interpolate_2f(ij);
    particle.pos += (velocity * particle_uniform.speed_factor);
    
    update_canvas(particle, velocity);
  }
   
  particle_buf[p_index] = particle;
}
