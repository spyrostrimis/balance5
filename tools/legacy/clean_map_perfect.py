import cv2
import numpy as np

ref_path = "C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1794834895605_af15c30b.jpg"
img = cv2.imread(ref_path)
clean = img.copy()

def clone_patch(src_rect, dst_pt, size):
    global clean
    sx, sy = src_rect
    dx, dy = dst_pt
    sw, sh = size
    
    src_patch = clean[sy:sy+sh, sx:sx+sw]
    center = (int(dx + sw / 2), int(dy + sh / 2))
    mask = 255 * np.ones((sh, sw), dtype=np.uint8)
    clean = cv2.seamlessClone(src_patch, clean, mask, center, cv2.NORMAL_CLONE)

# 1. Blue Tank on road
clone_patch((65, 175), (145, 200), (55, 48))

# 2. Blue Infantry on road
clone_patch((70, 175), (228, 225), (70, 65))

# 3. Blue Buggy in sand
clone_patch((320, 330), (320, 260), (48, 48))

# 4. Red Harvester next to rock
clone_patch((530, 255), (595, 345), (55, 48))

# 5. Red Buggy on road
clone_patch((75, 175), (655, 455), (42, 45))

# 6. Red Squad (Commander + Troopers) on road
clone_patch((70, 175), (675, 465), (82, 70))
clone_patch((75, 175), (715, 505), (55, 45))

# 7. Red Tank on road
clone_patch((70, 175), (795, 540), (52, 52))

# 8. Red Buggy in upper sand
clone_patch((805, 330), (805, 270), (45, 42))

# 9. Red 2 Infantry in far right sand
clone_patch((920, 330), (925, 265), (38, 42))

# 10. Turret on rock plateau
clone_patch((845, 55), (900, 135), (98, 95))

# Save the pristine clean map
out_albedo = "assets/textures/maps/desert_mission_1_clean_albedo.png"
cv2.imwrite(out_albedo, clean)
print(f"Pristine clean map saved to: {out_albedo}")

# Generate high-frequency normal map
gray = cv2.cvtColor(clean, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
sobelx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3) * 3.5
sobely = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3) * 3.5

nx = -sobelx
ny = -sobely
nz = np.ones_like(gray)
norm = np.sqrt(nx*nx + ny*ny + nz*nz)
nx /= norm
ny /= norm
nz /= norm

r = ((nx * 0.5 + 0.5) * 255).astype(np.uint8)
g = (((-ny) * 0.5 + 0.5) * 255).astype(np.uint8)
b = ((nz * 0.5 + 0.5) * 255).astype(np.uint8)

normal_map = np.stack([b, g, r], axis=-1)
out_normal = "assets/textures/maps/desert_mission_1_clean_normal.png"
cv2.imwrite(out_normal, normal_map)
print(f"Normal map saved to: {out_normal}")
