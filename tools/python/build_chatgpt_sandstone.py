"""Process ChatGPT-generated sandstone rock albedo + aligned height maps into
seamless 1024x1024 PBR maps (albedo, normal, ORM) for 3D canyon boulders.
"""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

SIZE = 1024
TILE_METRES = 1.6  # 1 repeat = 1.6m across boulder height/width (640 texels/m)
PER_METRE = SIZE / TILE_METRES

ROOT = Path(r"d:\Games\Balance5")
TEX_DIR = ROOT / "assets" / "textures" / "canyon_pbr"
CAP_DIR = ROOT / "render_captures" / "chatgpt_boulder_test"

SRC_ALBEDO = Path(
    r"C:\Users\PC\.gemini\antigravity\brain\25684232-7f72-4063-b959-1b79d32ac318\.user_uploaded\media_1795022926046_7eba23fa.jpg"
)
SRC_HEIGHT = Path(
    r"C:\Users\PC\.gemini\antigravity\brain\25684232-7f72-4063-b959-1b79d32ac318\.user_uploaded\media_1795022967542_3a10c6a3.jpg"
)


def make_seamless_pair(alb: np.ndarray, hgt: np.ndarray, pad: int = 36) -> tuple[np.ndarray, np.ndarray]:
    """Makes albedo + aligned height seamlessly tileable along both axes with identical narrow cosine wraps."""
    def wrap_axis_0(a: np.ndarray, b: np.ndarray, margin: int):
        crop_h = SIZE - margin
        w_t = (0.5 - 0.5 * np.cos(np.pi * np.linspace(0.0, 1.0, margin, dtype=np.float32)))[:, None, None]

        a_top = a[:margin, :, :]
        a_bot = a[crop_h:, :, :]
        a_seam = a_bot * (1.0 - w_t) + a_top * w_t
        a_res = np.vstack([a_seam, a[margin:crop_h, :, :]])
        a_res = cv2.resize(a_res, (SIZE, SIZE), interpolation=cv2.INTER_LANCZOS4)

        b_top = b[:margin, :]
        b_bot = b[crop_h:, :]
        b_seam = b_bot * (1.0 - w_t[:, :, 0]) + b_top * w_t[:, :, 0]
        b_res = np.vstack([b_seam, b[margin:crop_h, :]])
        b_res = cv2.resize(b_res, (SIZE, SIZE), interpolation=cv2.INTER_LANCZOS4)
        return a_res, b_res

    a1, h1 = wrap_axis_0(alb, hgt, pad)
    a2_t, h2_t = wrap_axis_0(np.transpose(a1, (1, 0, 2)), h1.T, pad)
    return np.transpose(a2_t, (1, 0, 2)), h2_t.T


def wrap_stats(name: str, arr: np.ndarray) -> None:
    f = arr.astype(np.float32)
    if f.ndim == 2:
        f = f[..., None]
    xa = float(np.abs(f[:, 1:, :] - f[:, :-1, :]).mean())
    xw = float(np.abs(f[:, -1, :] - f[:, 0, :]).mean())
    za = float(np.abs(f[1:, :, :] - f[:-1, :, :]).mean())
    zw = float(np.abs(f[-1, :, :] - f[0, :, :]).mean())
    print(f"{name} | X adj={xa:.3f} wrap={xw:.3f} ({xw / xa:.2f}x) | Y adj={za:.3f} wrap={zw:.3f} ({zw / za:.2f}x)")


def main() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    CAP_DIR.mkdir(parents=True, exist_ok=True)

    alb_raw = np.asarray(Image.open(SRC_ALBEDO).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)).astype(np.float32)
    hgt_raw = np.asarray(Image.open(SRC_HEIGHT).convert("L").resize((SIZE, SIZE), Image.Resampling.LANCZOS)).astype(np.float32)

    wrap_stats("Raw Sandstone Albedo", alb_raw)
    alb_s, hgt_s = make_seamless_pair(alb_raw, hgt_raw, pad=36)
    wrap_stats("Seamless Sandstone Albedo", alb_s)
    wrap_stats("Seamless Sandstone Height", hgt_s)

    alb_u8 = np.clip(np.rint(alb_s), 0.0, 255.0).astype(np.uint8)

    # Save 3x3 tiling verification proof
    tile_3x3 = np.tile(alb_u8, (3, 3, 1))
    Image.fromarray(tile_3x3).resize((1536, 1536), Image.Resampling.LANCZOS).save(CAP_DIR / "tile_chatgpt_sandstone_3x3.png")

    # Derive normal map combining macro stepped strata height + fine surface sandstone grit
    p2, p98 = np.percentile(hgt_s, [2.0, 98.0])
    h_norm = np.clip((hgt_s - p2) / max(p98 - p2, 1.0), 0.0, 1.0)

    lum = (0.299 * alb_s[:, :, 0] + 0.587 * alb_s[:, :, 1] + 0.114 * alb_s[:, :, 2]) / 255.0
    lum_pad = cv2.copyMakeBorder(lum.astype(np.float32), 16, 16, 16, 16, cv2.BORDER_WRAP)
    micro_lum = lum - cv2.GaussianBlur(lum_pad, (15, 15), 4.0)[16:-16, 16:-16]

    total_height_m = h_norm * 0.030 + micro_lum * 0.008
    dx = (np.roll(total_height_m, -1, axis=1) - np.roll(total_height_m, 1, axis=1)) * (PER_METRE * 0.5)
    dz = (np.roll(total_height_m, -1, axis=0) - np.roll(total_height_m, 1, axis=0)) * (PER_METRE * 0.5)
    nrm = np.stack((-dx, dz, np.ones_like(dx)), axis=-1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    nrm_u8 = np.clip(np.rint((nrm * 0.5 + 0.5) * 255.0), 0.0, 255.0).astype(np.uint8)

    # ORM: R=Cavity AO (deep cracks/undercuts dark), G=Roughness, B=Edge chip highlight
    t_cav = np.clip((h_norm - 0.12) / 0.45, 0.0, 1.0)
    t_cav = t_cav * t_cav * (3.0 - 2.0 * t_cav)
    cavity_ao = np.clip(0.28 + 0.72 * t_cav + micro_lum * 0.30, 0.22, 1.0)
    roughness = np.clip(0.94 - 0.24 * t_cav, 0.65, 0.96)
    rim_mask = np.clip(1.0 - np.abs(h_norm - 0.52) / 0.25, 0.0, 1.0) * 0.75
    orm_u8 = np.clip(np.rint(np.dstack((cavity_ao, roughness, rim_mask)) * 255.0), 0.0, 255.0).astype(np.uint8)

    Image.fromarray(alb_u8).save(TEX_DIR / "chatgpt_sandstone_albedo.png")
    Image.fromarray(nrm_u8).save(TEX_DIR / "chatgpt_sandstone_normal.png")
    Image.fromarray(orm_u8).save(TEX_DIR / "chatgpt_sandstone_orm.png")
    print(f"Saved chatgpt_sandstone_* (1024x1024) to {TEX_DIR}")


if __name__ == "__main__":
    main()
