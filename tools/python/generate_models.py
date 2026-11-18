import bpy
import bmesh
import math
import random
import os
import mathutils

os.makedirs("assets/models", exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_center_mound():
    clear_scene()
    print("Creating Center Cracked Rock Mound (wide top face)...")
    
    # Stepped bedrock mound
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=36,
        radius=4.8,
        depth=0.55,
        location=(0, 0, 0.28)
    )
    mound = bpy.context.active_object
    mound.name = "CenterMound"
    mound.scale = (1.22, 0.86, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    bm = bmesh.new()
    bm.from_mesh(mound.data)
    
    random.seed(1234)
    for v in bm.verts:
        r = math.sqrt(v.co.x**2 + v.co.y**2)
        angle = math.atan2(v.co.y, v.co.x)
        jitter = math.sin(angle * 7.0) * 0.35 + math.cos(angle * 13.0) * 0.18
        v.co.x += math.cos(angle) * jitter
        v.co.y += math.sin(angle) * jitter
        
        if v.co.z > 0.1:
            # Cracked stepped terracing across the top
            step = (math.sin(v.co.x * 1.6) * math.cos(v.co.y * 1.6)) * 0.15
            v.co.z += step
            if r > 3.6:
                v.co.z = max(0.08, v.co.z * 0.35)
                
    bm.to_mesh(mound.data)
    bm.free()
    
    out_path = os.path.abspath("assets/models/center_mound.gltf")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLTF_SEPARATE', use_selection=False)
    print("Center mound exported to:", out_path)

def create_orichalcum_crystals():
    clear_scene()
    print("Creating Orichalcum Crystal cluster (natural scattered formation)...")
    
    crystals_parent = bpy.data.objects.new("OrichalcumCrystals", None)
    bpy.context.scene.collection.objects.link(crystals_parent)
    
    random.seed(999)
    # 45 crystals distributed across an oval area matching the center rock
    cluster_x = 2.8
    cluster_y = 1.9
    for i in range(45):
        # Oval distribution
        r = (random.random() ** 0.5)
        theta = random.uniform(0, 2 * math.pi)
        x = r * math.cos(theta) * cluster_x
        y = r * math.sin(theta) * cluster_y
        
        # Center has taller crystal spires, edges have smaller shards
        dist_norm = math.sqrt((x/cluster_x)**2 + (y/cluster_y)**2)
        height = random.uniform(0.5, 1.8) * (1.0 - dist_norm * 0.45)
        radius = random.uniform(0.10, 0.28) * (height / 1.3)
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
            v.co = v.co.lerp(top_center, 0.90)
        bm.to_mesh(crystal.data)
        bm.free()
        
        tilt = random.uniform(0.06, 0.28)
        tx = -math.sin(theta) + random.uniform(-0.15, 0.15)
        ty = math.cos(theta) + random.uniform(-0.15, 0.15)
        crystal.rotation_euler = (tx * tilt, ty * tilt, random.uniform(0, math.pi))
        
    out_path = os.path.abspath("assets/models/orichalcum_crystals.gltf")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLTF_SEPARATE', use_selection=False)
    print("Orichalcum crystals exported to:", out_path)

def create_cliff_rock():
    clear_scene()
    print("Creating Single Modular Cliff Rock...")
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=18,
        radius=3.2,
        depth=1.3,
        location=(0, 0, 0.65)
    )
    rock = bpy.context.active_object
    rock.name = "CliffRock"
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    bm = bmesh.new()
    bm.from_mesh(rock.data)
    random.seed(333)
    for v in bm.verts:
        noise = (math.sin(v.co.x * 1.5) * math.cos(v.co.y * 1.5) + math.sin(v.co.z * 3.0)) * 0.25
        v.co.x += noise * 0.4
        v.co.y += noise * 0.4
        v.co.z += noise * 0.3
    bm.to_mesh(rock.data)
    bm.free()
    
    out_path = os.path.abspath("assets/models/cliff_rock.gltf")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLTF_SEPARATE', use_selection=False)
    print("Cliff rock exported to:", out_path)

if __name__ == "__main__":
    create_center_mound()
    create_orichalcum_crystals()
    create_cliff_rock()
