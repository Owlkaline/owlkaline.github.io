
// Import the standard 2d mesh uniforms and set their bind groups
#import bevy_sprite::mesh2d_functions
#import bevy_sprite::{
    mesh2d_functions as mesh_functions,
    mesh2d_view_bindings::{view, globals},
}

const TAU:f32 =  6.28318530718;
const SHINE_ANGLE: f32 = 45.0;
const SPLAT_MULT: f32 = 2.5;//8.0;

const EFFECT: f32 = -1.1;//-1.1; // -1.0 is BARREL, 0.1 is PINCUSHION. For planets, ideally -1.1 to -4.
const EFFECT_SCALE: f32 = 0.85; // Play with this to slightly vary the results.
const MANUAL_AMOUNT: f32 = 0.95; // Higher value = more crop.

struct Vertex {
    @builtin(instance_index) instance_index: u32,
#ifdef VERTEX_POSITIONS
    @location(0) position: vec3<f32>,
#endif
#ifdef VERTEX_NORMALS
    @location(1) normal: vec3<f32>,
#endif
#ifdef VERTEX_UVS
    @location(2) uv: vec2<f32>,
#endif
#ifdef VERTEX_TANGENTS
    @location(3) tangent: vec4<f32>,
#endif
#ifdef VERTEX_COLORS
    @location(4) color: vec4<f32>,
#endif
};

struct VertexOutput {
    // this is `clip position` when the struct is used as a vertex stage output
    // and `frag coord` when used as a fragment stage input
    @builtin(position) position: vec4<f32>,
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    #ifdef VERTEX_TANGENTS
    @location(3) world_tangent: vec4<f32>,
    #endif
    #ifdef VERTEX_COLORS
    @location(4) color: vec4<f32>,
    #endif
}

@vertex
fn vertex(vertex: Vertex) -> VertexOutput {
    var out: VertexOutput;
    out.uv = vertex.uv;

    var world_from_local = mesh_functions::get_world_from_local(vertex.instance_index);
    out.world_position = mesh_functions::mesh2d_position_local_to_world(
        world_from_local,
        vec4<f32>(vertex.position, 1.0)
    );
    out.position = mesh_functions::mesh2d_position_world_to_clip(out.world_position);

#ifdef VERTEX_NORMALS
    out.world_normal = mesh_functions::mesh2d_normal_local_to_world(vertex.normal, vertex.instance_index);
#endif

#ifdef VERTEX_TANGENTS
    out.world_tangent = mesh_functions::mesh2d_tangent_local_to_world(
        world_from_local,
        vertex.tangent
    );
#endif

#ifdef VERTEX_COLORS
    out.color = vertex.color;
#endif
    return out;
}

// we can import items from shader modules in the assets folder with a quoted path
//#import "shaders/custom_material_import.wgsl"::COLOR_MULTIPLIER

const COLOR_MULTIPLIER: vec4<f32> = vec4<f32>(1.0, 1.0, 1.0, 0.5);

@group(2) @binding(0) var<uniform> material_colour: vec4<f32>;
@group(2) @binding(1) var base_colour_texture: texture_2d<f32>;
@group(2) @binding(2) var base_colour_sampler: sampler;

// Created by greenbird10
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0

