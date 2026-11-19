import cv2
import numpy as np
import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

ref_path = os.path.join(PROJECT_ROOT, "assets/source_inputs", "media_1794834895605_af15c30b.jpg")
img = cv2.imread(ref_path)
h, w, c = img.shape

# Let's crop patches around each unit and print their exact bounding boxes
units = {
    "blue_tank": (150, 280, 50, 55),
    "blue_infantry": (230, 310, 65, 80),
    "blue_buggy": (320, 360, 45, 55),
    "red_harvester": (590, 480, 50, 55),
    "red_buggy_road": (645, 640, 45, 50),
    "red_squad": (660, 660, 90, 95),
    "red_tank": (785, 745, 50, 65),
    "red_buggy_sand": (795, 375, 40, 45),
    "red_infantry_sand": (915, 360, 35, 45),
    "turret": (905, 190, 75, 100),
}

debug_img = img.copy()
for name, (x, y, bw, bh) in units.items():
    cv2.rectangle(debug_img, (x, y), (x+bw, y+bh), (0, 255, 0), 2)

cv2.imwrite("assets/textures/maps/debug_boxes.png", debug_img)
print("Saved debug_boxes.png")
