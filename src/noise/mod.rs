//! #Perlin Simplex Noise
//!
//! 相关论文：http://staffwww.itn.liu.se/%7Estegu/simplexnoise/simplexnoise.pdf

use std::vec::Vec;

mod d3_noise_texture;
pub use d3_noise_texture::D3NoiseTexture;

mod sphere_display;

mod texture_simulator;
pub use texture_simulator::TextureSimulator;

#[repr(C)]
#[derive(Default, Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct TexGeneratorParams {
    pub bg_color: [f32; 4],
    pub front_color: [f32; 4],
    pub noise_scale: f32,
    pub octave: i32,
    pub lacunarity: f32,
    pub gain: f32,
    pub ty: i32,
    pub _padding: [i32; 3],
}

pub(crate) fn is_the_same_color(lh: [f32; 4], rh: [f32; 4]) -> bool {
    for i in 0..4 {
        if !is_the_same_f32(lh[i], rh[i]) {
            return false;
        }
    }
    true
}

pub(crate) fn is_the_same_f32(l: f32, r: f32) -> bool {
    if (l - r).abs() > 0.00001 {
        return false;
    }
    true
}

static PERMULATION: [i32; 512] = [
    151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69,
    142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219,
    203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
    74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230,
    220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76,
    132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173,
    186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206,
    59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163,
    70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232,
    178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162,
    241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204,
    176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141,
    128, 195, 78, 66, 215, 61, 156, 180, 151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194,
    233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234,
    75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174,
    20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83,
    111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25,
    63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188,
    159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147,
    118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170,
    213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253,
    19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193,
    238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31,
    181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
    222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180,
];

static GRADIENT: [[f32; 4]; 16] = [
    [1.0, 1.0, 0.0, 0.0],
    [-1.0, 1.0, 0.0, 0.0],
    [1.0, -1.0, 0.0, 0.0],
    [-1.0, -1.0, 0.0, 0.0],
    [1.0, 0.0, 1.0, 0.0],
    [-1.0, 0.0, 1.0, 0.0],
    [1.0, 0.0, -1.0, 0.0],
    [-1.0, 0.0, -1.0, 0.0],
    [0.0, 1.0, 1.0, 0.0],
    [0.0, -1.0, 1.0, 0.0],
    [0.0, 1.0, -1.0, 0.0],
    [0.0, -1.0, -1.0, 0.0],
    [1.0, 1.0, 0.0, 0.0],
    [0.0, -1.0, 1.0, 0.0],
    [-1.0, 1.0, 0.0, 0.0],
    [0.0, -1.0, -1.0, 0.0],
];

pub fn create_permulation_buf(device: &wgpu::Device) -> crate::util::BufferObj {
    let mut list: Vec<[i32; 4]> = vec![];
    // column
    for y in 0..256 {
        // row
        for x in 0..256 {
            // hash coordinates for 6 of th 8 cube corner
            let a = PERMULATION[x] + y;
            let aa = PERMULATION[a as usize];
            let ab = PERMULATION[a as usize + 1];
            let b = PERMULATION[x + 1] + y;
            let ba = PERMULATION[b as usize];
            let bb = PERMULATION[b as usize + 1];
            list.push([aa, ab, ba, bb]);
        }
    }
    let mut buf = crate::util::BufferObj::create_storage_buffer(device, &list, None);
    buf.read_only = true;
    buf
}

pub fn create_gradient_buf(device: &wgpu::Device) -> crate::util::BufferObj {
    let mut buf = crate::util::BufferObj::create_storage_buffer(device, &GRADIENT, None);
    buf.read_only = true;
    buf
}
