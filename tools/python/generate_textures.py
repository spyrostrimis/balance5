import numpy as np
from PIL import Image, ImageFilter
import math
import os

os.makedirs("assets/textures/terrain", exist_ok=True)

def height_to_normal(height_map, strength=3.0):
    dz_dx = (np.roll(height_map, -1, axis=1) - np.roll(height_map, 1, axis=1)) * 0.5 * strength
    dz_dy = (np.roll(height_map, -1, axis=0) - np.roll(height_map, 1, axis=0)) * 0.5 * strength
    
    nx = -dz_dx
    ny = -dz_dy
    nz = np.ones_like(height_map)
    
    norm = np.sqrt(nx*nx + ny*ny + nz*nz)
    nx /= norm
    ny /= norm
    nz /= norm
    
    r = ((nx * 0.5 + 0.5) * 255).astype(np.uint8)
    g = (((-ny) * 0.5 + 0.5) * 255).astype(np.uint8)
    b = ((nz * 0.5 + 0.5) * 255).astype(np.uint8)
    
    return np.stack([r, g, b], axis=-1)

def fast_cellular_noise(size, num_cells=350, seed=42):
    np.random.seed(seed)
    grid_cells = int(math.sqrt(num_cells))
    cell_w = size / grid_cells
    
    pts = []
    for gy in range(grid_cells):
        for gx in range(grid_cells):
            px = (gx + np.random.uniform(0.1, 0.9)) * cell_w
            py = (gy + np.random.uniform(0.1, 0.9)) * cell_w
            pts.append((px, py))
    pts = np.array(pts)
    
    d1 = np.full((size, size), 1e6, dtype=np.float32)
    d2 = np.full((size, size), 1e6, dtype=np.float32)
    cell_ids = np.zeros((size, size), dtype=np.int32)
    
    block_size = 256
    for by in range(0, size, block_size):
        for bx in range(0, size, block_size):
            bh = min(block_size, size - by)
            bw = min(block_size, size - bx)
            y, x = np.mgrid[by:by+bh, bx:bx+bw]
            coords = np.column_stack([x.ravel(), y.ravel()])
            
            margin = cell_w * 2.5
            mask = (pts[:, 0] >= bx - margin) & (pts[:, 0] <= bx + bw + margin) & \
                   (pts[:, 1] >= by - margin) & (pts[:, 1] <= by + bh + margin)
            sub_pts = pts[mask]
            sub_indices = np.where(mask)[0]
            
            dx = coords[:, 0:1] - sub_pts[:, 0]
            dy = coords[:, 1:2] - sub_pts[:, 1]
            dist_sq = dx*dx + dy*dy
            
            part_idx = np.argpartition(dist_sq, 1, axis=1)[:, :2]
            p0 = part_idx[:, 0]
            p1 = part_idx[:, 1]
            
            d0_sq = dist_sq[np.arange(len(coords)), p0]
            d1_sq = dist_sq[np.arange(len(coords)), p1]
            
            swap = d0_sq > d1_sq
            d0_sq, d1_sq = np.where(swap, d1_sq, d0_sq), np.where(swap, d0_sq, d1_sq)
            
            d1[by:by+bh, bx:bx+bw] = np.sqrt(d0_sq).reshape(bh, bw)
            d2[by:by+bh, bx:bx+bw] = np.sqrt(d1_sq).reshape(bh, bw)
            cell_ids[by:by+bh, bx:bx+bw] = sub_indices[p0].reshape(bh, bw)
            
    return d1, d2, cell_ids

