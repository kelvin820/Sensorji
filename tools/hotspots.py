"""找出淺草寺籤紙上四句與判語欄的位置（分鏡 ⑤ 點句用的熱區）。

籤紙已依 籤詩_統一規格/manifest.json 對齊到同一個外框（frame_box），版面是：
上方標題框，下方主框；主框由右到左是四句（大字＋下方日文說明），最左一欄是判語。
欄與欄之間是貫穿主框的直線，用投影法找：每個 x 在主框高度內的深色像素比例，
超過門檻的連續 x 就是一條直線。

輸出 app/assets/data/hotspots_sensoji.json：
  { "1": {"lines": [[x0,y0,x1,y1] ×4（第一句在最右）], "judgment": [x0,y0,x1,y1]}, ... }
座標是 0…1 的比例（對整張籤紙圖），App 直接乘上顯示大小。

用法：python tools/hotspots.py [--debug 輸出目錄]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SLIPS = ROOT / "app" / "assets" / "slips"
SPEC = ROOT / "app" / "assets" / "data" / "slip_spec.json"
OUT = ROOT / "app" / "assets" / "data" / "hotspots_sensoji.json"

DARK = 110  # 灰階低於此值算墨色
# 各條線的預期位置（@3x 像素，量自多張籤紙的中位數）：主框上下緣、由左到右六條直線。
MAIN_TOP, MAIN_BOTTOM = 201, 1492
V_PRIORS = (51, 242, 433, 628, 828, 1027)
SEARCH = 28  # 在預期位置 ± 多少 px 內找（再寬會吸到旁邊的假名欄，如第 57 籤）
MIN_INK = 0.2  # 找到的線至少要有這麼多墨色，否則退回預期位置

warnings: list[str] = []


def runs(flags: list[bool]) -> list[tuple[int, int]]:
    """連續 True 的區段 [起, 迄]。"""
    out, start = [], None
    for i, f in enumerate(flags):
        if f and start is None:
            start = i
        if not f and start is not None:
            out.append((start, i - 1))
            start = None
    if start is not None:
        out.append((start, len(flags) - 1))
    return out


def centers(rs: list[tuple[int, int]], merge: int = 12) -> list[float]:
    """把相鄰的區段合併（粗線可能斷成幾段），回傳中心。"""
    merged: list[list[int]] = []
    for a, b in rs:
        if merged and a - merged[-1][1] <= merge:
            merged[-1][1] = b
        else:
            merged.append([a, b])
    return [(a + b) / 2 for a, b in merged]


def analyse(path: Path, frame: list[int]) -> dict:
    im = Image.open(path).convert("L")
    w, h = im.size
    px = im.load()
    fx0, fy0, fx1, fy1 = frame

    # 手繪的框線常斷斷續續，所以不用固定門檻找「線」，而是在每條線的預期位置附近
    # 找墨色最多的那一列／欄（籤紙都已對齊到同一個外框，位置只差幾十 px）。
    def row_ink(y: int) -> float:
        return sum(1 for x in range(fx0, fx1, 2) if px[x, y] < DARK) / ((fx1 - fx0) / 2)

    def best(prior: float, score, lo: int, hi: int) -> float:
        cands = range(max(lo, int(prior) - SEARCH), min(hi, int(prior) + SEARCH))
        # 粗線取 3 px 平均，避免被單一雜點吸走
        scored = [(sum(score(v + d) for d in (-1, 0, 1)) / 3, v) for v in cands]
        ink, at = max(scored)
        if ink < MIN_INK:
            warnings.append(f"{path.name}: {prior:.0f} 附近找不到線（墨色 {ink:.2f}），用預期位置")
            return prior
        return float(at)

    top = best(MAIN_TOP, row_ink, fy0 + 1, fy1 - 1)
    bottom = best(MAIN_BOTTOM, row_ink, fy0 + 1, fy1 - 1)

    def col_ink(x: int) -> float:
        ys = range(int(top) + 8, int(bottom) - 8, 3)
        return sum(1 for y in ys if px[x, y] < DARK) / len(ys)

    vlines = [best(prior, col_ink, 1, w - 1) for prior in V_PRIORS]

    def rect(x0: float, x1: float) -> list[float]:
        return [round(x0 / w, 4), round(top / h, 4), round(x1 / w, 4), round(bottom / h, 4)]

    # 由右到左：第 1 句在最右欄。
    lines = [rect(vlines[i], vlines[i + 1]) for i in (4, 3, 2, 1)]
    return {"lines": lines, "judgment": rect(vlines[0], vlines[1])}


def main() -> None:
    debug = Path(sys.argv[sys.argv.index("--debug") + 1]) if "--debug" in sys.argv else None
    frame = json.loads(SPEC.read_text(encoding="utf-8"))["frame_box"]
    result, failed = {}, []
    for n in range(1, 101):
        path = SLIPS / f"sensoji_{n:03d}.webp"
        try:
            result[str(n)] = analyse(path, frame)
        except ValueError as e:
            failed.append(str(e))
            continue
        if debug:
            im = Image.open(path).convert("RGB")
            d = ImageDraw.Draw(im)
            w, h = im.size
            boxes = result[str(n)]["lines"] + [result[str(n)]["judgment"]]
            for i, (x0, y0, x1, y1) in enumerate(boxes):
                d.rectangle([x0 * w + 6, y0 * h + 6, x1 * w - 6, y1 * h - 6], outline=(220, 40, 40) if i < 4 else (40, 120, 220), width=5)
            debug.mkdir(parents=True, exist_ok=True)
            im.resize((w // 3, h // 3)).save(debug / f"hot_{n:03d}.png")
    if failed:
        print("\n".join(failed))
        sys.exit(1)
    OUT.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"寫出 {OUT.relative_to(ROOT)}：{len(result)} 籤")


if __name__ == "__main__":
    main()
