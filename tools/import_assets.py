"""把來源素材與資料整理進 app/assets/（BUILD_PLAN 第 1、3 節）。

用法（在專案根目錄）：
    python -I tools/import_assets.py

只讀取來源資料夾，不修改來源。重跑會覆蓋 app/assets/ 內的輸出。
需要 Pillow。
"""
from __future__ import annotations

import json
import shutil
import sys
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC_PROCESSED = ROOT / "素材" / "processed"
SRC_SLIPS = ROOT / "籤詩_統一規格"
SRC_DATA = ROOT / "data"
SRC_LOGO = ROOT / "Logo" / "0e136df7-a4d3-4b35-b17a-1adbd804d960.png"
OUT = ROOT / "app" / "assets"
WEB = ROOT / "app" / "web"

INK = (0x2A, 0x22, 0x1C)
OBJECT_SKIP = ("_3d", "OB01_left", "OB01_right")
# 無字的 OB01 已由 OB01_raimon（首頁）／OB01_sei（好籤）取代，字都合成在圖上。
OBJECT_SKIP_EXACT = ("OB01",)
PAPER = (0xF1, 0xEA, 0xDC)  # App 底色，也是自適應／maskable 圖示的底色
SPRITE_MAX = 256
WEBP_Q = 88


def log(msg: str) -> None:
    print(msg, flush=True)


def reset(path: Path) -> Path:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)
    return path


def to_webp(src: Path, dst: Path, max_edge: int | None = None) -> None:
    with Image.open(src) as im:
        im.load()
        if max_edge and max(im.size) > max_edge:
            im.thumbnail((max_edge, max_edge), Image.LANCZOS)
        mode = "RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB"
        im.convert(mode).save(dst, "WEBP", quality=WEBP_Q, method=6)


def import_data() -> None:
    out = reset(OUT / "data")
    sensoji = json.loads((SRC_DATA / "poems_sensoji.json").read_text("utf-8"))
    for p in sensoji["poems"]:
        p["image"] = f"assets/slips/sensoji_{p['number']:03d}.webp"
        p["thumb"] = f"assets/slips/thumb/sensoji_{p['number']:03d}.jpg"
    (out / "poems_sensoji.json").write_text(json.dumps(sensoji, ensure_ascii=False, indent=1), "utf-8")

    shutil.copy(SRC_DATA / "poems_tw60.json", out / "poems_tw60.json")
    shutil.copy(SRC_DATA / "category_map.json", out / "category_map.json")
    for deck in ("sensoji", "tw60"):
        shutil.copy(SRC_DATA / f"line_gloss_{deck}.json", out / f"line_gloss_{deck}.json")

    judgments = json.loads((SRC_SLIPS / "sensoji_judgments.json").read_text("utf-8"))
    for j in judgments:
        j.pop("image", None)
    (out / "judgments_sensoji.json").write_text(json.dumps(judgments, ensure_ascii=False, indent=1), "utf-8")

    manifest = json.loads((SRC_SLIPS / "manifest.json").read_text("utf-8"))
    (out / "slip_spec.json").write_text(json.dumps(manifest["spec"], ensure_ascii=False, indent=1), "utf-8")
    log("data: 7 files")


def import_slips() -> None:
    out = reset(OUT / "slips")
    (out / "thumb").mkdir()
    n = 0
    with zipfile.ZipFile(SRC_SLIPS / "sensoji_other_sizes.zip") as z:
        for info in z.infolist():
            name = info.filename
            if name.startswith("webp/") and name.endswith(".webp"):
                dst = out / Path(name).name.replace("@3x", "")
            elif name.startswith("thumb/") and name.endswith(".jpg"):
                dst = out / "thumb" / Path(name).name.replace("_thumb", "")
            else:
                continue
            dst.write_bytes(z.read(info))
            n += 1
    log(f"slips: {n} files")