def generate_organic_dunes(size=2048):
    print("Generating organic dune textures...")
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    norm_x = x / size
    norm_y = y / size
    
    # Diagonal angle ~32 degrees
    u = norm_x * 0.85 + norm_y * 0.53
    v = -norm_x * 0.53 + norm_y * 0.85
    
    # Smooth broad dunes
    warp = np.sin(v * 3.5 * np.pi) * 0.08 + np.cos(u * 1.8 * np.pi) * 0.04
    u_warped = u + warp
    
    dune_phase = (u_warped * 4.0 * np.pi) % (2 * np.pi)
    dune_wave = np.sin(dune_phase) * 0.5 + 0.5
    dune_wave = np.where(dune_wave > 0.4, 
                         ((np.maximum(0.0, dune_wave - 0.4)) / 0.6) ** 0.75, 
                         (dune_wave / 0.4) ** 1.8 * 0.2)
    
    # Fine wind ripples
    ripple_phase = (u_warped * 24.0 * np.pi + np.sin(v * 10.0 * np.pi) * 0.4) % (2 * np.pi)
    ripples = (np.sin(ripple_phase) * 0.5 + 0.5) ** 0.85
    
    sand_h = dune_wave * 0.72 + ripples * 0.28
    
    # Rich warm desert palette
    # Crest:  #f8b33c (248, 179, 60)
    # Body:   #de7e18 (222, 126, 24)
    # Shadow: #a44a08 (164, 74, 8)
    crest_col  = np.array([248, 179, 60], dtype=np.float32)
    body_col   = np.array([222, 126, 24], dtype=np.float32)
    shadow_col = np.array([164, 74, 8], dtype=np.float32)
    
    h_norm = np.clip(sand_h, 0.0, 1.0)[..., np.newaxis]
    albedo = np.where(h_norm > 0.45,
                      body_col + (crest_col - body_col) * ((h_norm - 0.45) / 0.55),
                      shadow_col + (body_col - shadow_col) * (h_norm / 0.45))
    
    np.random.seed(99)
    grain = np.random.normal(0, 2.0, (size, size, 3))
    albedo = np.clip(albedo + grain, 0, 255).astype(np.uint8)
    
    normal = height_to_normal(sand_h, strength=3.8)
    
    Image.fromarray(albedo).save("assets/textures/terrain/sand_albedo.png")
    Image.fromarray(normal).save("assets/textures/terrain/sand_normal.png")
    print("Organic dunes saved.")

def generate_cracked_rock_textures(size=2048):
    print("Generating cracked basalt rock textures...")
    d1, d2, cell_ids = fast_cellular_noise(size, num_cells=420, seed=42)
    crack_mask = np.clip((d2 - d1) / 7.5, 0.0, 1.0)
    
    np.random.seed(84)
    cell_heights = np.random.uniform(0.75, 1.0, 500)
    rock_height = cell_heights[cell_ids % 500] * (crack_mask ** 0.4)
    
    # Basalt rock with crisp edge highlights:
    # Base: #342921 (52, 41, 33)
    # Fissure: #120e0a (18, 14, 10)
    # Edge highlight: #8c735d (140, 115, 93)
    base_color  = np.array([52, 41, 33], dtype=np.float32)
    crack_color = np.array([18, 14, 10], dtype=np.float32)
    edge_color  = np.array([140, 115, 93], dtype=np.float32)
    
    cm = crack_mask[..., np.newaxis]
    albedo = crack_color + (base_color - crack_color) * cm
    # Sharp edge highlight along cracks
    edge_highlight = np.clip(1.0 - np.abs(crack_mask - 0.18) * 6.0, 0.0, 1.0)[..., np.newaxis]
    albedo = np.clip(albedo + edge_color * 0.55 * edge_highlight, 0, 255).astype(np.uint8)
    
    normal = height_to_normal(rock_height, strength=6.0)
    
    Image.fromarray(albedo).save("assets/textures/terrain/rock_albedo.png")
    Image.fromarray(normal).save("assets/textures/terrain/rock_normal.png")
    print("Cracked rock saved.")

