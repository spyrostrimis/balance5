"""
HD-2D Desert Canyon Approach — v2
Octopath Traveler style: low camera, tilt-shift DoF, warm volumetric haze.
Fixed: wider canyon, better camera placement, much more light.
"""
import bpy
import bmesh
import math
import random
import os
from mathutils import Vector, noise

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

# ─── Clean slate ───
bpy.ops.wm.read_factory_settings(use_empty=True)

OUT_DIR = os.path.join(PROJECT_ROOT, r"render_captures")
os.makedirs(OUT_DIR, exist_ok=True)

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'GPU'
scene.cycles.samples = 256
scene.cycles.use_denoising = True
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.film_transparent = False

prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'CUDA'
prefs.get_devices()
for d in prefs.devices:
    d.use = True

# ─── World: warm desert sky ───
world = bpy.data.worlds.new("DesertWorld")
scene.world = world
wnodes = world.node_tree.nodes
wlinks = world.node_tree.links
wnodes.clear()

sky_tex = wnodes.new('ShaderNodeTexSky')
sky_tex.sky_type = 'HOSEK_WILKIE'
sky_tex.sun_direction = (
    math.cos(math.radians(30)) * math.cos(math.radians(60)),
    math.cos(math.radians(30)) * math.sin(math.radians(60)),
    math.sin(math.radians(30))
)

bg = wnodes.new('ShaderNodeBackground')
bg.inputs['Strength'].default_value = 3.0

vol_scatter = wnodes.new('ShaderNodeVolumeScatter')
vol_scatter.inputs['Density'].default_value = 0.008
vol_scatter.inputs['Color'].default_value = (1.0, 0.93, 0.78, 1.0)
vol_scatter.inputs['Anisotropy'].default_value = 0.7

output = wnodes.new('ShaderNodeOutputWorld')
wlinks.new(sky_tex.outputs['Color'], bg.inputs['Color'])
wlinks.new(bg.outputs['Background'], output.inputs['Surface'])
wlinks.new(vol_scatter.outputs['Volume'], output.inputs['Volume'])


# ─── Materials ───
def make_material(name):
    mat = bpy.data.materials.new(name)
    n = mat.node_tree.nodes
    l = mat.node_tree.links
    n.clear()
    out = n.new('ShaderNodeOutputMaterial')
    bsdf = n.new('ShaderNodeBsdfPrincipled')
    l.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat, n, l, bsdf

# Sand
sand_mat, sn, sl, sbsdf = make_material("DesertSand")
sbsdf.inputs['Roughness'].default_value = 0.95
sbsdf.inputs['Specular IOR Level'].default_value = 0.1

noise_s = sn.new('ShaderNodeTexNoise')
noise_s.inputs['Scale'].default_value = 12.0
noise_s.inputs['Detail'].default_value = 8.0

wave_s = sn.new('ShaderNodeTexWave')
wave_s.wave_type = 'BANDS'
wave_s.inputs['Scale'].default_value = 4.0
wave_s.inputs['Distortion'].default_value = 5.0
wave_s.inputs['Detail'].default_value = 4.0

ramp_s = sn.new('ShaderNodeValToRGB')
ramp_s.color_ramp.elements[0].position = 0.3
ramp_s.color_ramp.elements[0].color = (0.78, 0.6, 0.36, 1.0)
ramp_s.color_ramp.elements[1].position = 0.7
ramp_s.color_ramp.elements[1].color = (0.94, 0.8, 0.54, 1.0)

mix_s = sn.new('ShaderNodeMixRGB')
mix_s.inputs['Fac'].default_value = 0.5
sl.new(noise_s.outputs['Fac'], mix_s.inputs['Color1'])
sl.new(wave_s.outputs['Fac'], mix_s.inputs['Color2'])
sl.new(mix_s.outputs['Color'], ramp_s.inputs['Fac'])
sl.new(ramp_s.outputs['Color'], sbsdf.inputs['Base Color'])

bump_sn = sn.new('ShaderNodeBump')
bump_sn.inputs['Strength'].default_value = 0.25
noise_sb = sn.new('ShaderNodeTexNoise')
noise_sb.inputs['Scale'].default_value = 40.0
noise_sb.inputs['Detail'].default_value = 10.0
sl.new(noise_sb.outputs['Fac'], bump_sn.inputs['Height'])
sl.new(bump_sn.outputs['Normal'], sbsdf.inputs['Normal'])

