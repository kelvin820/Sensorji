"""把莫大毛筆字體（Bakudai，SIL OFL 1.1）縮成 App 用得到的字。

毛筆字只用在固定文字：標題、按鈕、籤號、籤詩原文、類別名稱。使用者打的問題、
AI 解說、逐句白話用一般黑體（好讀，也不會缺字）。完整字型 14 MB，Web 版載不動，
所以只保留下列來源出現過的字；缺的字 Flutter 會自動改用備用字型。

來源：
  - app/lib/**/*.dart 裡所有中日文字（介面文字、籤號中文數字）
  - 兩套籤詩原文、干支、吉凶、類別與分項名稱
  - ASCII 可見字元與常用全形標點

用法：python -I tools/subset_font.py
需要：pip install fonttools；原始字型放在 fonts_src/Bakudai-Medium.ttf（不進版控），
下載自 https://github.com/max32002/bakudaifont （tw/Bakudai-Medium.ttf）。
改了介面文字或籤詩資料後要重跑。
"""

import json
import re
import shutil
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
# 用 Medium 字重：Regular 是原作筆畫，手機上的標題與按鈕偏細；Medium 是莫大自動加粗的版本。
SRC = ROOT / "fonts_src" / "Bakudai-Medium.ttf"
LICENSE = ROOT / "fonts_src" / "SIL_Open_Font_License_1.1.txt"
OUT_DIR = ROOT / "app" / "assets" / "fonts"
OUT = OUT_DIR / "Bakudai.ttf"

CJK = re.compile(r"[　-〿㐀-䶿一-鿿豈-﫿＀-￯]")


def collect() -> set[str]:
    chars: set[str] = set(chr(c) for c in range(0x20, 0x7F))
    chars |= set("「」『』（）、，。：；！？…・—～　")
    for f in (ROOT / "app" / "lib").rglob("*.dart"):
        chars |= set(CJK.findall(f.read_text("utf-8")))
    data = ROOT / "data"
    for deck in ("poems_sensoji.json", "poems_tw60.json"):
        for p in json.loads((data / deck).read_text("utf-8"))["poems"]:
            for v in (p.get("lines", []), [p.get("rank", ""), p.get("ganzhi", "")]):
                for s in v:
                    chars |= set(s)
    cats = json.loads((data / "category_map.json").read_text("utf-8"))
    chars |= set(CJK.findall(json.dumps(cats, ensure_ascii=False)))
    return chars


def main() -> None:
    chars = collect()
    font = TTFont(SRC)
    cmap = font.getBestCmap()
    missing = sorted(c for c in chars if ord(c) > 0x7F and ord(c) not in cmap)

    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.name_languages = ["*"]
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in chars])
    sub.subset(font)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    font.save(OUT)
    shutil.copy(LICENSE, OUT_DIR / "OFL.txt")

    print(f"字數 {len(chars)}，輸出 {OUT.relative_to(ROOT)}（{OUT.stat().st_size / 1024:.0f} KB）")
    if missing:
        print(f"字型沒有的字（會用備用字型顯示）：{''.join(missing)}")


if __name__ == "__main__":
    main()
