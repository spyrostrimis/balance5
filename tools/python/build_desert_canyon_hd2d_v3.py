"""
HD-2D Desert Canyon Scene Builder for Blender 5.2
Creates an Octopath Traveler-style desert canyon:
- Stepped/terraced sandstone cliffs on left and right (grand canyon strata)
- Winding cobblestone/sand path through the center
- Scattered desert rocks, cacti, dry shrubs
- Sunlit opening/clearing in the distance with warm atmospheric glow
- Diagonal god rays streaming into the canyon
- Tilt-shift camera (shallow depth of field)
"""
import bpy
import bmesh
import math
import random
import os
from mathutils import Vector, Euler

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

# Reset
bpy.ops.wm.read_factory_settings(use_empty=True)

OUT_DIR = os.path.join(PROJECT_ROOT, r"render_captures")
os.makedirs(OUT_DIR, exist_ok=True)
RENDER_FILE = os.path.join(OUT_DIR, "desert_approach_rpg_hd2d_v3.png")

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'GPU'
scene.cycles.samples = 200
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 720

# GPU enable
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'CUDA'
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
except Exception as e:
    print(f"GPU config notice: {e}")

# ─── Materials Helper ───
def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return m, nodes, links, bsdf

# 1. Sandstone Strata (Rock Wall) Material with visible horizontal layers
rock_mat, rnodes, rlinks, rbsdf = new_mat("SandstoneStrata")
rbsdf.inputs['Roughness'].default_value = 0.85

# Texture coordinate & mapping
tex_coord = rnodes.new('ShaderNodeTexCoord')
mapping = rnodes.new('ShaderNodeMapping')
rlinks.new(tex_coord.outputs['Object'], mapping.inputs['Vector'])

# Wave texture for horizontal geological strata (Z axis bands)
wave_z = rnodes.new('ShaderNodeTexWave')
wave_z.wave_type = 'BANDS'
wave_z.bands_direction = 'Z'
wave_z.inputs['Scale'].default_value = 1.2
wave_z.inputs['Distortion'].default_value = 3.0
wave_z.inputs['Detail'].default_value = 6.0
wave_z.inputs['Detail Scale'].default_value = 2.0
rlinks.new(mapping.outputs['Vector'], wave_z.inputs['Vector'])

# Noise texture for roughness & color breakup
noise_rock = rnodes.new('ShaderNodeTexNoise')
noise_rock.inputs['Scale'].default_value = 8.0
noise_rock.inputs['Detail'].default_value = 8.0
rlinks.new(mapping.outputs['Vector'], noise_rock.inputs['Vector'])

# Color ramp for rich warm sandstone (red rock / canyon palette)
ramp_rock = rnodes.new('ShaderNodeValToRGB')
ramp_rock.color_ramp.elements[0].position = 0.15
ramp_rock.color_ramp.elements[0].color = (0.35, 0.18, 0.10, 1.0) # deep terracotta brown
e1 = ramp_rock.color_ramp.elements.new(0.40)
e1.color = (0.65, 0.38, 0.22, 1.0) # warm rust sandstone
e2 = ramp_rock.color_ramp.elements.new(0.65)
e2.color = (0.82, 0.55, 0.32, 1.0) # golden amber layer
ramp_rock.color_ramp.elements[2].position = 0.90
ramp_rock.color_ramp.elements[2].color = (0.92, 0.72, 0.48, 1.0) # pale sand stratum

mix_rock = rnodes.new('ShaderNodeMixRGB')
mix_rock.inputs['Fac'].default_value = 0.25
rlinks.new(noise_rock.outputs['Fac'], mix_rock.inputs['Color1'])
rlinks.new(wave_z.outputs['Fac'], mix_rock.inputs['Color2'])
rlinks.new(mix_rock.outputs['Color'], ramp_rock.inputs['Fac'])
rlinks.new(ramp_rock.outputs['Color'], rbsdf.inputs['Base Color'])

# Bump
bump_r = rnodes.new('ShaderNodeBump')
bump_r.inputs['Strength'].default_value = 0.6
rlinks.new(wave_z.outputs['Fac'], bump_r.inputs['Height'])
rlinks.new(bump_r.outputs['Normal'], rbsdf.inputs['Normal'])