# Rock
rock_mat, rn, rl_mat, rbsdf = make_material("CanyonRock")
rbsdf.inputs['Roughness'].default_value = 0.88
rbsdf.inputs['Specular IOR Level'].default_value = 0.15

noise_r1 = rn.new('ShaderNodeTexNoise')
noise_r1.inputs['Scale'].default_value = 3.0
noise_r1.inputs['Detail'].default_value = 12.0

voronoi_r = rn.new('ShaderNodeTexVoronoi')
voronoi_r.inputs['Scale'].default_value = 6.0

ramp_r = rn.new('ShaderNodeValToRGB')
ramp_r.color_ramp.elements[0].position = 0.15
ramp_r.color_ramp.elements[0].color = (0.3, 0.22, 0.14, 1.0)
el = ramp_r.color_ramp.elements.new(0.5)
el.color = (0.52, 0.38, 0.25, 1.0)
ramp_r.color_ramp.elements[1].position = 0.85
ramp_r.color_ramp.elements[1].color = (0.7, 0.55, 0.38, 1.0)

mix_r = rn.new('ShaderNodeMixRGB')
mix_r.inputs['Fac'].default_value = 0.4
rl_mat.new(noise_r1.outputs['Fac'], mix_r.inputs['Color1'])
rl_mat.new(voronoi_r.outputs['Distance'], mix_r.inputs['Color2'])
rl_mat.new(mix_r.outputs['Color'], ramp_r.inputs['Fac'])
rl_mat.new(ramp_r.outputs['Color'], rbsdf.inputs['Base Color'])

bump_r = rn.new('ShaderNodeBump')
bump_r.inputs['Strength'].default_value = 0.7
rl_mat.new(voronoi_r.outputs['Distance'], bump_r.inputs['Height'])
rl_mat.new(bump_r.outputs['Normal'], rbsdf.inputs['Normal'])

# Path
path_mat, pn, pl, pbsdf = make_material("DesertPath")
pbsdf.inputs['Roughness'].default_value = 0.97
noise_p = pn.new('ShaderNodeTexNoise')
noise_p.inputs['Scale'].default_value = 25.0
noise_p.inputs['Detail'].default_value = 8.0
ramp_p = pn.new('ShaderNodeValToRGB')
ramp_p.color_ramp.elements[0].position = 0.35
ramp_p.color_ramp.elements[0].color = (0.58, 0.44, 0.3, 1.0)
ramp_p.color_ramp.elements[1].position = 0.65
ramp_p.color_ramp.elements[1].color = (0.72, 0.58, 0.4, 1.0)
pl.new(noise_p.outputs['Fac'], ramp_p.inputs['Fac'])
pl.new(ramp_p.outputs['Color'], pbsdf.inputs['Base Color'])
bump_p = pn.new('ShaderNodeBump')
bump_p.inputs['Strength'].default_value = 0.4
pl.new(noise_p.outputs['Fac'], bump_p.inputs['Height'])
pl.new(bump_p.outputs['Normal'], pbsdf.inputs['Normal'])


# ─── Ground (large sand plane) ───
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
ground = bpy.context.active_object
ground.name = "Ground"
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.subdivide(number_cuts=80)
bpy.ops.object.mode_set(mode='OBJECT')

for v in ground.data.vertices:
    nx = v.co.x * 0.12
    ny = v.co.y * 0.12
    v.co.z += noise.noise(Vector((nx, ny, 0.0))) * 0.6
    v.co.z += noise.noise(Vector((v.co.x * 0.5, v.co.y * 0.5, 1.0))) * 0.08

ground.data.materials.append(sand_mat)
bpy.ops.object.shade_smooth()


