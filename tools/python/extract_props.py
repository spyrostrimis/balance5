import cv2
import numpy as np

img = cv2.imread(r'd:\Games\Balance5\assets\textures\maps\desert_mission_1_clean_albedo.png')

# 1. Extract bush (around x=770, y=140)
# Let's crop a 60x60 patch around the bush and mask the sand out
bush_crop = img[135:185, 750:800].copy()
# Sand in this area is golden (high red/green, low blue). Green foliage has higher G than R!
# Let's make an alpha mask based on color
hsv = cv2.cvtColor(bush_crop, cv2.COLOR_BGR2HSV)
# Green mask: H between 30 and 85
green_mask = cv2.inRange(hsv, (25, 60, 40), (85, 255, 255))
# Clean mask
kernel = np.ones((3,3), np.uint8)
green_mask = cv2.morphologyEx(green_mask, cv2.MORPH_CLOSE, kernel)
green_mask = cv2.GaussianBlur(green_mask, (3,3), 0)

# Build RGBA
bush_rgba = cv2.cvtColor(bush_crop, cv2.COLOR_BGR2BGRA)
bush_rgba[:, :, 3] = green_mask
cv2.imwrite(r'd:\Games\Balance5\assets\textures\maps\prop_bush.png', bush_rgba)

# 2. Extract small rock props from the sand dunes
# Near x=650, y=300 or x=200, y=600 there are small isolated rocks
rock_crop = img[290:330, 640:680].copy()
# The rock is dark brown, sand is bright gold
gray_rock = cv2.cvtColor(rock_crop, cv2.COLOR_BGR2GRAY)
# Darker than sand
rock_mask = (gray_rock < 140).astype(np.uint8) * 255
rock_mask = cv2.morphologyEx(rock_mask, cv2.MORPH_CLOSE, kernel)
rock_rgba = cv2.cvtColor(rock_crop, cv2.COLOR_BGR2BGRA)
rock_rgba[:, :, 3] = rock_mask
cv2.imwrite(r'd:\Games\Balance5\assets\textures\maps\prop_rock.png', rock_rgba)

# 3. Extract glowing Orichalcum crystal cluster from center crater
crystal_crop = img[425:485, 470:530].copy()
# The crystals are bright gold/yellow (R>200, G>180, B<100)
cryst_mask = ((crystal_crop[:,:,2] > 180) & (crystal_crop[:,:,1] > 140) & (crystal_crop[:,:,0] < 120)).astype(np.uint8) * 255
cryst_mask = cv2.dilate(cryst_mask, kernel, iterations=1)
cryst_mask = cv2.GaussianBlur(cryst_mask, (3,3), 0)
crystal_rgba = cv2.cvtColor(crystal_crop, cv2.COLOR_BGR2BGRA)
crystal_rgba[:, :, 3] = cryst_mask
cv2.imwrite(r'd:\Games\Balance5\assets\textures\maps\prop_crystal.png', crystal_rgba)

print('Props extracted successfully!')
