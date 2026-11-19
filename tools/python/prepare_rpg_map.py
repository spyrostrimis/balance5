import cv2
import numpy as np
import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

src_path = os.path.join(PROJECT_ROOT, "assets/source_inputs", r'desert_canyon_hd2d_1794850108794.jpg')
dst_albedo = os.path.join(PROJECT_ROOT, r'assets\textures\maps\desert_approach_rpg_albedo.png')
dst_normal = os.path.join(PROJECT_ROOT, r'assets\textures\maps\desert_approach_rpg_normal.png')

img = cv2.imread(src_path)
cv2.imwrite(dst_albedo, img)

# Generate normal map
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3) * 2.0
gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3) * 2.0
gz = np.ones_like(gx)

norm = np.sqrt(gx**2 + gy**2 + gz**2)
nx = (gx / norm * 0.5 + 0.5) * 255.0
ny = (-gy / norm * 0.5 + 0.5) * 255.0
nz = (gz / norm * 0.5 + 0.5) * 255.0

normal_map = np.stack([nx, ny, nz], axis=2).astype(np.uint8)
cv2.imwrite(dst_normal, normal_map)

print('Albedo and normal map saved to project!')
