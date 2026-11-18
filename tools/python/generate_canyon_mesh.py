"""
Generate a high-fidelity 3D Desert Canyon mesh with organic rock walls,
stepped ledges, and a sunken winding cobblestone path.
Exports to res://assets/models/canyon_environment.gltf
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector, noise

# Clean slate
bpy.ops.wm.read_factory_settings(use_empty=True)

OUT_GLTF = r"d:\Games\Balance5\assets\models\canyon_environment.glb"
os.makedirs(os.path.dirname(OUT_GLTF), exist_ok=True)

def clamp_val(val, mi, ma):
    return max(mi, min(ma, val))

# ─── 1. Build Canyon Terrain Mesh ───
# Grid: X from -15 to +15, Y from -35 (exit) to +15 (start)
# We will sculpt canyon walls on left (X < -2.5) and right (X > 2.5),
# with a winding path in the center (X between -2.0 and +2.0)

mesh = bpy.data.meshes.new("CanyonTerrain")
obj = bpy.data.objects.new("CanyonTerrain", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()

# Create a high-res grid
nx = 60
ny = 100
dx = 30.0 / (nx - 1)
dy = 50.0 / (ny - 1)

verts = []
for j in range(ny):
    y = 15.0 - j * dy # Y from +15 down to -35 (in Godot coordinates: Z)
    # Winding path center offset
    path_cx = math.sin(y * 0.15) * 1.5
    for i in range(nx):
        x = -15.0 + i * dx
        dist_from_path = abs(x - path_cx)
        
        # Base height
        z = 0.0
        
        # Canyon wall profile:
        # Path width: 2.2m (flat at z=0)
        # Bank slope: 2.2m to 4.0m (rises to z=1.5)
        # Tier 1 shelf: 4.0m to 7.0m (flat shelf at z=1.8 to 2.2)
        # Tier 2 wall: 7.0m to 10.0m (steep rise to z=4.5)
        # Tier 3 ridge: 10.0m to 15.0m (height 6.0 to 8.0)
        
        if dist_from_path < 1.8:
            # On the path
            z = 0.0 + noise.noise(Vector((x * 2.0, y * 2.0, 0.0))) * 0.04
        elif dist_from_path < 3.2:
            # First slope up to Tier 1 shelf
            t = (dist_from_path - 1.8) / 1.4
            z = t * 1.5 + noise.noise(Vector((x * 0.8, y * 0.8, 1.0))) * 0.2
        elif dist_from_path < 6.5:
            # Tier 1 rocky shelf
            t = (dist_from_path - 3.2) / 3.3
            z = 1.5 + t * 0.5 + noise.noise(Vector((x * 0.5, y * 0.5, 2.0))) * 0.3
        elif dist_from_path < 9.5:
            # Steep cliff rise to Tier 2
            t = (dist_from_path - 6.5) / 3.0
            z = 2.0 + t * 3.0 + noise.noise(Vector((x * 0.6, y * 0.6, 3.0))) * 0.5
        else:
            # High ridge
            t = (dist_from_path - 9.5) / 5.5
            z = 5.0 + t * 2.5 + noise.noise(Vector((x * 0.3, y * 0.3, 4.0))) * 0.8
            
        # Canyon Exit Gateway: At y < -22, the canyon walls open up!
        if y < -22.0:
            open_factor = clamp_val((-22.0 - y) / 10.0, 0.0, 1.0)
            # Walls push outward and lower into the open desert clearing
            if dist_from_path < 8.0 * (1.0 + open_factor * 1.5):
                z *= (1.0 - open_factor * 0.75)
                
        v = bm.verts.new((x, y, z))
        verts.append(v)

def clamp_val(val, mi, ma):
    return max(mi, min(ma, val))

bm.verts.ensure_lookup_table()

# Create faces
for j in range(ny - 1):
    for i in range(nx - 1):
        v1 = verts[j * nx + i]
        v2 = verts[j * nx + (i + 1)]
        v3 = verts[(j + 1) * nx + (i + 1)]
        v4 = verts[(j + 1) * nx + i]
        bm.faces.new([v1, v2, v3, v4])

# Generate UV coordinates
uv_layer = bm.loops.layers.uv.new("UVMap")
for face in bm.faces:
    for loop in face.loops:
        v = loop.vert
        loop[uv_layer].uv = (v.co.x * 0.2, v.co.y * 0.2)

bm.to_mesh(mesh)
bm.free()

bpy.ops.object.shade_smooth()

# ─── 2. Materials ───
# Sandstone Rock Material
mat_rock = bpy.data.materials.new("CanyonSandstone")
mat_rock.use_nodes = True
nodes = mat_rock.node_tree.nodes
links = mat_rock.node_tree.links
nodes.clear()

out = nodes.new('ShaderNodeOutputMaterial')
bsdf = nodes.new('ShaderNodeBsdfPrincipled')
bsdf.inputs['Roughness'].default_value = 0.88

tex_img = nodes.new('ShaderNodeTexImage')
tex_path = r"d:\Games\Balance5\assets\textures\maps\tex_rock_albedo_seamless.png"
if os.path.exists(tex_path):
    tex_img.image = bpy.data.images.load(tex_path)
    links.new(tex_img.outputs['Color'], bsdf.inputs['Base Color'])
else:
    bsdf.inputs['Base Color'].default_value = (0.72, 0.45, 0.25, 1.0)

links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
obj.data.materials.append(mat_rock)

# ─── 3. Separate Stone Path Overlay Ribbon ───
# A clean stone path ribbon running along the path center
path_bm = bmesh.new()
path_points = 50
for p in range(path_points):
    py = 15.0 - p * (50.0 / (path_points - 1))
    pcx = math.sin(py * 0.15) * 1.5
    pw = 2.4 # Path width
    v_l = path_bm.verts.new((pcx - pw/2.0, py, 0.02))
    v_r = path_bm.verts.new((pcx + pw/2.0, py, 0.02))

path_bm.verts.ensure_lookup_table()
for p in range(path_points - 1):
    vl1 = path_bm.verts[p * 2]
    vr1 = path_bm.verts[p * 2 + 1]
    vr2 = path_bm.verts[(p + 1) * 2 + 1]
    vl2 = path_bm.verts[(p + 1) * 2]
    path_bm.faces.new([vl1, vr1, vr2, vl2])

path_uv = path_bm.loops.layers.uv.new("UVMap")
for face in path_bm.faces:
    for loop in face.loops:
        loop[path_uv].uv = (loop.vert.co.x * 0.5, loop.vert.co.y * 0.5)

mesh_path = bpy.data.meshes.new("CobblestonePath")
path_bm.to_mesh(mesh_path)
path_bm.free()

obj_path = bpy.data.objects.new("CobblestonePath", mesh_path)
bpy.context.collection.objects.link(obj_path)

mat_path = bpy.data.materials.new("TrailCobblestone")
mat_path.use_nodes = True
pn = mat_path.node_tree.nodes
pl = mat_path.node_tree.links
pn.clear()
pout = pn.new('ShaderNodeOutputMaterial')
pbsdf = pn.new('ShaderNodeBsdfPrincipled')
pbsdf.inputs['Roughness'].default_value = 0.92

p_tex = pn.new('ShaderNodeTexImage')
p_tex_path = r"d:\Games\Balance5\assets\textures\maps\tex_path_albedo_seamless.png"
if os.path.exists(p_tex_path):
    p_tex.image = bpy.data.images.load(p_tex_path)
    pl.new(p_tex.outputs['Color'], pbsdf.inputs['Base Color'])
else:
    pbsdf.inputs['Base Color'].default_value = (0.58, 0.44, 0.3, 1.0)

pl.new(pbsdf.outputs['BSDF'], pout.inputs['Surface'])
obj_path.data.materials.append(mat_path)

# ─── 4. Export GLTF ───
print(f"Exporting organic 3D canyon to: {OUT_GLTF}")
bpy.ops.export_scene.gltf(
    filepath=OUT_GLTF,
    export_format='GLB',
    use_selection=False
)
print("GLTF Export Complete!")