# 2. Sand Path Material (fine ripples, golden yellow)
sand_mat, snodes, slinks, sbsdf = new_mat("CanyonSand")
sbsdf.inputs['Roughness'].default_value = 0.9
ramp_sand = snodes.new('ShaderNodeValToRGB')
ramp_sand.color_ramp.elements[0].position = 0.3
ramp_sand.color_ramp.elements[0].color = (0.78, 0.58, 0.33, 1.0)
ramp_sand.color_ramp.elements[1].position = 0.8
ramp_sand.color_ramp.elements[1].color = (0.95, 0.78, 0.48, 1.0)
noise_sand = snodes.new('ShaderNodeTexNoise')
noise_sand.inputs['Scale'].default_value = 15.0
noise_sand.inputs['Detail'].default_value = 6.0
slinks.new(noise_sand.outputs['Fac'], ramp_sand.inputs['Fac'])
slinks.new(ramp_sand.outputs['Color'], sbsdf.inputs['Base Color'])

# 3. Cobblestone / Packed Dirt Trail Material
trail_mat, tnodes, tlinks, tbsdf = new_mat("TrailStones")
tbsdf.inputs['Roughness'].default_value = 0.92
voro_trail = tnodes.new('ShaderNodeTexVoronoi')
voro_trail.inputs['Scale'].default_value = 14.0
voro_trail.feature = 'F1'
ramp_trail = tnodes.new('ShaderNodeValToRGB')
ramp_trail.color_ramp.elements[0].position = 0.1
ramp_trail.color_ramp.elements[0].color = (0.42, 0.32, 0.22, 1.0)
ramp_trail.color_ramp.elements[1].position = 0.8
ramp_trail.color_ramp.elements[1].color = (0.68, 0.54, 0.38, 1.0)
tlinks.new(voro_trail.outputs['Distance'], ramp_trail.inputs['Fac'])
tlinks.new(ramp_trail.outputs['Color'], tbsdf.inputs['Base Color'])
bump_trail = tnodes.new('ShaderNodeBump')
bump_trail.inputs['Strength'].default_value = 0.5
tlinks.new(voro_trail.outputs['Distance'], bump_trail.inputs['Height'])
tlinks.new(bump_trail.outputs['Normal'], tbsdf.inputs['Normal'])

# 4. Desert Shrub / Cactus Material (dusty sage olive)
plant_mat, pnodes, plinks, pbsdf = new_mat("DesertPlant")
pbsdf.inputs['Roughness'].default_value = 0.85
pbsdf.inputs['Base Color'].default_value = (0.32, 0.38, 0.22, 1.0) # dusty green

# 5. God Ray Beam Material (Volume Scatter Cone)
beam_mat = bpy.data.materials.new("GodRayMat")
beam_mat.use_nodes = True
bnodes = beam_mat.node_tree.nodes
blinks = beam_mat.node_tree.links
bnodes.clear()
bout = bnodes.new('ShaderNodeOutputMaterial')
bvol = bnodes.new('ShaderNodeVolumeScatter')
bvol.inputs['Color'].default_value = (1.0, 0.94, 0.78, 1.0)
bvol.inputs['Density'].default_value = 0.12
bvol.inputs['Anisotropy'].default_value = 0.85
blinks.new(bvol.outputs['Volume'], bout.inputs['Volume'])


# ─── Geometry: Stepped Terraces (Octopath Style) ───
# We construct stepped rock shelves along the canyon flanks

def make_terrace(name, x, y, z, sx, sy, sz, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z + sz / 2.0))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    obj.data.materials.append(mat)
    # Bevel slightly for chunky blocky HD-2D look
    bev = obj.modifiers.new("Bevel", 'BEVEL')
    bev.width = 0.15
    bev.segments = 2
    return obj

# Base canyon floor (ground)
floor_obj = make_terrace("CanyonFloor", 0, 8, -0.5, 30, 40, 1.0, sand_mat)

# Center Trail (subtle curve leading toward clearing at Y=22)
trail_points = [
    (0.0, -4.0), (0.2, -1.0), (-0.3, 2.0), (0.1, 5.0),
    (0.5, 9.0), (0.2, 13.0), (-0.2, 17.0), (0.0, 22.0)
]
for i, (tx, ty) in enumerate(trail_points):
    t_obj = make_terrace(f"Trail_{i}", tx, ty, 0.01, 2.8, 3.2, 0.05, trail_mat)

# LEFT CLIFF TERRACES (Stepped up like Octopath diorama)
# Tier 1: Low shelves along path edge
make_terrace("L_Tier1_A", -3.8, -2.0, 0.0, 3.0, 5.0, 1.2, rock_mat)
make_terrace("L_Tier1_B", -3.6,  3.0, 0.0, 2.8, 6.0, 1.5, rock_mat)
make_terrace("L_Tier1_C", -3.9,  9.0, 0.0, 3.2, 7.0, 1.8, rock_mat)
make_terrace("L_Tier1_D", -4.2, 16.0, 0.0, 3.0, 8.0, 1.4, rock_mat)

