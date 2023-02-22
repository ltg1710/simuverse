use crate::{
    noise::{create_gradient_buf, create_permulation_buf},
    util::BufferObj,
    Simulator,
};

use super::sphere_display::SphereDisplay;

pub struct TextureSimulator {
    uniform_data: super::TexGeneratorParams,
    uniform_buf: BufferObj,
    sphere: SphereDisplay,
    regenerate_tex: bool,
}

impl TextureSimulator {
    pub fn new(app: &app_surface::AppSurface) -> TextureSimulator {
        let uniform_data = super::TexGeneratorParams::default();
        let uniform_buf = BufferObj::create_uniform_buffer(&app.device, &uniform_data, None);
        let permulation_buf = create_permulation_buf(&app.device);
        let gradient_buf = create_gradient_buf(&app.device);

        let sphere = SphereDisplay::new(app, &uniform_buf, &permulation_buf, &gradient_buf);

        TextureSimulator {
            uniform_data,
            uniform_buf,
            sphere,
            regenerate_tex: true,
        }
    }
}

impl Simulator for TextureSimulator {
    fn update_by(
        &mut self,
        app: &app_surface::AppSurface,
        control_panel: &mut crate::ControlPanel,
    ) {
        let setting = &control_panel.noise_setting;
        self.uniform_data.ty = setting.simu_ty.unwrap();
        let bg_color = setting.back_color;
        let front_color = setting.front_color;
        self.uniform_data.bg_color = [bg_color[0], bg_color[1], bg_color[2], 1.0];
        self.uniform_data.front_color = [front_color[0], front_color[1], front_color[2], 1.0];
        self.uniform_data.noise_scale = setting.noise_scale;
        self.uniform_data.octave = setting.octave;
        self.uniform_data.lacunarity = setting.lacunarity;
        self.uniform_data.gain = setting.gain;
        app.queue.write_buffer(
            &self.uniform_buf.buffer,
            0,
            bytemuck::bytes_of(&self.uniform_data),
        );
    }

    fn update_workgroup_count(
        &mut self,
        _app: &app_surface::AppSurface,
        _workgroup_count: (u32, u32, u32),
    ) {
    }

    fn compute(&mut self, _encoder: &mut wgpu::CommandEncoder) {}

    fn draw_by_rpass<'b, 'a: 'b>(
        &'a mut self,
        app: &app_surface::AppSurface,
        rpass: &mut wgpu::RenderPass<'b>,
        _setting: &mut crate::SettingObj,
    ) {
        if self.regenerate_tex {
            self.regenerate_tex = false;
            self.sphere.gen_texture(app);
        }
        self.sphere.draw_by_pass(app, rpass);
    }
}
