import cv2
import numpy as np
from PIL import Image
import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

os.makedirs("assets/textures/maps", exist_ok=True)

# Load reference image
ref_path = os.path.join(PROJECT_ROOT, "assets/source_inputs", "media_1794834895605_af15c30b.jpg")
img = cv2.imread(ref_path)
h, w, c = img.shape
print(f"Loaded reference image: {w}x{h}")

# Create unit mask (255 where units are located, 0 elsewhere)
mask = np.zeros((h, w), dtype=np.uint8)

# 1. Blue forces (upper-left road & sand)
# Blue tank
cv2.rectangle(mask, (145, 275), (205, 335), 255, -1)
# Blue infantry group
cv2.rectangle(mask, (225, 305), (295, 385), 255, -1)
# Blue buggy
cv2.rectangle(mask, (315, 355), (365, 415), 255, -1)

# 2. Red harvester near rock mound
cv2.rectangle(mask, (580, 470), (645, 535), 255, -1)

# 3. Red forces (lower-right road & sand)
# Red buggy 1 (on road)
cv2.rectangle(mask, (635, 625), (695, 685), 255, -1)
# Red infantry + commander + healthbar
cv2.rectangle(mask, (650, 645), (755, 755), 255, -1)
# Red tank
cv2.rectangle(mask, (770, 725), (840, 805), 255, -1)
# Red buggy 2 (upper sand)
cv2.rectangle(mask, (785, 370), (840, 425), 255, -1)
# Red 2 infantry (far right)
cv2.rectangle(mask, (905, 350), (950, 410), 255, -1)

# 4. Missile turret on upper-right plateau
cv2.rectangle(mask, (885, 185), (980, 295), 255, -1)

# Dilate mask slightly for smooth seams
kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
mask = cv2.dilate(mask, kernel, iterations=1)

# Perform inpainting using Telea & Navier-Stokes
inpaint_telea = cv2.inpaint(img, mask, inpaintRadius=7, flags=cv2.INPAINT_TELEA)
inpaint_ns = cv2.inpaint(img, mask, inpaintRadius=7, flags=cv2.INPAINT_NS)
clean_map = cv2.addWeighted(inpaint_telea, 0.5, inpaint_ns, 0.5, 0)

# Save the clean albedo map
out_albedo = "assets/textures/maps/desert_mission_1_clean_albedo.png"
cv2.imwrite(out_albedo, clean_map)
print(f"Clean albedo map saved to {out_albedo}")

# Generate precision normal map from luminance/height
gray = cv2.cvtColor(clean_map, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
# Sobel derivatives
sobelx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3) * 3.5
sobely = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3) * 3.5

nx = -sobelx
ny = -sobely # OpenGL / Godot format
nz = np.ones_like(gray)

norm = np.sqrt(nx*nx + ny*ny + nz*nz)
nx /= norm
ny /= norm
nz /= norm

r = ((nx * 0.5 + 0.5) * 255).astype(np.uint8)
g = (((-ny) * 0.5 + 0.5) * 255).astype(np.uint8)
b = ((nz * 0.5 + 0.5) * 255).astype(np.uint8)

normal_map = np.stack([b, g, r], axis=-1) # BGR for cv2
out_normal = "assets/textures/maps/desert_mission_1_clean_normal.png"
cv2.imwrite(out_normal, normal_map)
print(f"Precision normal map saved to {out_normal}")
