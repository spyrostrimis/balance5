import cv2
import numpy as np

img = cv2.imread("assets/textures/maps/desert_mission_1_clean_albedo.png")
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

# Spot 1: Far right soldiers
clone_patch((920, 320), (920, 260), (32, 35))

# Spot 2: Red soldiers on road
clone_patch((75, 175), (690, 505), (55, 45))

# Spot 3: Red tank on road
clone_patch((75, 175), (805, 555), (42, 45))

# Save pristine clean map
out_albedo = "assets/textures/maps/desert_mission_1_clean_albedo.png"
cv2.imwrite(out_albedo, clean)
print(f"Pristine clean map saved to: {out_albedo}")

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
print(f"Normal map saved to: {out_normal}")