# ─── Canyon walls — wider, taller, flanking a broad path ───
def create_wall(name, base_x, y_start, y_end, height, width, seed):
    """Create a long rocky wall along one side of the canyon."""
    length = y_end - y_start
    y_center = (y_start + y_end) / 2.0
    
    bpy.ops.mesh.primitive_cube_add(size=1, location=(base_x, y_center, height / 2.0))
    wall = bpy.context.active_object
    wall.name = name
    wall.scale = (width, length / 2.0, height)
    bpy.ops.object.transform_apply(scale=True)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=25)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    me = wall.data
    random.seed(seed)
    for v in me.vertices:
        # Erode the top edge
        if v.co.z > height * 0.3:
            factor = (v.co.z - height * 0.3) / (height * 0.7)
            n_val = noise.noise(Vector((v.co.x * 0.4 + seed, v.co.y * 0.3, v.co.z * 0.5)))
            v.co.x += n_val * 0.8 * factor
            v.co.z += n_val * 0.6 * factor
        # Surface roughness
        micro = noise.noise(Vector((v.co.x * 1.5 + seed, v.co.y * 1.5, v.co.z * 1.5))) * 0.12
        v.co.x += micro
        v.co.y += micro * 0.5
    
    wall.data.materials.append(rock_mat)
    bpy.ops.object.shade_smooth()
    return wall

# Left wall segments (negative X)
create_wall("LeftWall_Near", -8, -15, 5, 6.0, 4.0, 42)
create_wall("LeftWall_Mid", -9, 3, 20, 8.0, 5.0, 77)
create_wall("LeftWall_Far", -7.5, 18, 30, 7.0, 4.5, 99)

# Right wall segments (positive X)
create_wall("RightWall_Near", 8, -12, 8, 5.5, 3.5, 137)
create_wall("RightWall_Mid", 9.5, 6, 22, 7.5, 5.0, 221)
create_wall("RightWall_Far", 8, 20, 30, 6.5, 4.0, 333)


# ─── Winding path through the canyon ───
path_verts = []
path_width = 3.0
for i in range(50):
    y = -18 + i * 1.0
    x_off = math.sin(y * 0.12) * 2.0
    path_verts.append((x_off - path_width / 2, y, 0.03))
    path_verts.append((x_off + path_width / 2, y, 0.03))

mesh = bpy.data.meshes.new("PathMesh")
obj = bpy.data.objects.new("DesertPath", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
bm_verts = [bm.verts.new(v) for v in path_verts]
for i in range(0, len(bm_verts) - 2, 2):
    try:
        bm.faces.new([bm_verts[i], bm_verts[i+1], bm_verts[i+3], bm_verts[i+2]])
    except:
        pass
bm.to_mesh(mesh)
bm.free()
obj.data.materials.append(path_mat)


# ─── Scattered rocks ───
def create_rock(loc, scale, seed):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.5 * scale, location=loc)
    rock = bpy.context.active_object
    rock.name = f"Rock_{seed}"
    for v in rock.data.vertices:
        d = noise.noise(Vector((v.co.x * 3 + seed, v.co.y * 3, v.co.z * 3)))
        v.co.x += d * 0.15 * scale
        v.co.y += d * 0.12 * scale
        v.co.z += d * 0.1 * scale
    rock.data.materials.append(rock_mat)
    bpy.ops.object.shade_smooth()
    return rock

rock_data = [
    ((-5, -5, 0.2), 1.0, 10), ((-6, 2, 0.3), 0.8, 20),
    ((5, -3, 0.2), 0.9, 30), ((6, 4, 0.25), 0.7, 40),
    ((-5, 8, 0.2), 1.2, 50), ((5.5, 9, 0.3), 0.6, 60),
    ((-4, -10, 0.15), 0.5, 70), ((4.5, -8, 0.2), 0.7, 80),
    # Foreground rocks (will be beautifully blurred by DoF)
    ((-3, -15, 0.4), 1.5, 90), ((4, -16, 0.3), 1.3, 100),
    ((-2, -17, 0.2), 0.6, 105),
    # Far background
    ((-6, 20, 0.3), 1.0, 110), ((7, 22, 0.4), 1.4, 120),
]
for loc, s, sd in rock_data:
    create_rock(loc, s, sd)


# ─── Small desert brush / scrub plants ───
# Simple stretched icospheres with a green-brown tint
brush_mat, bn, blinks, bbsdf = make_material("DesertBrush")
bbsdf.inputs['Roughness'].default_value = 0.95
bbsdf.inputs['Base Color'].default_value = (0.35, 0.38, 0.2, 1.0)

