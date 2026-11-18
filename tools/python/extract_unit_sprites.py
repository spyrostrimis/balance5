import cv2
import numpy as np
import os

os.makedirs("assets/textures/units", exist_ok=True)

orig = cv2.imread("C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1794834895605_af15c30b.jpg")
clean = cv2.imread("assets/textures/maps/desert_mission_1_clean_albedo.png")

# Difference image
diff = cv2.absdiff(orig, clean)
diff_gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)

def extract_sprite(name, x, y, w, h, thresh=15, pad=4):
    crop_orig = orig[y-pad:y+h+pad, x-pad:x+w+pad]
    crop_diff = diff_gray[y-pad:y+h+pad, x-pad:x+w+pad]
    
    # Smooth alpha mask
    alpha = np.clip((crop_diff.astype(float) - thresh) / 20.0, 0.0, 1.0)
    # Morphological cleanup
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    alpha_bin = (alpha > 0.1).astype(np.uint8)
    alpha_bin = cv2.morphologyEx(alpha_bin, cv2.MORPH_CLOSE, kernel)
    alpha_smooth = cv2.GaussianBlur(alpha_bin.astype(float) * 255, (3, 3), 0)
    
    b, g, r = cv2.split(crop_orig)
    rgba = np.stack([b, g, r, alpha_smooth.astype(np.uint8)], axis=-1)
    
    out_path = f"assets/textures/units/{name}.png"
    cv2.imwrite(out_path, rgba)
    print(f"Extracted {name}: {out_path} ({rgba.shape[1]}x{rgba.shape[0]})")

# 1. Blue Tank: (x=148, y=205, w=45, h=38)
extract_sprite("blue_tank", 148, 205, 45, 38)

# 2. Blue Infantry: (x=235, y=230, w=60, h=50)
extract_sprite("blue_infantry_squad", 235, 230, 60, 50)

# 3. Blue Buggy: (x=320, y=265, w=38, h=38)
extract_sprite("blue_buggy", 320, 265, 38, 38)

# 4. Red Harvester: (x=600, y=350, w=45, h=40)
extract_sprite("red_harvester", 600, 350, 45, 40)

# 5. Red Buggy (road): (x=655, y=455, w=38, h=38)
extract_sprite("red_buggy_road", 655, 455, 38, 38)

# 6. Red Commander & Squad: (x=680, y=475, w=75, h=70)
extract_sprite("red_commander_squad", 680, 475, 75, 70)

# 7. Red Tank: (x=805, y=545, w=42, h=42)
extract_sprite("red_tank", 805, 545, 42, 42)

# 8. Red Buggy (sand): (x=810, y=275, w=38, h=35)
extract_sprite("red_buggy_sand", 810, 275, 38, 35)

# 9. Turret: (x=900, y=135, w=80, h=85)
extract_sprite("turret", 900, 135, 80, 85)

print("All unit sprites extracted successfully!")