def import_backgrounds() -> None:
    out = reset(OUT / "bg")
    n = 0
    with zipfile.ZipFile(SRC_PROCESSED / "bg_webp.zip") as z:
        for info in z.infolist():
            if info.filename.endswith(".webp"):
                (out / Path(info.filename).name).write_bytes(z.read(info))
                n += 1
    log(f"bg: {n} files")


def import_objects() -> None:
    out = reset(OUT / "objects")
    n = 0
    for src in sorted((SRC_PROCESSED / "objects").glob("OB*.png")):
        if src.stem in OBJECT_SKIP_EXACT or any(s in src.stem for s in OBJECT_SKIP):
            continue
        to_webp(src, out / f"{src.stem}.webp")
        n += 1
    log(f"objects: {n} files")


def import_sprites() -> None:
    out = reset(OUT / "sprites")
    n = 0
    for src in sorted((SRC_PROCESSED / "sprites").glob("*.png")):
        to_webp(src, out / f"{src.stem}.webp", SPRITE_MAX)
        n += 1
    log(f"sprites: {n} files")


def import_textures() -> None:
    out = reset(OUT / "textures")
    for src in sorted((SRC_PROCESSED / "textures").glob("*.png")):
        to_webp(src, out / f"{src.stem}.webp")
    log("textures: 4 files")


def import_brand() -> None:
    out = reset(OUT / "brand")
    # 原檔白字黑底 → 墨字透明底：亮度當作不透明度，顏色填墨色。
    with Image.open(SRC_LOGO) as im:
        # 黑底不是純黑（約 #151515），先扣掉底色亮度，否則會留一層淡灰框。
        gray = im.convert("L").point(lambda v: 0 if v <= 40 else min(255, (v - 40) * 255 // 190))
        ink = Image.new("RGBA", gray.size, INK + (0,))
        ink.putalpha(gray)
        bbox = gray.getbbox()
        if bbox:
            pad = 24
            bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                    min(gray.width, bbox[2] + pad), min(gray.height, bbox[3] + pad))
            ink = ink.crop(bbox)
        ink.save(out / "logo_ink.png")
        white = Image.new("RGBA", ink.size, (0xF6, 0xEE, 0xDD, 0))
        white.putalpha(ink.getchannel("A"))
        white.save(out / "logo_light.png")
    obj = SRC_PROCESSED / "objects"
    # App 圖示：「成」燈籠（舊的 IC01_icon_1024／IC01_lantern_cutout 不再使用）。
    # Android 圖示由 flutter_launcher_icons 讀這兩張產生（設定在 app/pubspec.yaml）。
    shutil.copy(obj / "IC01_icon_1024_sei.png", out / "icon_1024.png")
    shutil.copy(obj / "IC01_adaptive_fg_sei.png", out / "icon_foreground.png")
    log("brand: 4 files")


def import_web_icons() -> None:
    """Web／PWA：一般圖示與 favicon 用完整圖示縮小；maskable 用前景圖疊在 #F1EADC 底上。"""
    obj = SRC_PROCESSED / "objects"
    icons = WEB / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    with Image.open(obj / "IC01_icon_1024_sei.png") as im:
        full = im.convert("RGB")
    with Image.open(obj / "IC01_adaptive_fg_sei.png") as im:
        fg = im.convert("RGBA")
    mask = Image.new("RGBA", fg.size, PAPER + (255,))
    mask.alpha_composite(fg)
    mask = mask.convert("RGB")
    for size in (192, 512):
        full.resize((size, size), Image.LANCZOS).save(icons / f"Icon-{size}.png", optimize=True)
        mask.resize((size, size), Image.LANCZOS).save(icons / f"Icon-maskable-{size}.png", optimize=True)
    full.resize((32, 32), Image.LANCZOS).save(WEB / "favicon.png", optimize=True)
    log("web icons: 5 files")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    import_data()
    import_slips()
    import_backgrounds()
    import_objects()
    import_sprites()
    import_textures()
    import_brand()
    import_web_icons()
    total = sum(f.stat().st_size for f in OUT.rglob("*") if f.is_file())
    log(f"total: {total / 1e6:.1f} MB in {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