fn hash(p: vec2<f32>) -> f32 {
	return 0.5*(
    sin(dot(p, vec2(271.319, 413.975)) + 1217.13*p.x*p.y)
    ) + 0.5;
}
//
fn noise(p1: vec2<f32>) -> f32 {
  var w: vec2<f32> = fract(p1);
  w = w * w * (3.0 - 2.0*w);
  var p = floor(p1);
  return mix(
    mix(hash(p+vec2(0,0)), hash(p+vec2(1,0)), w.x),
    mix(hash(p+vec2(0,1)), hash(p+vec2(1,1)), w.x), w.y);
}
//
//// wave octave inspiration
//// Alexander Alekseev - Seascape
//// https://www.shadertoy.com/view/Ms2SD1
fn map_octave(uv_in: vec2<f32>) -> f32 {
  var uv = (uv_in + noise(uv_in)) / 2.5;
  uv = vec2(uv.x*0.6-uv.y*0.8, uv.x*0.8+uv.y*0.6);
  var uvsin: vec2<f32> = 1.0 - abs(sin(uv));
  var uvcos: vec2<f32> = abs(cos(uv));
  uv = mix(uvsin, uvcos, uvsin);
  var val: f32 = 1.0 - pow(uv.x * uv.y, 0.65);
  return val;
}
//
fn map(p: vec3<f32>) -> f32 {
  var uv: vec2<f32> = p.xz + globals.time/2.;
  var amp: f32 = 0.6;
  var freq = 2.0;
  var val = 0.0;
  for(var i = 0; i < 3; i+=1) {
    val += map_octave(uv) * amp;
    amp *= 0.3;
    uv *= freq;
    // uv = vec2(uv.x*0.6-uv.y*0.8, uv.x*0.8+uv.y*0.6);
  }
  uv = p.xz - 1000. - globals.time/2.;
  amp = 0.6;
  freq = 2.0;
  for(var i = 0; i < 3; i+=1) {
    val += map_octave(uv) * amp;
    amp *= 0.3;
    uv *= freq;
    // uv = vec2(uv.x*0.6-uv.y*0.8, uv.x*0.8+uv.y*0.6);
  }
  return val + 3.0 - p.y;
}
//
fn getNormal(p: vec3<f32>, resolution: vec2<f32>) -> vec3<f32> {
  var eps: f32 = 1./resolution.x;
  var px: vec3<f32> = p + vec3(eps, 0, 0);
  var pz: vec3<f32> = p + vec3(0, 0, eps);
  return normalize(vec3(map(px),eps,map(pz)));
}
//
//// raymarch inspiration
//// Alexander Alekseev - Seascape
//// https://www.shadertoy.com/view/Ms2SD1
////var raymarch(vec3 ro, vec3 rd, out vec3 outP, out float outT) -> f32 {
fn raymarch(ro: vec3<f32>, rd: vec3<f32>, outP: vec3<f32>, outT: f32, resolution: vec2<f32>) -> vec3<u32> {
    var l: f32 = 0.;
    var r = 26.;
    var i: i32 = 0;
    var steps = 16;
    var dist: f32 = 1000000.;
    for(i = 0; i < steps; i+=1) {
        var mid: f32 = (r+l)/2.;
        var mapmid: f32 = map(ro + rd*mid);
        dist = min(dist, abs(mapmid));
        if(mapmid > 0.) {
        	l = mid;
        }
        else {
        	r = mid;
        }
        if(r - l < 1./resolution.x) {
          break;
        }
    }

    var out_p = ro + rd*l;
    var out_t = l;

    var a = pack2x16float(out_p.xy);
    var b = pack2x16float(vec2(out_p.z, out_t));
    var c = pack2x16float(vec2(dist, dist));

    return vec3(a,b,c);
  //  *outP = ro + rd*l;
  //  *outT = l;
  //  return dist;
}
//
fn fbm(n_in: vec2<f32>) -> f32 {
  var n = n_in;
	var total: f32 = 0.0;
	var amplitude: f32 = 1.0;
	for (var i: i32 = 0; i < 5; i++) {
		total += noise(n) * amplitude;
		n += n;
		amplitude *= 0.4;
	}
	return total;
}
//
fn lightShafts(st_in: vec2<f32>) -> f32 {
    var st = st_in;
    var angle: f32 = -0.2;
    var _st: vec2<f32> = st;
    var t: f32 = globals.time / 16.;
    st = vec2(st.x * cos(angle) - st.y * sin(angle),
              st.x * sin(angle) + st.y * cos(angle));
    var val: f32 = fbm(vec2(st.x*2. + 200. + t, st.y/4.));
    val += fbm(vec2(st.x*2. + 200. - t, st.y/4.));
    val = val / 3.;
    var mask: f32 = pow(clamp(1.0 - abs(_st.y-0.15), 0., 1.)*0.49 + 0.5, 2.0);
    mask *= clamp(1.0 - abs(_st.x+0.2), 0., 1.) * 0.49 + 0.5;
	return pow(val*mask, 2.0);
}
//
fn bubble(uv: vec2<f32>, scale: f32) -> vec2<f32> {
    if (uv.y > 0.2) {
      return vec2(0.);
    }
    var t: f32 = globals.time/4.;
    var st: vec2<f32> = uv * scale;
    var _st: vec2<f32> = floor(st);
    var bias: vec2<f32> = vec2(0., 4. * sin(_st.x*128. + t));
    var mask: f32 = smoothstep(0.1, 0.2, -cos(_st.x*128. + t));
    st += bias;
    var _st_: vec2<f32> = floor(st);
    st = fract(st);
    var size: f32 = noise(_st_)*0.07+0.01;
    var pos: vec2<f32> = vec2(noise(vec2(t, _st_.y*64.1)) * 0.8 + 0.1, 0.5);
    if (length(st.xy - pos) < size) {
      return (st + pos) * vec2(.1, .2) * mask;
    }
    return vec2(0.);
}

