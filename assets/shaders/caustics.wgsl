//#import bevy_sprite::mesh2d_vertex_output::VertexOutput
#import bevy_pbr::mesh_view_bindings::globals
#import bevy_render::view::View
#import bevy_pbr::forward_io::VertexOutput
#import bevy_pbr::mesh_bindings::mesh
#import bevy_pbr::utils::coords_to_viewport_uv


//#import shadplay::shader_utils::common NEG_HALF_PI, shader_toy_default, rotate2D, TAU
const PI:f32  =         3.14159265359;
const HALF_PI =         1.57079632679;
const NEG_HALF_PI =    -1.57079632679;
const NEG_QUARTER_PI = -0.78539816339;
const QUARTER_PI =     -0.78539816339;
const TAU:f32 =         6.28318530718;

/// Clockwise by `theta`
fn rotate2D(theta: f32) -> mat2x2<f32> {
    let c = cos(theta);
    let s = sin(theta);
    return mat2x2<f32>(c, s, -s, c);
}

/// This is the default (and rather pretty) shader you start with in ShaderToy
fn shader_toy_default(t: f32, uv: vec2f) -> vec3f {
    var col = vec3f(0.0);
    let v = vec3(t) + vec3(uv.xyx) + vec3(0., 2., 4.);
    return 0.5 + 0.5 * cos(v);
}

@group(0) @binding(0) var<uniform> view: View;
@group(2) @binding(100) var<uniform> colour: vec4<f32>;
@group(2) @binding(101) var texture: texture_2d<f32>;
@group(2) @binding(102) var texture_sampler: sampler;

const MAX_ITER: i32 = 3;
const SPEED:f32 = 1.0;

@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
  //return vec4(1.0, 0.0, 0.0, 1.0);
    let time: f32 = globals.time * 0.5 + 23.0;
   // var a = view.viewport;
    let viewport_uv = coords_to_viewport_uv(in.position.xy, view.viewport);
  //  var uv: vec2<f32> = in.uv;
    var uv: vec2<f32> = viewport_uv*2.0;

    // Tiling calculation
    var p: vec2<f32>;
    // Note: Choose one of the following two lines based on whether SHOW_TILING is defined or not
    // p = uv * TAU * 2.0 % TAU - 250.0;  // show TILING
    p = uv * TAU % TAU - 250.0;           // hide TILING

    var i: vec2<f32> = vec2<f32>(p); // iterator position
    var c: f32 = 1.0; // colour intensity
    let inten: f32 = 0.005; // Intensity factor

    for (var n: i32 = 0; n < MAX_ITER; n = n + 1) {
        let t: f32 = time * (1.0 - (3.5 / f32(n + 1)));
        i = p + vec2<f32>(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(vec2<f32>(p.x / (sin(i.x + t) / inten), p.y / (cos(i.y + t) / inten)));
    }

    // c = colour intensity
    c /= f32(MAX_ITER);
    c = 1.17 - pow(c, 1.4);
    var colour: vec3<f32> = vec3<f32>(pow(abs(c), 8.0));
    colour = clamp(colour + vec3<f32>(0.0, 0.35, 0.5), vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(1.0, 1.0, 1.0));


    // Show grid:
    // let pixel: vec2<f32> = vec2<f32>(2.0) / view.viewport.zw;
    // uv *= 2.0;
    // let flash: f32 = floor(globals.time * 0.5 % 2.0);
    // let first: vec2<f32> = step(pixel, uv) * flash;
    // uv = step(fract(uv), pixel);
    // colour = mix(colour, vec3<f32>(1.0, 1.0, 0.0), (uv.x + uv.y) * first.x * first.y);
var texture = textureSample(texture, texture_sampler, in.uv);

    return vec4(mix(colour, texture.rgb, 0.90), 1.0); //vec4<f32>(colour, 1.0);
}