for i in range(20):
    random.seed(i + 1000)
    x = random.uniform(-6, 6)
    y = random.uniform(-12, 18)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.15, location=(x, y, 0.1))
    bush = bpy.context.active_object
    bush.name = f"Brush_{i}"
    bush.scale = (random.uniform(0.8, 1.5), random.uniform(0.8, 1.5), random.uniform(0.4, 0.8))
    for v in bush.data.vertices:
        v.co.z = max(v.co.z, 0)
        d = noise.noise(Vector((v.co.x * 5 + i, v.co.y * 5, v.co.z * 5)))
        v.co.x += d * 0.05
        v.co.y += d * 0.05
    bush.data.materials.append(brush_mat)
    bpy.ops.object.shade_smooth()


# ─── Dust motes (tiny emissive cubes floating in the air) ───
dust_mat_shared, dn, dlnk, dbsdf = make_material("DustMote")
dbsdf.inputs['Base Color'].default_value = (1.0, 0.95, 0.85, 1.0)
dbsdf.inputs['Emission Color'].default_value = (1.0, 0.95, 0.85, 1.0)
dbsdf.inputs['Emission Strength'].default_value = 0.3

for i in range(40):
    random.seed(i + 2000)
    x = random.uniform(-5, 5)
    y = random.uniform(-5, 15)
    z = random.uniform(0.3, 4.0)
    bpy.ops.mesh.primitive_cube_add(size=random.uniform(0.015, 0.04), location=(x, y, z))
    dust = bpy.context.active_object
    dust.name = f"Dust_{i}"
    dust.data.materials.append(dust_mat_shared)


# ─── Lighting ───
# Main sun — coming from upper-right-back, casting long shadows into the canyon
bpy.ops.object.light_add(type='SUN', location=(10, 10, 15))
sun = bpy.context.active_object
sun.name = "DesertSun"
sun.data.energy = 6.0
sun.data.color = (1.0, 0.94, 0.8)
sun.data.angle = math.radians(1.5)
sun.rotation_euler = (math.radians(45), math.radians(-20), math.radians(30))

# Warm fill from below-left (bounce light from sand)
bpy.ops.object.light_add(type='AREA', location=(-5, 0, 1.5))
fill = bpy.context.active_object
fill.name = "FillWarm"
fill.data.energy = 80.0
fill.data.color = (1.0, 0.88, 0.7)
fill.data.size = 12.0
fill.rotation_euler = (math.radians(85), 0, math.radians(15))

# Rim/key light for the path ahead — creates the "light at end of canyon" effect
bpy.ops.object.light_add(type='AREA', location=(0, 20, 5))
rim = bpy.context.active_object
rim.name = "RimLight"
rim.data.energy = 150.0
rim.data.color = (1.0, 0.95, 0.82)
rim.data.size = 10.0
rim.rotation_euler = (math.radians(120), 0, 0)


# ─── Camera (Octopath HD-2D low angle) ───
# Camera looking up the path, low to the ground
bpy.ops.object.camera_add(location=(0.5, -16, 3.0))
camera = bpy.context.active_object
camera.name = "HD2D_Camera"
scene.camera = camera

# Angle: mostly horizontal but slightly looking up-and-forward
camera.rotation_euler = (math.radians(78), 0, math.radians(2))

cam = camera.data
cam.lens = 28  # Wider lens for the panoramic canyon feel
cam.sensor_width = 36

# Tilt-shift Depth of Field
cam.dof.use_dof = True
cam.dof.focus_distance = 16.0  # Focus on the mid-ground path
cam.dof.aperture_fstop = 1.8   # Very shallow for tilt-shift miniature effect

cam.clip_start = 0.1
cam.clip_end = 200


# ─── Render ───
render_path = os.path.join(OUT_DIR, "desert_approach_rpg_hd2d_v2.png")
scene.render.filepath = render_path
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'

print(f"Rendering HD-2D desert canyon v2 to: {render_path}")
bpy.ops.render.render(write_still=True)
print("Render complete!")

blend_path = os.path.join(PROJECT_ROOT, r"assets\models\desert_approach_rpg.blend")
os.makedirs(os.path.dirname(blend_path), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"Blend saved: {blend_path}")
