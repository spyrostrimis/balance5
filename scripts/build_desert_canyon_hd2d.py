"""
Build a desert canyon approach scene in Blender for the HD-2D RPG view.
Octopath Traveler style: low camera angle, tilt-shift DoF, volumetric light.
Desert theme: sandy canyon walls, narrow winding path, scattered rocks.
"""
import bpy
import bmesh
import math
import random
import os
from mathutils import Vector, noise

# ─── Clean slate ───
bpy.ops.wm.read_factory_settings(use_empty=True)

# ─── Output paths ───
OUT_DIR = r"d:\Games\Balance5\assets\textures\maps"
RENDER_DIR = r"d:\Games\Balance5\render_captures"
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(RENDER_DIR, exist_ok=True)

# ─── Scene setup ───
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'GPU'
scene.cycles.samples = 256
scene.cycles.use_denoising = True
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.film_transparent = False

# Enable GPU
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'CUDA'
prefs.get_devices()
for d in prefs.devices:
    d.use = True

# ─── World: warm desert sky with volumetrics ───
world = bpy.data.worlds.new("DesertWorld")
scene.world = world
nodes = world.node_tree.nodes
links = world.node_tree.links
nodes.clear()

# Sky texture
sky_tex = nodes.new('ShaderNodeTexSky')
sky_tex.sky_type = 'HOSEK_WILKIE'
sky_tex.sun_direction = (
    math.cos(math.radians(25)) * math.cos(math.radians(45)),
    math.cos(math.radians(25)) * math.sin(math.radians(45)),
    math.sin(math.radians(25))
)

bg = nodes.new('ShaderNodeBackground')
bg.inputs['Strength'].default_value = 2.5

# Volume scatter for atmospheric haze
vol_scatter = nodes.new('ShaderNodeVolumeScatter')
vol_scatter.inputs['Density'].default_value = 0.015
vol_scatter.inputs['Color'].default_value = (1.0, 0.92, 0.75, 1.0)  # warm sandy haze
vol_scatter.inputs['Anisotropy'].default_value = 0.6

output = nodes.new('ShaderNodeOutputWorld')

links.new(sky_tex.outputs['Color'], bg.inputs['Color'])
links.new(bg.outputs['Background'], output.inputs['Surface'])
links.new(vol_scatter.outputs['Volume'], output.inputs['Volume'])


# ─── Materials ───

