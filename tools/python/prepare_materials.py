import cv2
import numpy as np

def generate_normal_map(img_bgr, strength=2.0):
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3) * strength
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3) * strength
    gz = np.ones_like(gx)
    
    norm = np.sqrt(gx**2 + gy**2 + gz**2)
    # Godot standard tangent space normal map: Red=X+, Green=Y-, Blue=Z+
    nx = (gx / norm * 0.5 + 0.5) * 255.0
    ny = (-gy / norm * 0.5 + 0.5) * 255.0
    nz = (gz / norm * 0.5 + 0.5) * 255.0
    
    return np.stack([nx, ny, nz], axis=2).astype(np.uint8)

def make_seamless(img, overlap=32):
    h, w, c = img.shape
    out = img.copy()
    for x in range(overlap):
        alpha = x / float(overlap)
        out[:, x] = (1.0 - alpha) * img[:, w - overlap + x] + alpha * img[:, x]
    for y in range(overlap):
        alpha = y / float(overlap)
        out[y, :] = (1.0 - alpha) * img[h - overlap + y, :] + alpha * img[y, :]
    return out

for name in ['tex_sand_albedo', 'tex_rock_albedo', 'tex_path_albedo']:
    im = cv2.imread(f'd:/Games/Balance5/assets/textures/maps/{name}.png')
    seamless = make_seamless(im)
    normal = generate_normal_map(seamless, strength=2.5)
    norm_name = name.replace('albedo', 'normal')
    cv2.imwrite(f'd:/Games/Balance5/assets/textures/maps/{name}_seamless.png', seamless)
    cv2.imwrite(f'd:/Games/Balance5/assets/textures/maps/{norm_name}.png', normal)

print('Seamless textures and normal maps generated!')