# Tier 2: Mid-height cliff shelves
make_terrace("L_Tier2_A", -6.5, -1.0, 1.0, 4.0, 7.0, 2.5, rock_mat)
make_terrace("L_Tier2_B", -6.2,  6.0, 1.2, 3.8, 8.0, 3.0, rock_mat)
make_terrace("L_Tier2_C", -6.8, 14.0, 1.0, 4.2, 8.0, 3.2, rock_mat)

# Tier 3: High canyon wall backdrop
make_terrace("L_Tier3_A", -9.8,  2.0, 2.0, 4.5, 12.0, 5.0, rock_mat)
make_terrace("L_Tier3_B", -10.0, 14.0, 2.5, 4.5, 14.0, 6.0, rock_mat)

# RIGHT CLIFF TERRACES
# Tier 1: Low shelves
make_terrace("R_Tier1_A", 3.7, -3.0, 0.0, 2.8, 5.0, 1.0, rock_mat)
make_terrace("R_Tier1_B", 3.5,  2.5, 0.0, 2.6, 5.5, 1.4, rock_mat)
make_terrace("R_Tier1_C", 3.8,  8.5, 0.0, 3.0, 6.5, 1.6, rock_mat)
make_terrace("R_Tier1_D", 4.0, 15.5, 0.0, 3.0, 7.5, 1.3, rock_mat)

# Tier 2: Mid-height
make_terrace("R_Tier2_A", 6.2, -1.5, 0.8, 3.5, 6.5, 2.4, rock_mat)
make_terrace("R_Tier2_B", 6.0,  5.5, 1.0, 3.6, 7.5, 2.8, rock_mat)
make_terrace("R_Tier2_C", 6.5, 13.5, 1.2, 4.0, 8.5, 3.5, rock_mat)

# Tier 3: High canyon wall
make_terrace("R_Tier3_A", 9.5,  1.5, 1.8, 4.5, 11.0, 5.5, rock_mat)
make_terrace("R_Tier3_B", 9.8, 13.0, 2.2, 4.5, 13.0, 6.2, rock_mat)

# Distant desert mountains / canyon exit opening (The Clearing beyond!)
make_terrace("Dist_Gate_L", -5.5, 25.0, 0.0, 5.0, 4.0, 7.0, rock_mat)
make_terrace("Dist_Gate_R",  5.5, 25.0, 0.0, 5.0, 4.0, 7.0, rock_mat)
# Sunlit distant plateau in the gap
make_terrace("Dist_Plateau", 0.0, 32.0, 0.0, 16.0, 8.0, 3.5, rock_mat)


# ─── Scattered Props: Boulders, Desert Flora & Cacti ───
def make_boulder(name, x, y, z, s):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=s, location=(x, y, z))
    b = bpy.context.active_object
    b.name = name
    b.scale = (1.1, 0.9, 0.8)
    bpy.ops.object.transform_apply(scale=True)
    b.data.materials.append(rock_mat)
    bpy.ops.object.shade_smooth()
    return b

# Foreground boulders (softly blurred by DoF)
make_boulder("FG_Boulder_L", -1.8, -3.5, 0.35, 0.45)
make_boulder("FG_Boulder_R",  1.9, -3.2, 0.30, 0.40)

# Midground rocks along trail
make_boulder("Mid_Rock_1", -1.9,  1.5, 0.25, 0.30)
make_boulder("Mid_Rock_2",  1.8,  4.2, 0.35, 0.42)
make_boulder("Mid_Rock_3", -1.8,  7.0, 0.30, 0.35)
make_boulder("Mid_Rock_4",  1.9, 11.0, 0.40, 0.48)
make_boulder("Mid_Rock_5", -1.7, 14.5, 0.30, 0.35)

# Cacti / Stylized Desert Shrubs on terraces
def make_cactus(name, x, y, z, h):
    # Main trunk
    bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=h, location=(x, y, z + h/2.0))
    c = bpy.context.active_object
    c.name = name
    c.data.materials.append(plant_mat)
    # Left arm
    bpy.ops.mesh.primitive_cylinder_add(radius=0.09, depth=h*0.4, location=(x - 0.22, y, z + h*0.6))
    arm_l = bpy.context.active_object
    arm_l.data.materials.append(plant_mat)
    # Right arm
    bpy.ops.mesh.primitive_cylinder_add(radius=0.09, depth=h*0.35, location=(x + 0.22, y, z + h*0.45))
    arm_r = bpy.context.active_object
    arm_r.data.materials.append(plant_mat)

