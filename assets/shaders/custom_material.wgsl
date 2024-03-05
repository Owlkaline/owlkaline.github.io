#import bevy_sprite::mesh2d_vertex_output::VertexOutput

//layout(push_constant) uniform Name {..

@group(2) @binding(0) var<uniform> outline_colour: vec4<f32>;
@group(2) @binding(1) var<uniform> overlay_colour: vec4<f32>;
@group(2) @binding(2) var colour_texture: texture_2d<f32>;
@group(2) @binding(3) var colour_sampler: sampler;
@group(2) @binding(4) var pattern_texture: texture_2d<f32>;

fn not(value: f32) -> f32 {
  return 1.0 - value;
}

@fragment
fn fragment(mesh: VertexOutput) -> @location(0) vec4<f32> {
  var texture = textureSample(colour_texture, colour_sampler, mesh.uv);
  let pattern_texture = textureSample(pattern_texture, colour_sampler, mesh.uv);
  

  let uv = mesh.uv.xy;
  let width = 0.05;

  let left_outline_uv = uv - vec2(width, 0.0);
  let right_outline_uv = uv + vec2(width, 0.0);
  let top_outline_uv = uv - vec2(0.0, width);
  let bottom_outline_uv = uv + vec2(0.0, width);

  let left_alpha = textureSample(colour_texture, colour_sampler, left_outline_uv).a;
  let right_alpha = textureSample(colour_texture, colour_sampler, right_outline_uv).a;
  let top_alpha = textureSample(colour_texture, colour_sampler, top_outline_uv).a;
  let bottom_alpha = textureSample(colour_texture, colour_sampler, bottom_outline_uv).a;

  let outline_total_alpha = left_alpha + right_alpha + top_alpha + bottom_alpha;

  var has_texture = texture.a;
  let has_outline = outline_colour.a;
  var has_overlay = overlay_colour.a;
  var overlay_has_texture = not(has_texture);
  let discard_low_value_pattern = 1.0; //step(pattern_texture.r, 0.2); // 0.0 is discard

  let outline_with_noise = pattern_texture.r * outline_colour.rgb;

  var overlay_colour = overlay_colour;
  if overlay_colour.a < 0.0 {
    has_overlay = 1.0;
    overlay_colour.a = 1.0;
    overlay_has_texture = 1.0;
  }


  let base_colour = has_texture*texture + 
                    has_overlay*has_texture*overlay_colour + 
                    has_outline*overlay_has_texture*discard_low_value_pattern*vec4(outline_with_noise, (1.0 - texture.a) * outline_total_alpha);

  return base_colour;
}
