@group(0) @binding(0) var<storage, read> permutation: array<vec4<i32>>;
@group(0) @binding(1) var<storage, read> gradient: array<vec4<f32>>;
@group(0) @binding(2) var tex: texture_storage_3d<rgba8unorm, write>;


fn fade(t: vec3<f32>) -> vec3<f32> {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

fn perm(x: i32, y: i32) -> vec4<i32> {
    return permutation[y * 256 + x];
}

fn grad(x: i32, p: vec3<f32>) -> f32 {
    return dot(gradient[x & 15].xyz, p);
}

fn lerp(a: f32, b: f32, w: f32) -> f32 {
    return a + (b - a) * w;
}

fn lerp3(a: vec3<f32>, b: vec3<f32>, w: f32) -> vec3<f32> {
    return a + (b - a) * w;
}

fn noise(pos: vec3<f32>) -> f32 {
    let P: vec3<i32> = vec3<i32>(floor(pos)) % vec3<i32>(256);  
    let fract_pos = fract(pos);  
    let f: vec3<f32> = fade(fract_pos);      
    let hash = (perm(P.x, P.y) + P.z) % vec4<i32>(256);

    return lerp(lerp(lerp(
            grad(hash.x, fract_pos), 
            grad(hash.z, fract_pos + vec3<f32>(-1.0, 0.0, 0.0)), f.x),           
        lerp(
            grad(hash.y, fract_pos + vec3<f32>(0.0, -1.0, 0.0)), 
            grad(hash.w, fract_pos + vec3<f32>(-1.0, -1.0, 0.0)), f.x), f.y),      
        lerp(lerp(
            grad(hash.x + 1, fract_pos + vec3<f32>(0.0, 0.0, -1.0)), 
            grad(hash.z + 1, fract_pos + vec3<f32>(-1.0, 0.0, -1.0)), f.x),           
        lerp(
            grad(hash.y + 1, fract_pos + vec3<f32>(0.0, -1.0, -1.0)), 
            grad(hash.w + 1, fract_pos + vec3<f32>(-1.0, -1.0, -1.0)), f.x), f.y), f.z); 
}

fn turbulence(pos: vec3<f32>, octaves: i32, lacunarity: f32, gain: f32) -> f32 {	
  var sum: f32 = 0.0;
  var scale: f32 = 1.0;
  var totalgain: f32 = 1.0;
  for(var i = 0; i < octaves; i = i + 1){
    sum += totalgain * noise(pos * scale);
    scale *= lacunarity;
    totalgain *= gain;
  }
  return abs(sum);
}

@compute @workgroup_size(8, 8, 8)
fn cs_main(@builtin(global_invocation_id) gid: vec3<u32>) {
    let p = vec3<f32>(gid.xyz) / 8.0 ; 
    let val = noise(p);
    
    textureStore(tex, vec3<i32>(gid.xyz), vec4<f32>(val, val * 0.5 + 0.5, val * 0.25 + 0.5, val * 0.125 + 0.5));
}