make_cactus("Cactus_L1", -2.8, -0.5, 1.2, 1.4)
make_cactus("Cactus_L2", -3.2,  7.5, 1.8, 1.8)
make_cactus("Cactus_L3", -4.5, 15.0, 1.4, 2.0)
make_cactus("Cactus_R1",  2.8,  1.0, 1.4, 1.3)
make_cactus("Cactus_R2",  3.0,  9.5, 1.6, 1.7)
make_cactus("Cactus_R3",  3.5, 16.5, 1.3, 1.5)


# ─── God Rays: Volumetric Light Shafts ───
# We create angled transparent light-shaft cylinders crossing the canyon
def make_god_ray(name, x, y, z, rot_x, rot_y, rot_z, length, radius):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=length, location=(x, y, z))
    beam = bpy.context.active_object
    beam.name = name
    beam.rotation_euler = (math.radians(rot_x), math.radians(rot_y), math.radians(rot_z))
    beam.data.materials.append(beam_mat)
    return beam

make_god_ray("Ray1", -2.0, 6.0, 4.5, -45, 25, -20, 14.0, 1.8)
make_god_ray("Ray2",  1.5, 12.0, 5.0, -42, 28, -25, 16.0, 2.2)
make_god_ray("Ray3", -0.5, 18.0, 6.0, -40, 20, -15, 18.0, 2.5)


# ─── Lighting Setup ───
# 1. Warm Sun shining diagonally from top-right into the canyon
bpy.ops.object.light_add(type='SUN', location=(15, -5, 20))
sun = bpy.context.active_object
sun.name = "DesertSun"
sun.data.energy = 8.5
sun.data.color = (1.0, 0.92, 0.76)
sun.data.angle = math.radians(2.0)
sun.rotation_euler = (math.radians(48), math.radians(-22), math.radians(35))

# 2. Golden Horizon Glow at the far end of the canyon (clearing exit)
bpy.ops.object.light_add(type='POINT', location=(0, 26, 3.5))
exit_glow = bpy.context.active_object
exit_glow.name = "ClearingExitGlow"
exit_glow.data.energy = 1500.0
exit_glow.data.color = (1.0, 0.82, 0.50)
exit_glow.data.shadow_soft_size = 3.0

# 3. Ambient sky fill
bpy.ops.object.light_add(type='SUN', location=(-10, 10, 15))
sky_fill = bpy.context.active_object
sky_fill.name = "SkyFill"
sky_fill.data.energy = 1.8
sky_fill.data.color = (0.75, 0.85, 1.0) # subtle blue sky fill in shadows
sky_fill.rotation_euler = (math.radians(20), math.radians(40), 0)

# World background color
world = bpy.data.worlds.new("DesertSky")
scene.world = world
world.use_nodes = True
wnodes = world.node_tree.nodes
wnodes.clear()
wout = wnodes.new('ShaderNodeOutputWorld')
wbg = wnodes.new('ShaderNodeBackground')
wbg.inputs['Color'].default_value = (0.95, 0.88, 0.75, 1.0)
wbg.inputs['Strength'].default_value = 1.2
world.node_tree.links.new(wbg.outputs['Background'], wout.inputs['Surface'])


# ─── Camera: Octopath Traveler Perspective ───
# Low angle looking along the canyon path toward the sunlit opening
bpy.ops.object.camera_add(location=(0.0, -7.0, 3.2))
cam_obj = bpy.context.active_object
cam_obj.name = "HD2D_Camera"
scene.camera = cam_obj

# Looking forward and slightly downward along +Y
cam_obj.rotation_euler = (math.radians(76), 0, 0)

cam = cam_obj.data
cam.lens = 42 # Slightly tighter focal length for cinematic depth compression
cam.sensor_width = 36

# Depth of Field (Tilt-Shift Miniature Effect)
cam.dof.use_dof = True
cam.dof.focus_distance = 11.0 # Razor sharp focus on the midground trail (Y ~ 4)
cam.dof.aperture_fstop = 1.4  # Shallow depth of field: blurry foreground & blurry distant opening

cam.clip_start = 0.5
cam.clip_end = 150

# ─── Render ───
print(f"Rendering HD-2D Desert Canyon v3 to: {RENDER_FILE}")
scene.render.filepath = RENDER_FILE
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'

bpy.ops.render.render(write_still=True)
print("Render complete!")

# Save blend
blend_path = os.path.join(PROJECT_ROOT, r"assets\models\desert_canyon_hd2d.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"Blend saved to: {blend_path}")