@fragment
fn fragment(mesh: VertexOutput) -> @location(0) vec4<f32> {
    let resolution = view.viewport.zw;//vec2(ocean_config.width, ocean_config.height);

    var ro: vec3<f32> = vec3(0.,0.,2.);
    var lightPos: vec3<f32> = vec3(8, 3, -3);
    var lightDir: vec3<f32> = normalize(lightPos - ro);

    //var uv = mesh.uv;
    //uv.y = -uv.y;
    //uv = (-resolution.xy+4*uv) / resolution.y;
    //uv = (-resolution.xy + 2.0*uv) / resolution.y;
    var uv = (mesh.uv.xy * 2.0) - 1.0;
    uv.x *= resolution.x / resolution.y;

    uv.y *= 0.5;
    uv.x *= 0.45;
    uv += bubble(uv, 12.0) + bubble(uv, 24.0);

    var rd: vec3<f32> = normalize(vec3(uv, -1.));
    var hitPos: vec3<f32> = vec3(0.0);
    var hitT: f32 = 0.0;

    var seaColor: vec3<f32> = vec3(11,82,142)/255.;
    var color: vec3<f32>;

    // waves
    var abc: vec3<u32> = raymarch(ro, rd, hitPos, hitT, resolution);
    var a = unpack2x16float(abc.x);
    var b = unpack2x16float(abc.y);
    var c = unpack2x16float(abc.z);

    hitPos.x = a.x;
    hitPos.y = a.y;
    hitPos.z = b.x;
    hitT = b.y;
    var dist = c.x;

    var diffuse: f32 = dot(getNormal(hitPos, resolution), rd) * 0.5 + 0.5;
    color = mix(seaColor, vec3(15,120,152)/255., diffuse);
    color += pow(diffuse, 12.0);

    // refraction
    var ref_b: vec3<f32> = normalize(refract(hitPos-lightPos, getNormal(hitPos, resolution), 0.05));
    var refraction: f32 = clamp(dot(ref_b, rd), 0., 1.0);
    color += vec3(245,250,220)/255. * 0.6 * pow(refraction, 1.5);

    var col = vec3(0.);
    col = mix(color, seaColor, pow(clamp(0., 1., dist), 0.2)); // glow edge
    col += vec3(225,230,200)/255. * lightShafts(uv); // light shafts

    // tone map
    col = (col*col + sin(col))/vec3(1.8, 1.8, 1.9);

    // vignette
    // inigo quilez - Stop Motion Fox
    // https://www.shadertoy.com/view/3dXGWB
    var q: vec2<f32> = mesh.uv / resolution.xy;
    col *= 0.7+0.3*pow(16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.2);

    return vec4(col, 0.9);

    //var colour = textureSample(base_colour_texture, base_colour_sampler, uv);


   // return mat_colour * pixel_colour + vec4(fract(col), 0.0)*has_shine;
}