def create_sand_material():
    mat = bpy.data.materials.new("DesertSand")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 0.95
    bsdf.inputs['Specular IOR Level'].default_value = 0.1
    
    # Sand color with noise variation
    noise_tex = nodes.new('ShaderNodeTexNoise')
    noise_tex.inputs['Scale'].default_value = 15.0
    noise_tex.inputs['Detail'].default_value = 8.0
    noise_tex.inputs['Roughness'].default_value = 0.7
    
    # Wave texture for sand ripples
    wave_tex = nodes.new('ShaderNodeTexWave')
    wave_tex.wave_type = 'BANDS'
    wave_tex.inputs['Scale'].default_value = 3.0
    wave_tex.inputs['Distortion'].default_value = 4.0
    wave_tex.inputs['Detail'].default_value = 5.0
    wave_tex.inputs['Detail Scale'].default_value = 2.0
    wave_tex.inputs['Detail Roughness'].default_value = 0.5
    
    # Color ramp for sand tones
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[0].color = (0.76, 0.58, 0.35, 1.0)  # darker sand
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (0.92, 0.78, 0.52, 1.0)  # lighter sand
    
    mix = nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MIX'
    mix.inputs['Fac'].default_value = 0.5
    
    links.new(noise_tex.outputs['Fac'], mix.inputs['Color1'])
    links.new(wave_tex.outputs['Fac'], mix.inputs['Color2'])
    links.new(mix.outputs['Color'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
    
    # Bump for sand texture
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.3
    
    noise_bump = nodes.new('ShaderNodeTexNoise')
    noise_bump.inputs['Scale'].default_value = 50.0
    noise_bump.inputs['Detail'].default_value = 10.0
    
    links.new(noise_bump.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    
    return mat

def create_rock_material():
    mat = bpy.data.materials.new("CanyonRock")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 0.9
    bsdf.inputs['Specular IOR Level'].default_value = 0.15
    
    # Multi-layered rock texture
    noise1 = nodes.new('ShaderNodeTexNoise')
    noise1.inputs['Scale'].default_value = 4.0
    noise1.inputs['Detail'].default_value = 12.0
    noise1.inputs['Roughness'].default_value = 0.6
    
    noise2 = nodes.new('ShaderNodeTexNoise')
    noise2.inputs['Scale'].default_value = 20.0
    noise2.inputs['Detail'].default_value = 6.0
    
    voronoi = nodes.new('ShaderNodeTexVoronoi')
    voronoi.inputs['Scale'].default_value = 8.0
    voronoi.feature = 'F1'
    
    # Rock color ramp
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.2
    ramp.color_ramp.elements[0].color = (0.25, 0.18, 0.12, 1.0)  # dark brown
    el = ramp.color_ramp.elements.new(0.5)
    el.color = (0.45, 0.32, 0.22, 1.0)  # mid brown
    ramp.color_ramp.elements[1].position = 0.8
    ramp.color_ramp.elements[1].color = (0.62, 0.48, 0.33, 1.0)  # sandy brown
    
    mix = nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MIX'
    
    links.new(noise1.outputs['Fac'], mix.inputs['Color1'])
    links.new(voronoi.outputs['Distance'], mix.inputs['Color2'])
    links.new(noise2.outputs['Fac'], mix.inputs['Fac'])
    links.new(mix.outputs['Color'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
    
    # Strong bump for rocky surface
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.8
    
    links.new(voronoi.outputs['Distance'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    
    return mat

def create_path_material():
    """Packed earth / gravel path material"""
    mat = bpy.data.materials.new("DesertPath")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 0.98
    
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 30.0
    noise.inputs['Detail'].default_value = 10.0
    
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (0.55, 0.42, 0.28, 1.0)
    ramp.color_ramp.elements[1].position = 0.65
    ramp.color_ramp.elements[1].color = (0.68, 0.55, 0.38, 1.0)
    
    links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
    
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.5
    links.new(noise.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat


# ─── Create materials ───
sand_mat = create_sand_material()
rock_mat = create_rock_material()
path_mat = create_path_material()


# ─── Ground plane (sand) ───
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
ground = bpy.context.active_object
ground.name = "Ground"

# Subdivide for displacement
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.subdivide(number_cuts=60)
bpy.ops.object.mode_set(mode='OBJECT')

# Add subtle sand dune displacement
me = ground.data
for v in me.vertices:
    # Large gentle dunes
    nx = v.co.x * 0.15
    ny = v.co.y * 0.15
    dune_height = noise.noise(Vector((nx, ny, 0.0))) * 0.8
    # Smaller ripples  
    rx = v.co.x * 0.8
    ry = v.co.y * 0.8
    ripple = noise.noise(Vector((rx, ry, 1.0))) * 0.1
    v.co.z += dune_height + ripple

ground.data.materials.append(sand_mat)

# Smooth shading
bpy.ops.object.shade_smooth()


# ─── Canyon walls (left and right) ───
def create_canyon_wall(name, x_offset, z_scale, seed):
    """Create a rugged canyon wall from a displaced subdivided cube"""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x_offset, 0, 1.5))
    wall = bpy.context.active_object
    wall.name = name
    wall.scale = (3.5, 25, z_scale)
    bpy.ops.object.transform_apply(scale=True)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=30)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    me = wall.data
    random.seed(seed)
    for v in me.vertices:
        # Only displace the top and outward-facing verts
        if v.co.z > 0.5:
            nx = v.co.x * 0.3 + seed
            ny = v.co.y * 0.2
            nz = v.co.z * 0.4
            disp = noise.noise(Vector((nx, ny, nz))) * 1.2
            v.co.x += disp * 0.3
            v.co.z += abs(disp) * 0.5
        # Roughen the surface
        micro = noise.noise(Vector((v.co.x * 2 + seed, v.co.y * 2, v.co.z * 2))) * 0.15
        v.co.x += micro
        v.co.z += micro * 0.5
    
    wall.data.materials.append(rock_mat)
    bpy.ops.object.shade_smooth()
    
    # Add auto-smooth via modifier (Blender 4+)
    return wall

left_wall = create_canyon_wall("LeftWall", -5.5, 5.0, 42)
right_wall = create_canyon_wall("RightWall", 5.5, 4.5, 137)

# Additional wall segments further back for depth
left_wall_far = create_canyon_wall("LeftWallFar", -6.0, 6.0, 77)
left_wall_far.location.y = 15
right_wall_far = create_canyon_wall("RightWallFar", 6.5, 5.5, 221)
right_wall_far.location.y = 18


# ─── Path through the canyon ───
# Create a curved path on the ground
path_verts = []
path_width = 2.5
for i in range(40):
    y = -15 + i * 0.8
    # Slight S-curve
    x_offset = math.sin(y * 0.15) * 1.5
    path_verts.append((x_offset - path_width/2, y, 0.02))
    path_verts.append((x_offset + path_width/2, y, 0.02))

mesh = bpy.data.meshes.new("PathMesh")
obj = bpy.data.objects.new("DesertPath", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
verts_bm = []
for v in path_verts:
    verts_bm.append(bm.verts.new(v))

for i in range(0, len(verts_bm) - 2, 2):
    try:
        bm.faces.new([verts_bm[i], verts_bm[i+1], verts_bm[i+3], verts_bm[i+2]])
    except:
        pass

bm.to_mesh(mesh)
bm.free()

obj.data.materials.append(path_mat)


# ─── Scattered rocks along the canyon ───
def create_rock(location, scale_factor, seed):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=3,
        radius=0.5 * scale_factor,
        location=location
    )
    rock = bpy.context.active_object
    rock.name = f"Rock_{seed}"
    
    # Deform into rocky shape
    me = rock.data
    random.seed(seed)
    for v in me.vertices:
        disp = noise.noise(Vector((v.co.x * 3 + seed, v.co.y * 3, v.co.z * 3)))
        v.co.x += disp * 0.15 * scale_factor
        v.co.y += disp * 0.12 * scale_factor
        v.co.z += disp * 0.1 * scale_factor
    
    rock.data.materials.append(rock_mat)
    bpy.ops.object.shade_smooth()
    return rock

# Rocks scattered along the canyon edges
rock_positions = [
    ((-4.0, -6, 0.2), 0.8, 10),
    ((-3.5, -2, 0.15), 0.5, 20),
    ((4.2, -4, 0.2), 0.7, 30),
    ((3.8, 1, 0.3), 1.0, 40),
    ((-4.5, 4, 0.25), 0.6, 50),
    ((4.0, 7, 0.15), 0.4, 60),
    ((-3.0, 8, 0.2), 0.9, 70),
    ((3.5, -8, 0.2), 0.6, 80),
    ((-2.5, -10, 0.1), 0.3, 90),
    ((2.8, 10, 0.15), 0.5, 100),
    # Foreground rocks (closer to camera, will be blurred)
    ((-3.0, -12, 0.3), 1.2, 110),
    ((3.5, -13, 0.25), 0.9, 120),
    # Background rocks
    ((-4.0, 15, 0.2), 0.7, 130),
    ((4.5, 16, 0.3), 1.1, 140),
]

for pos, scale, seed in rock_positions:
    create_rock(pos, scale, seed)


# ─── Dust / particle system (small floating specs) ───
# We'll do this with small emissive cubes instead of a proper particle system
# since we're rendering a single frame
for i in range(30):
    random.seed(i + 500)
    x = random.uniform(-4, 4)
    y = random.uniform(-8, 12)
    z = random.uniform(0.5, 3.5)
    size = random.uniform(0.01, 0.03)
    
    bpy.ops.mesh.primitive_cube_add(size=size, location=(x, y, z))
    dust = bpy.context.active_object
    dust.name = f"Dust_{i}"
    
    dust_mat = bpy.data.materials.new(f"DustMat_{i}")
    dust_mat.use_nodes = True
    dust_nodes = dust_mat.node_tree.nodes
    bsdf = dust_nodes.get("Principled BSDF")
    bsdf.inputs['Base Color'].default_value = (1.0, 0.95, 0.8, 1.0)
    bsdf.inputs['Alpha'].default_value = random.uniform(0.3, 0.7)
    dust_mat.blend_method = 'BLEND' if hasattr(dust_mat, 'blend_method') else None
    dust.data.materials.append(dust_mat)


# ─── Sun light (dramatic side-lighting) ───
bpy.ops.object.light_add(type='SUN', location=(5, -3, 10))
sun = bpy.context.active_object
sun.name = "DesertSun"
sun.data.energy = 5.0
sun.data.color = (1.0, 0.93, 0.78)
sun.data.angle = math.radians(2.0)
sun.rotation_euler = (math.radians(35), math.radians(15), math.radians(-30))

# Secondary fill light (bounced light from sand)
bpy.ops.object.light_add(type='AREA', location=(-4, 5, 2))
fill = bpy.context.active_object
fill.name = "FillLight"
fill.data.energy = 50.0
fill.data.color = (0.95, 0.85, 0.65)
fill.data.size = 8.0
fill.rotation_euler = (math.radians(80), 0, math.radians(20))


# ─── Camera (low angle, Octopath style) ───
bpy.ops.object.camera_add(location=(0, -14, 4.5))
camera = bpy.context.active_object
camera.name = "HD2D_Camera"
scene.camera = camera

# Look along the canyon path
camera.rotation_euler = (math.radians(72), 0, 0)

# Camera settings
cam_data = camera.data
cam_data.lens = 35
cam_data.sensor_width = 36

# Depth of Field — tilt-shift effect
cam_data.dof.use_dof = True
cam_data.dof.focus_distance = 12.0
cam_data.dof.aperture_fstop = 2.0  # Shallow DoF for tilt-shift

# Clamp
cam_data.clip_start = 0.1
cam_data.clip_end = 100


# ─── Compositing for bloom and color grading ───
# In Blender 5.x, compositing is accessed differently
try:
    scene.use_nodes = True
    if hasattr(scene, 'node_tree') and scene.node_tree:
        comp_nodes = scene.node_tree.nodes
        comp_links = scene.node_tree.links
        comp_nodes.clear()

        rl = comp_nodes.new('CompositorNodeRLayers')

        glare = comp_nodes.new('CompositorNodeGlare')
        glare.glare_type = 'FOG_GLOW'
        glare.threshold = 0.8
        glare.size = 7
        glare.quality = 'HIGH'

        color_bal = comp_nodes.new('CompositorNodeColorBalance')
        color_bal.correction_method = 'LIFT_GAMMA_GAIN'
        color_bal.lift = (0.95, 0.92, 0.88)
        color_bal.gamma = (1.05, 1.0, 0.92)
        color_bal.gain = (1.1, 1.02, 0.9)

        output = comp_nodes.new('CompositorNodeComposite')

        comp_links.new(rl.outputs['Image'], glare.inputs['Image'])
        comp_links.new(glare.outputs['Image'], color_bal.inputs['Image'])
        comp_links.new(color_bal.outputs['Image'], output.inputs['Image'])
    else:
        print("Compositing node tree not available, skipping post-processing")
except Exception as e:
    print(f"Compositing setup skipped: {e}")


# ─── Render ───
render_path = os.path.join(RENDER_DIR, "desert_approach_rpg_hd2d.png")
scene.render.filepath = render_path
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'

print(f"Rendering HD-2D desert canyon scene to: {render_path}")
bpy.ops.render.render(write_still=True)
print("Render complete!")

# Also save the .blend file for future iteration
blend_path = os.path.join(r"d:\Games\Balance5\assets\models", "desert_approach_rpg.blend")
os.makedirs(os.path.dirname(blend_path), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"Blend file saved to: {blend_path}")
