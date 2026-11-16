import cv2
import numpy as np

src_path = r'd:\Games\Balance5\assets\textures\maps\desert_approach_rpg_albedo.png'
dst_path = r'd:\Games\Balance5\assets\textures\maps\desert_canyon_projected_albedo.png'

img = cv2.imread(src_path).astype(np.float32)
h, w, _ = img.shape

# Multi-band unsharp masking for upper canyon & exit region (y = 0..440)
b1 = cv2.GaussianBlur(img, (0, 0), 1.2)
b2 = cv2.GaussianBlur(img, (0, 0), 2.8)
b3 = cv2.GaussianBlur(img, (0, 0), 5.5)
sharp = img + (img - b1) * 0.9 + (img - b2) * 0.65 + (img - b3) * 0.4
sharp = np.clip(sharp, 0.0, 255.0)

y_coords = np.arange(h, dtype=np.float32)[:, None]
w_y = np.clip((440.0 - y_coords) / 220.0, 0.0, 1.0)[:, :, None]

out = img * (1.0 - w_y) + sharp * w_y
out = np.clip(out, 0.0, 255.0).astype(np.uint8)
cv2.imwrite(dst_path, out)
print(f"Saved multi-band enhanced projected canyon texture to {dst_path} ({w}x{h})")
