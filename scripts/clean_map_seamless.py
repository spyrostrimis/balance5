import cv2
import numpy as np

ref_path = "C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1794834895605_af15c30b.jpg"
img = cv2.imread(ref_path)
h, w, c = img.shape
print(f"Image shape: width={w}, height={h}")
clean = img.copy()

def clone_patch(src_rect, dst_pt, size):
    global clean
    sx, sy = src_rect
    dx, dy = dst_pt
    sw, sh = size
    
    # Boundary checks
    if dx < 0 or dy < 0 or dx + sw > w or dy + sh > h:
        print(f"Skipping out of bounds dst: {dst_pt}, size: {size}")
        return
    if sx < 0 or sy < 0 or sx + sw > w or sy + sh > h:
        print(f"Skipping out of bounds src: {src_rect}, size: {size}")
        return
        
    src_patch = clean[sy:sy+sh, sx:sx+sw]
    center = (int(dx + sw / 2), int(dy + sh / 2))
    mask = 255 * np.ones((sh, sw), dtype=np.uint8)
    clean = cv2.seamlessClone(src_patch, clean, mask, center, cv2.NORMAL_CLONE)

# 1. Clean Blue Tank (on road, around x=150, y=280)
clone_patch((70, 240), (145, 275), (55, 55))

# 2. Clean Blue Infantry (on road, around x=230, y=315)
clone_patch((80, 245), (225, 310), (65, 65))

# 3. Clean Blue Buggy (in sand, around x=320, y=360)
clone_patch((320, 430), (320, 360), (45, 45))

# 4. Clean Red Harvester (right of rock mound, around x=590, y=475)
clone_patch((530, 365), (585, 475), (55, 55))

# 5. Clean Red Buggy on Road (around x=640, y=625)
clone_patch((460, 560), (635, 625), (50, 50))

# 6. Clean Red Infantry + Commander (around x=660, y=650)
clone_patch((80, 245), (660, 650), (45, 45))
clone_patch((90, 250), (705, 665), (45, 40))

# 7. Clean Red Tank (around x=775, y=650..700)
# Notice in image, red tank is at bottom-right road
clone_patch((75, 240), (775, 640), (55, 55))

# 8. Clean Red Buggy in upper sand (around x=790, y=370)
clone_patch((710, 370), (790, 370), (45, 45))

# 9. Clean Red 2 Infantry in far right sand (around x=910, y=350)
clone_patch((840, 420), (910, 350), (40, 45))

# 10. Clean Missile Turret on Upper-Right Plateau (around x=885, y=190)
clone_patch((770, 100), (885, 190), (90, 95))

out_albedo = "assets/textures/maps/desert_mission_1_clean_albedo.png"
cv2.imwrite(out_albedo, clean)
print(f"Saved: {out_albedo}")

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
print(f"Saved: {out_normal}")
