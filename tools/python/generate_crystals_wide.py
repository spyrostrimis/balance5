import bpy
import bmesh
import math
import random
import os
import mathutils

os.makedirs("assets/models", exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_orichalcum_crystals():
    clear_scene()
    print("Creating Orichalcum Crystal cluster (full top-surface coverage)...")
    
    crystals_parent = bpy.data.objects.new("OrichalcumCrystals", None)
    bpy.context.scene.collection.objects.link(crystals_parent)
    
    random.seed(1024)
    # Scatter 68 crystals across the mound top face (oval radius X ~3.8, Y ~2.6)
    cluster_x = 3.6
    cluster_y = 2.4
    for i in range(68):
        r = (random.random() ** 0.55)
        theta = random.uniform(0, 2 * math.pi)
        x = r * math.cos(theta) * cluster_x
        y = r * math.sin(theta) * cluster_y
        
        dist_norm = math.sqrt((x/cluster_x)**2 + (y/cluster_y)**2)
        height = random.uniform(0.5, 1.7) * (1.0 - dist_norm * 0.40)
        radius = random.uniform(0.12, 0.28) * (height / 1.3)
        segments = random.choice([5, 6])
        
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=segments,
            radius=radius,
            depth=height,
            location=(x, y, height * 0.45)
        )
        crystal = bpy.context.active_object
        crystal.name = f"Crystal_{i}"
        crystal.parent = crystals_parent
        
        bm = bmesh.new()
        bm.from_mesh(crystal.data)
        top_verts = [v for v in bm.verts if v.co.z > 0.1]
        top_center = sum((v.co for v in top_verts), mathutils.Vector()) / len(top_verts)
        top_center.z += height * 0.38
        for v in top_verts:
            v.co = v.co.lerp(top_center, 0.88)
        bm.to_mesh(crystal.data)
        bm.free()
        
        tilt = random.uniform(0.06, 0.28)
        tx = -math.sin(theta) + random.uniform(-0.15, 0.15)
        ty = math.cos(theta) + random.uniform(-0.15, 0.15)
        crystal.rotation_euler = (tx * tilt, ty * tilt, random.uniform(0, math.pi))
        
    out_path = os.path.abspath("assets/models/orichalcum_crystals.gltf")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLTF_SEPARATE', use_selection=False)
    print("Orichalcum crystals exported to:", out_path)

if __name__ == "__main__":
    create_orichalcum_crystals()
