"""檢查 app/assets/data 與素材完整性（BUILD_PLAN 第 11 節）。失敗時 exit 1。

用法：python -I tools/check_data.py
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "app" / "assets"
DATA = ASSETS / "data"

SENSOJI_RANKS = {"大吉": 17, "吉": 35, "半吉": 5, "小吉": 4, "末小吉": 3, "末吉": 6, "凶": 30}
JUDGMENT_KEYS = {"願望", "病人", "失物", "待人", "新居・遷移", "旅行", "婚姻", "雇人"}
SEASONS = ["spring", "summer_noon", "summer", "autumn", "winter"]

errors: list[str] = []
notes: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        errors.append(msg)


def load(name: str):
    return json.loads((DATA / name).read_text("utf-8"))


def sixty_cycle_tw60_order() -> list[str]:
    stems, branches = "甲乙丙丁戊己庚辛壬癸", "子丑寅卯辰巳午未申酉戌亥"
    out = []
    for i, s in enumerate(stems):
        start = 0 if i % 2 == 0 else 1
        out += [s + branches[(start + 2 * k) % 12] for k in range(6)]
    return out


def main() -> int:
    sensoji = load("poems_sensoji.json")["poems"]
    tw60 = load("poems_tw60.json")["poems"]
    judgments = load("judgments_sensoji.json")
    categories = load("category_map.json")["categories"]

    check([p["number"] for p in sensoji] == list(range(1, 101)), "淺草寺籤號需為 1–100 依序")
    check([p["number"] for p in tw60] == list(range(1, 61)), "六十甲子籤號需為 1–60 依序")
    check(dict(Counter(p["rank"] for p in sensoji)) == SENSOJI_RANKS, "淺草寺吉凶分布不符")
    for p in sensoji:
        check(len(p["lines"]) == 4 and all(len(l) == 5 for l in p["lines"]), f"淺草寺第 {p['number']} 籤不是四句五言")
        check((ROOT / "app" / p["image"]).is_file(), f"缺籤紙圖 {p['image']}")
        check((ROOT / "app" / p["thumb"]).is_file(), f"缺縮圖 {p['thumb']}")
    for p in tw60:
        check(len(p["lines"]) == 4 and all(len(l) == 7 for l in p["lines"]), f"六十甲子第 {p['number']} 籤不是四句七言")
    check([p["ganzhi"] for p in tw60] == sixty_cycle_tw60_order(), "六十甲子干支順序不符")

    jmap = {j["number"]: j for j in judgments}
    check(sorted(jmap) == list(range(1, 101)), "判語需有 1–100")
    for p in sensoji:
        j = jmap.get(p["number"])
        if not j:
            continue
        check(j["rank"] == p["rank"], f"第 {p['number']} 籤吉凶與判語不一致")
        missing = JUDGMENT_KEYS - set(j["items"])
        if missing:
            notes.append(f"第 {p['number']} 籤判語缺分項 {sorted(missing)}（解籤時改附整段原文）")

    for deck, poems in (("sensoji", sensoji), ("tw60", tw60)):
        gloss = load(f"line_gloss_{deck}.json")
        check([g["number"] for g in gloss["poems"]] == [p["number"] for p in poems], f"{deck} 逐句白話籤號不齊")
        for g in gloss["poems"]:
            check(len(g["gloss"]) == 4 and all(g["gloss"]), f"{deck} 第 {g['number']} 籤逐句白話不是四句")
            check(all(len(s) <= 40 for s in g["gloss"]), f"{deck} 第 {g['number']} 籤逐句白話有句子超過 40 字")
        if not gloss.get("reviewed"):
            notes.append(f"{deck} 逐句白話尚未人工審閱（審完把 reviewed 改成 true）")

    check(len(categories) == 8, "提問類別需為 8 類")
    for c in categories:
        check(c["sensoji"] in JUDGMENT_KEYS, f"類別 {c['id']} 的淺草寺分項 {c['sensoji']} 不存在")

    for scene in range(1, 7):
        for s in SEASONS:
            check((ASSETS / "bg" / f"BG0{scene}_{s}.webp").is_file(), f"缺背景 BG0{scene}_{s}")
        if scene == 1:
            for s in SEASONS:
                check((ASSETS / "bg" / f"BG01_{s}_nolantern.webp").is_file(), f"缺背景 BG01_{s}_nolantern")

    for e in errors:
        print("✗", e)
    for n in notes:
        print("!", n)
    print(f"{'失敗' if errors else '通過'}：{len(errors)} 個錯誤，{len(notes)} 個提醒")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
