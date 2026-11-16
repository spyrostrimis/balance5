import cv2
import numpy as np

src_path = r'C:\Users\PC\.gemini\antigravity\brain\25684232-7f72-4063-b959-1b79d32ac318\desert_canyon_hd2d_1794850108794.jpg'
dst_albedo = r'd:\Games\Balance5\assets\textures\maps\desert_approach_rpg_albedo.png'
dst_normal = r'd:\Games\Balance5\assets\textures\maps\desert_approach_rpg_normal.png'

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
