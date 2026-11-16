import numpy as np
from PIL import Image, ImageFilter
import math
import os

os.makedirs("assets/textures/terrain", exist_ok=True)

def generate_splatmap(size=2048):
    print("Generating authentic layout splatmap...")
    y, x = np.mgrid[0:size, 0:size]
    norm_x = x / size
    norm_y = y / size
    
    bedrock = np.zeros((size, size), dtype=np.float32)
    
    # Top-left cliff
    tl_dist = np.sqrt(norm_x**2 + (norm_y*1.2)**2)
    bedrock = np.maximum(bedrock, np.clip(1.0 - (tl_dist - 0.16) / 0.10, 0.0, 1.0))
    
    # Bottom-left cliff
    bl_dist = np.sqrt(norm_x**2 + ((1.0 - norm_y)*1.1)**2)
    bedrock = np.maximum(bedrock, np.clip(1.0 - (bl_dist - 0.22) / 0.12, 0.0, 1.0))
    
    # Upper-right cliff plateau (around oasis)
    ur_dist = np.sqrt(((1.0 - norm_x)*0.95)**2 + (norm_y*1.3)**2)
    bedrock = np.maximum(bedrock, np.clip(1.0 - (ur_dist - 0.28) / 0.14, 0.0, 1.0))
    
    # Center rock mound (oval shaped, centered at 0.50, 0.52)
    center_dist = np.sqrt(((norm_x - 0.50) / 0.11)**2 + ((norm_y - 0.52) / 0.08)**2)
    center_mound = np.clip(1.0 - (center_dist - 0.85) / 0.18, 0.0, 1.0)
    bedrock = np.maximum(bedrock, center_mound)
    
    # Flagstone path:
    path = np.zeros((size, size), dtype=np.float32)
    road_width = 0.032
    
    # Road segment 1: upper-left to center
    p1 = np.array([0.03, 0.27])
    p2 = np.array([0.41, 0.48])
    v = p2 - p1
    L2 = np.dot(v, v)
    t1 = np.clip(((norm_x - p1[0])*v[0] + (norm_y - p1[1])*v[1]) / L2, 0.0, 1.0)
    proj_x = p1[0] + t1 * v[0]
    proj_y = p1[1] + t1 * v[1]
    dist_seg1 = np.sqrt((norm_x - proj_x)**2 + (norm_y - proj_y)**2)
    path = np.maximum(path, np.clip(1.0 - dist_seg1 / road_width, 0.0, 1.0))
    
    # Road segment 2: center to bottom-right
    p3 = np.array([0.59, 0.56])
    p4 = np.array([0.85, 0.82])
    v2 = p4 - p3
    L2_2 = np.dot(v2, v2)
    t2 = np.clip(((norm_x - p3[0])*v2[0] + (norm_y - p3[1])*v2[1]) / L2_2, 0.0, 1.0)
    proj_x2 = p3[0] + t2 * v2[0]
    proj_y2 = p3[1] + t2 * v2[1]
    dist_seg2 = np.sqrt((norm_x - proj_x2)**2 + (norm_y - proj_y2)**2)
    path = np.maximum(path, np.clip(1.0 - dist_seg2 / road_width, 0.0, 1.0))
    
    # SOLID APRON: Paving starts right at the edge of the center rock mound and extends outward!
    # center_dist is 1.0 at rock perimeter. Apron extends from center_dist ~0.9 to ~1.45!
    apron_zone = np.clip((1.45 - center_dist) / 0.25, 0.0, 1.0)
    # Exclude the rock mound itself
    apron = apron_zone * (1.0 - center_mound)
    path = np.maximum(path, apron)
    
    # Oasis pool on the upper-right rock plateau (around 0.80, 0.16)
    oasis_dist = np.sqrt(((norm_x - 0.80) / 0.045)**2 + ((norm_y - 0.16) / 0.035)**2)
    oasis = np.clip(1.0 - oasis_dist, 0.0, 1.0)
    
    sand = np.clip(1.0 - (bedrock + path), 0.0, 1.0)
    
    splat_r = (sand * 255).astype(np.uint8)
    splat_g = (path * 255).astype(np.uint8)
    splat_b = (bedrock * 255).astype(np.uint8)
    splat_a = (oasis * 255).astype(np.uint8)
    
    splat = np.stack([splat_r, splat_g, splat_b, splat_a], axis=-1)
    img = Image.fromarray(splat, mode="RGBA")
    img = img.filter(ImageFilter.GaussianBlur(radius=3.0))
    img.save("assets/textures/terrain/splatmap.png")
    print("Authentic layout splatmap saved.")

if __name__ == "__main__":
    generate_splatmap()
