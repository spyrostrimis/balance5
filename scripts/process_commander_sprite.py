import cv2
import numpy as np

src_path = r'C:\Users\PC\.gemini\antigravity\brain\25684232-7f72-4063-b959-1b79d32ac318\combat_commander_hd2d_sprite_1794851030582.jpg'
out_sprite = r'd:\Games\Balance5\assets\textures\units\blue_commander_rpg.png'
out_normal = r'd:\Games\Balance5\assets\textures\units\blue_commander_rpg_normal.png'
out_shadow = r'd:\Games\Balance5\assets\textures\units\blue_commander_shadow.png'

img = cv2.imread(src_path)
h, w, _ = img.shape
print(f'Source sprite shape: {w}x{h}')

# The background is bright chroma green: high G (around 255), low R and B
# Let's isolate the green background cleanly
# In BGR: B < 100, G > 180, R < 100
is_green = (img[:, :, 1] > 180) & (img[:, :, 0] < 120) & (img[:, :, 2] < 120)

# Build alpha mask: 0 where green, 255 where character
alpha = np.where(is_green, 0, 255).astype(np.uint8)

# Clean up any green spill / fringe around edges
# Any pixel where alpha > 0 but has high green component
green_spill = (alpha > 0) & (img[:, :, 1] > img[:, :, 0] + 50) & (img[:, :, 1] > img[:, :, 2] + 50)
img_clean = img.copy()
# Desaturate green fringe to neutral dark tone
img_clean[green_spill, 1] = ((img_clean[green_spill, 0].astype(int) + img_clean[green_spill, 2].astype(int)) // 2).astype(np.uint8)

# Crop tight bounding box around the character
y_indices, x_indices = np.where(alpha > 0)
y_min, y_max = y_indices.min(), y_indices.max()
x_min, x_max = x_indices.min(), x_indices.max()

# Add small 2px padding
pad = 4
y_min = max(0, y_min - pad)
y_max = min(h, y_max + pad)
x_min = max(0, x_min - pad)
x_max = min(w, x_max + pad)

cropped_img = img_clean[y_min:y_max, x_min:x_max]
cropped_alpha = alpha[y_min:y_max, x_min:x_max]

# Assemble RGBA
rgba = cv2.cvtColor(cropped_img, cv2.COLOR_BGR2BGRA)
rgba[:, :, 3] = cropped_alpha

cv2.imwrite(out_sprite, rgba)
print(f'Clean cropped sprite saved: {cropped_alpha.shape[1]}x{cropped_alpha.shape[0]} to {out_sprite}')

# Generate Normal Map for sprite
gray = cv2.cvtColor(cropped_img, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3) * 1.8
gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3) * 1.8
gz = np.ones_like(gx)
norm = np.sqrt(gx**2 + gy**2 + gz**2)

nx = (gx / norm * 0.5 + 0.5) * 255.0
ny = (-gy / norm * 0.5 + 0.5) * 255.0
nz = (gz / norm * 0.5 + 0.5) * 255.0

normal_bgr = np.stack([nx, ny, nz], axis=2).astype(np.uint8)
normal_rgba = cv2.cvtColor(normal_bgr, cv2.COLOR_BGR2BGRA)
normal_rgba[:, :, 3] = cropped_alpha
cv2.imwrite(out_normal, normal_rgba)
print(f'Normal map saved to {out_normal}')

# Create an oval soft contact shadow
sw, sh = 120, 50
shadow = np.zeros((sh, sw, 4), dtype=np.uint8)
center = (sw // 2, sh // 2)
axes = (sw // 2 - 8, sh // 2 - 8)
# Draw filled ellipse with soft blur
cv2.ellipse(shadow, center, axes, 0, 0, 360, (20, 15, 10, 180), -1)
shadow[:, :, 3] = cv2.GaussianBlur(shadow[:, :, 3], (15, 15), 0)
cv2.imwrite(out_shadow, shadow)
print(f'Contact shadow saved to {out_shadow}')
