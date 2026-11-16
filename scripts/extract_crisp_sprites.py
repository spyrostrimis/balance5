import cv2
import numpy as np
import os

os.makedirs("assets/textures/units", exist_ok=True)

orig = cv2.imread("C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1794834895605_af15c30b.jpg")
clean = cv2.imread("assets/textures/maps/desert_mission_1_clean_albedo.png")

diff = cv2.absdiff(orig, clean)
diff_gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)

def extract_perfect(name, x, y, w, h, thresh=24, pad=3):
    crop_orig = orig[y-pad:y+h+pad, x-pad:x+w+pad]
    crop_diff = diff_gray[y-pad:y+h+pad, x-pad:x+w+pad]
    
    alpha = (crop_diff > thresh).astype(np.uint8) * 255
    # Remove small specks by connected components area
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(alpha)
    clean_alpha = np.zeros_like(alpha)
    for i in range(1, num_labels):
        if stats[i, cv2.CC_STAT_AREA] >= 30: # Only significant clusters
            clean_alpha[labels == i] = 255
            
    # Anti-alias edges
    alpha_smooth = cv2.GaussianBlur(clean_alpha.astype(float), (3, 3), 0.4)
    
    b, g, r = cv2.split(crop_orig)
    rgba = np.stack([b, g, r, alpha_smooth.astype(np.uint8)], axis=-1)
    
    out_path = f"assets/textures/units/{name}.png"
    cv2.imwrite(out_path, rgba)
    print(f"Perfect extracted {name}: {out_path}")

extract_perfect("blue_tank", 148, 205, 45, 38, thresh=22)
extract_perfect("blue_infantry_squad", 235, 230, 60, 50, thresh=18)
extract_perfect("blue_buggy", 320, 265, 38, 38, thresh=20)
extract_perfect("red_harvester", 600, 350, 45, 40, thresh=22)
extract_perfect("red_buggy_road", 655, 455, 38, 38, thresh=20)
extract_perfect("red_commander_squad", 680, 475, 75, 70, thresh=18)
extract_perfect("red_tank", 805, 545, 42, 42, thresh=22)
extract_perfect("red_buggy_sand", 810, 275, 38, 35, thresh=20)
extract_perfect("turret", 900, 135, 80, 85, thresh=25)
