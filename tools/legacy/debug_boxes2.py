import cv2
import numpy as np

ref_path = "C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1794834895605_af15c30b.jpg"
img = cv2.imread(ref_path)

# Correct coordinates
units = {
    "blue_tank": (148, 282, 52, 48),
    "blue_infantry": (228, 312, 65, 75),
    "blue_buggy": (318, 362, 45, 52),
    "red_harvester": (588, 482, 50, 48),
    "red_buggy_road": (642, 638, 45, 50),
    "red_squad": (660, 660, 92, 95),
    "red_tank": (782, 742, 52, 65),
    "red_buggy_sand": (792, 375, 42, 42),
    "red_infantry_sand": (910, 368, 38, 38),
    "turret": (888, 192, 92, 96),
}

debug_img = img.copy()
for name, (x, y, bw, bh) in units.items():
    cv2.rectangle(debug_img, (x, y), (x+bw, y+bh), (0, 0, 255), 2)

cv2.imwrite("assets/textures/maps/debug_boxes_corrected.png", debug_img)
print("Saved corrected debug boxes.")