def generate_flagstone_textures(size=2048):
    print("Generating weathered desert flagstone pavers...")
    # Irregular cobblestone pavers
    d1, d2, cell_ids = fast_cellular_noise(size, num_cells=600, seed=88)
    crack_mask = np.clip((d2 - d1) / 6.0, 0.0, 1.0)
    
    np.random.seed(101)
    stone_heights = np.random.uniform(0.82, 1.0, 750)
    height = stone_heights[cell_ids % 750] * (crack_mask ** 0.45)
    
    # Weathered desert paver colors (warm sand-stone, not white!)
    # Stone body: #b29e84 (178, 158, 132)
    # Mortar/sand joint: #524032 (82, 64, 50)
    # Bevel highlight: #ccb99f (204, 185, 159)
    stone_col  = np.array([178, 158, 132], dtype=np.float32)
    mortar_col = np.array([82, 64, 50], dtype=np.float32)
    bevel_col  = np.array([204, 185, 159], dtype=np.float32)
    
    cm = crack_mask[..., np.newaxis]
    albedo = mortar_col + (stone_col - mortar_col) * cm
    bevel_factor = np.clip(1.0 - np.abs(crack_mask - 0.22) * 5.0, 0.0, 1.0)[..., np.newaxis]
    albedo = np.clip(albedo + bevel_col * 0.35 * bevel_factor, 0, 255).astype(np.uint8)
    
    normal = height_to_normal(height, strength=4.5)
    
    Image.fromarray(albedo).save("assets/textures/terrain/flagstone_albedo.png")
    Image.fromarray(normal).save("assets/textures/terrain/flagstone_normal.png")
    print("Flagstone saved.")

def generate_splatmap(size=2048):
    print("Generating refined wide splatmap...")
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
    
    # Upper-right cliff plateau
    ur_dist = np.sqrt(((1.0 - norm_x)*0.95)**2 + (norm_y*1.3)**2)
    bedrock = np.maximum(bedrock, np.clip(1.0 - (ur_dist - 0.28) / 0.14, 0.0, 1.0))
    
    # Center rock mound (oval shaped, centered at 0.50, 0.52)
    center_dist = np.sqrt(((norm_x - 0.50) / 0.11)**2 + ((norm_y - 0.52) / 0.08)**2)
    center_mound = np.clip(1.0 - (center_dist - 0.85) / 0.20, 0.0, 1.0)
    bedrock = np.maximum(bedrock, center_mound)
    
    # Flagstone path:
    path = np.zeros((size, size), dtype=np.float32)
    road_width = 0.034
    
    # Road segment 1: upper-left to center
    p1 = np.array([0.03, 0.27])
    p2 = np.array([0.39, 0.48])
    v = p2 - p1
    L2 = np.dot(v, v)
    t1 = np.clip(((norm_x - p1[0])*v[0] + (norm_y - p1[1])*v[1]) / L2, 0.0, 1.0)
    proj_x = p1[0] + t1 * v[0]
    proj_y = p1[1] + t1 * v[1]
    dist_seg1 = np.sqrt((norm_x - proj_x)**2 + (norm_y - proj_y)**2)
    path = np.maximum(path, np.clip(1.0 - dist_seg1 / road_width, 0.0, 1.0))
    
    # Road segment 2: center to bottom-right
    p3 = np.array([0.61, 0.56])
    p4 = np.array([0.85, 0.82])
    v2 = p4 - p3
    L2_2 = np.dot(v2, v2)
    t2 = np.clip(((norm_x - p3[0])*v2[0] + (norm_y - p3[1])*v2[1]) / L2_2, 0.0, 1.0)
    proj_x2 = p3[0] + t2 * v2[0]
    proj_y2 = p3[1] + t2 * v2[1]
    dist_seg2 = np.sqrt((norm_x - proj_x2)**2 + (norm_y - proj_y2)**2)
    path = np.maximum(path, np.clip(1.0 - dist_seg2 / road_width, 0.0, 1.0))
    
    # Paved circular apron around center mound
    ring_dist = np.sqrt(((norm_x - 0.50) / 0.17)**2 + ((norm_y - 0.52) / 0.13)**2)
    apron_mask = np.clip(1.0 - np.abs(ring_dist - 0.95) / 0.32, 0.0, 1.0)
    path = np.maximum(path, apron_mask)
    path = path * (1.0 - center_mound)
    
    # Oasis pool in upper right
    oasis_dist = np.sqrt(((norm_x - 0.81) / 0.038)**2 + ((norm_y - 0.16) / 0.028)**2)
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
    print("Splatmap saved.")

if __name__ == "__main__":
    generate_organic_dunes()
    generate_cracked_rock_textures()
    generate_flagstone_textures()
    generate_splatmap()
    print("All updated textures generated successfully!")
