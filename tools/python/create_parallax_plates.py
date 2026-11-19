import cv2
import numpy as np
import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

albedo = cv2.imread(os.path.join(PROJECT_ROOT, r'assets\textures\maps\desert_approach_rpg_albedo.png'))
h, w, _ = albedo.shape

# Build a smooth alpha mask for the foreground cliffs (bottom-left and bottom-right)
fg_mask = np.zeros((h, w), dtype=np.float32)

# Bottom-left rock formation (up to x=320, y from 480 to 768)
# Create polygon points for bottom-left cliff
pts_bl = np.array([
    [0, 520],
    [120, 500],
    [240, 530],
    [320, 600],
    [300, 768],
    [0, 768]
], np.int32)
cv2.fillPoly(fg_mask, [pts_bl], 1.0)

# Bottom-right rock formation (x from 1050 to 1376, y from 480 to 768)
pts_br = np.array([
    [1060, 560],
    [1180, 510],
    [1376, 480],
    [1376, 768],
    [1000, 768]
], np.int32)
cv2.fillPoly(fg_mask, [pts_br], 1.0)

# Softly feather the edges of the mask
fg_mask = cv2.GaussianBlur(fg_mask, (31, 31), 0)

# Save foreground RGBA
fg_rgba = cv2.cvtColor(albedo, cv2.COLOR_BGR2BGRA)
fg_rgba[:, :, 3] = (fg_mask * 255.0).astype(np.uint8)
cv2.imwrite(os.path.join(PROJECT_ROOT, r'assets\textures\maps\desert_approach_rpg_foreground.png'), fg_rgba)

print('Foreground parallax plate created!')
