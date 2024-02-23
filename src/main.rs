mod ray;

use std::io::{ stderr, Write };
use std::path::Path;

use image::{ RgbImage, Rgb, imageops };
use nalgebra::Vector3;

use ray::Ray;

fn ray_colour(r: &Ray) -> Vector3<f32> {
    let unit_direction = r.direction().normalize();
    let t = 0.5 * (unit_direction.y + 1.0);
    (1.0 - t) * Vector3::new(1.0, 1.0, 1.0) + t * Vector3::new(0.5, 0.7, 1.0)
}

fn main() {
    const IMAGE_WIDTH: u32 = 1280;
    const IMAGE_HEIGHT: u32 = 720;

    let mut img = RgbImage::new(IMAGE_WIDTH, IMAGE_HEIGHT);

    const ASPECT_RATIO: f32 = (IMAGE_WIDTH as f32) / (IMAGE_HEIGHT as f32);

    let viewport_height = 2.0;
    let viewport_width = viewport_height * ASPECT_RATIO;
    let focal_length = 1.0;

    let origin = Vector3::new(0.0, 0.0, 0.0);
    let horizontal = Vector3::new(viewport_width, 0.0, 0.0);
    let vertical = Vector3::new(0.0, viewport_height, 0.0);
    let depth = Vector3::new(0.0, 0.0, focal_length);
    let lower_left_corner = origin - horizontal / 2.0 - vertical / 2.0 - depth;

    for j in 0..IMAGE_HEIGHT {
        eprint!("\rscanlines remaining: {:3}", IMAGE_HEIGHT - j - 1);
        stderr().flush().unwrap();

        for i in 0..IMAGE_WIDTH {
            let u = (i as f32) / ((IMAGE_WIDTH - 1) as f32);
            let v = (j as f32) / ((IMAGE_HEIGHT - 1) as f32);

            let r = Ray::new(
                origin,
                lower_left_corner + u * horizontal + v * vertical - origin
            );

            let pixel_colour = ray_colour(&r);

            let ir = (255.0 * pixel_colour.x) as u8;
            let ig = (255.0 * pixel_colour.y) as u8;
            let ib = (255.0 * pixel_colour.z) as u8;

            img.put_pixel(i, j, Rgb([ir, ig, ib]));
        }
    }

    eprintln!("\ndone");

    imageops::flip_vertical_in_place(&mut img);
    img.save(Path::new("image.png")).expect("export image");
}
