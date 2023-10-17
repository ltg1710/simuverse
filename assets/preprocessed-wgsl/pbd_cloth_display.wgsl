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

struct MVPMatUniform {
    mv: mat4x4<f32>,
    proj: mat4x4<f32>,
    mvp: mat4x4<f32>,
    normal: mat4x4<f32>,
};

@group(0) @binding(0) var<uniform> mvp_mat: MVPMatUniform;
@group(0) @binding(1) var<uniform> cloth: ClothUniform;
@group(0) @binding(2) var<storage, read> particles: array<Particle>;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) ec_pos: vec3<f32>,
    @location(3) collision_area: f32,
};

@vertex
fn vs_main(
    @location(0) particle_index: vec3<u32>,
) -> VertexOutput {
    let field_index = particle_index.x + particle_index.y * u32(cloth.num_x);
    let particle = particles[field_index];

    let particle1 = particles[particle.connect[0] ];
    let particle2 = particles[particle.connect[1] ];
    let particle3 = particles[particle.connect[2] ];
    let particle4 = particles[particle.connect[3] ];

    let mv_pos = mvp_mat.mv * vec4<f32>(particle.pos.xyz, 1.0);

    var result: VertexOutput;
    result.normal = (cross(particle2.pos.xyz - particle.pos.xyz, particle1.pos.xyz - particle.pos.xyz) +
                        cross(particle4.pos.xyz - particle.pos.xyz, particle3.pos.xyz - particle.pos.xyz)) / 2.0;
    result.position = mvp_mat.proj * mv_pos;
    result.ec_pos = mv_pos.xyz;
    result.uv = particle.uv_mass.xy;
    result.collision_area = 0.0;
   
    return result;
}

@group(0) @binding(3) var tex: texture_2d<f32>;
@group(0) @binding(4) var tex_sampler: sampler;

const light_color = vec3<f32>(1.0, 1.0, 1.0);
const light_pos = vec3<f32>(-0.0, -0.0, 0.6);
const view_pos = vec3<f32>(0.0, 0.0, 1.0);

@fragment
fn fs_main(vertex: VertexOutput) -> @location(0) vec4<f32> {
    let color: vec4<f32> = textureSample(tex, tex_sampler, vertex.uv);
    var norm = normalize(vertex.normal);
    norm = faceForward(norm, view_pos, norm);

    let light_dir = normalize(light_pos - vertex.ec_pos);
    let diffuse = clamp(abs(dot(norm, light_dir)), 0.5, 1.0) * color.rgb;
    return vec4<f32>(diffuse, color.a);
}
