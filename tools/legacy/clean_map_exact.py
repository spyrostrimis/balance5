import cv2
import numpy as np

ref_path = "C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1794834895605_af15c30b.jpg"
img = cv2.imread(ref_path)
h, w, c = img.shape
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

# 1. Clean Blue Tank (around x=155..190, y=205..240)
# Source: clean road to the left (x=70, y=175)
clone_patch((70, 180), (150, 205), (42, 38))

# 2. Clean Blue Infantry (around x=235..295, y=230..280)
# Source: clean road segment (x=75, y=180)
clone_patch((75, 180), (235, 230), (62, 52))

# 3. Clean Blue Buggy (around x=330..365, y=265..300)
# Source: clean sand just below (x=330, y=320)
clone_patch((330, 320), (330, 265), (38, 38))

# 4. Clean Red Harvester (around x=600..645, y=350..385)
# Source: clean road/apron above (x=530, y=280)
clone_patch((530, 280), (600, 350), (48, 40))

# 5. Clean Red Buggy on Road (around x=660..690, y=460..495)
# Source: clean road segment (x=80, y=180)
clone_patch((80, 180), (660, 460), (35, 38))

# 6. Clean Red Squad (around x=680..760, y=475..555)
# Source: clean road segment (x=75, y=180)
clone_patch((75, 180), (680, 475), (82, 80))

# 7. Clean Red Tank (around x=805..845, y=545..585)
# Source: clean road segment (x=75, y=180)
clone_patch((75, 180), (805, 545), (42, 42))

# 8. Clean Red Buggy in upper sand (around x=810..845, y=275..305)
# Source: clean sand below (x=810, y=330)
clone_patch((810, 330), (810, 275), (38, 32))

# 9. Clean Red 2 Infantry in far right sand (around x=930..960, y=280..310)
# Source: clean sand below (x=930, y=330)
clone_patch((930, 330), (930, 280), (32, 32))

# 10. Clean Missile Turret on Upper-Right Plateau (around x=910..980, y=140..220)
# Source: clean rock plateau to the left (x=860, y=50)
clone_patch((850, 60), (910, 140), (75, 80))

out_albedo = "assets/textures/maps/desert_mission_1_clean_albedo.png"
cv2.imwrite(out_albedo, clean)
print(f"Clean map successfully saved to: {out_albedo}")

# Precision normal map
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
print(f"Precision normal map saved to: {out_normal}")
