import cv2
import numpy as np

ref_path = "C:/Users/PC/.gemini/antigravity/brain/25684232-7f72-4063-b959-1b79d32ac318/.user_uploaded/media_1794834895605_af15c30b.jpg"
img = cv2.imread(ref_path)
h, w, c = img.shape

# Let's inspect coordinates of key units:
# 1. Blue tank: x ~ 150..200, y ~ 270..340
# 2. Blue infantry: x ~ 230..295, y ~ 310..390
# 3. Blue buggy: x ~ 320..365, y ~ 360..420
# 4. Center rock: x ~ 400..600, y ~ 380..580
# 5. Red harvester: x ~ 590..640, y ~ 480..535
# 6. Red buggy on road: x ~ 640..690, y ~ 635..690
# 7. Red infantry group: x ~ 660..750, y ~ 655..750
# 8. Red tank: x ~ 780..835, y ~ 730..810
# 9. Red buggy in sand: x ~ 790..835, y ~ 370..425
# 10. Red infantry in sand: x ~ 910..950, y ~ 355..405
# 11. Turret: x ~ 890..980, y ~ 185..300

print(f"Image shape: {w}x{h}")
