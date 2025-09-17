use {
    anyhow::{Context, Result},
    winit::{
        event::{Event, WindowEvent},
        event_loop::{ControlFlow, EventLoop},
        window::{Window, WindowBuilder}
    }
};

mod render;

const WIDTH: u32 = 1280;
const HEIGHT: u32 = 720;

async fn connect_to_gpu(window: &Window) -> Result<(wgpu::Device, wgpu::Queue, wgpu::Surface)> {
    use wgpu::TextureFormat::{Bgra8Unorm, Rgba8Unorm};

    let instance = wgpu::Instance::default();

    let surface = instance.create_surface(window)?;

    let adapter = instance
        .request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            force_fallback_adapter: false,
            compatible_surface: Some(&surface)
        })
        .await
        .context("failed to find compatible adapter")?;

    let (device, queue) = adapter
        .request_device(&wgpu::DeviceDescriptor::default())
        .await
        .context("failed to create logical device")?;

    let caps = surface.get_capabilities(&adapter);
    let format = caps
        .formats
        .into_iter()
        .find(|it| matches!(it, Rgba8Unorm | Bgra8Unorm))
        .context("could not find preferred texture format")?;

    let size = window.inner_size();
    let config = wgpu::SurfaceConfiguration {
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
        format,
        width: size.width,
        height: size.height,
        present_mode: wgpu::PresentMode::AutoVsync,
        alpha_mode: caps.alpha_modes[0],
        view_formats: vec![],
        desired_maximum_frame_latency: 3
    };
    surface.configure(&device, &config);

    Ok((device, queue, surface))
}

#[pollster::main]
async fn main() -> Result<()> {
    let event_loop = EventLoop::new()?;

    let window_size = winit::dpi::PhysicalSize::new(WIDTH, HEIGHT);
    let window = WindowBuilder::new()
        .with_inner_size(window_size)
        .with_resizable(false)
        .with_title("Rustracer".to_string())
        .build(&event_loop)?;

    let (device, queue, surface) = connect_to_gpu(&window).await?;
    let renderer = render::PathTracer::new(device, queue);

    event_loop.run(|event, control_handle| {
        control_handle.set_control_flow(ControlFlow::Poll);
        if let Event::WindowEvent { event, .. } = event {
            match event {
                WindowEvent::CloseRequested => control_handle.exit(),
                WindowEvent::RedrawRequested => {
                    let frame: wgpu::SurfaceTexture = surface
                        .get_current_texture()
                        .expect("failed to get current texture");

                    let render_target = frame
                        .texture
                        .create_view(&wgpu::TextureViewDescriptor::default());

                    renderer.render_frame(&render_target);

                    frame.present();
                    window.request_redraw();
                },
                _ => ()
            };
        };
    })?;

    Ok(())
}
