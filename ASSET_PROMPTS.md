# 心想事（Sensoji）美術素材清單與繪圖 Prompt

> 目標：讓使用者從打開 App 到拿到籤紙，都像真的走進淺草寺：雷門 → 仲見世 → 常香爐 → 籤亭 → 籤筒 → 百格籤櫃 → 正版籤紙。
> 正版籤紙是真實的物件，所以其他場景也要有同樣的「實物感」，畫風必須全套統一。

---

## 一、整體方向（先定案再開畫）

**主風格：日式水彩繪本風（和風水彩＋淡墨線）**，所有場景和物件都用同一種畫法。
- 理由：水彩的紙感和正版籤紙最搭；分層去背後可以做視差、晃動、開抽屜等動畫，Android 與 Web 都跑得動。
- 會動的物件（籤筒、籤棒、籤櫃抽屜、筊杯）若想要更立體，可另出「水彩質感的 3D 渲染」版本（第六節），但**同一個畫面裡不要混用兩種風格**。

**季節版本**：場景背景各出四季。App **依一天中的時辰**切換季節，讓使用者每天都有機會看到四季（設定裡可改成依真實季節，或固定某一季）。四季的光線因此要對上時辰：
- 春 = 晨（05:00–10:59）：櫻花、粉白花瓣，清晨柔光
- 夏 = 午（11:00–15:59）：青楓濃綠、風鈴、酸漿（ほおずき），明亮正午光 —— 見第十二節
- 秋 = 暮（16:00–18:59）：紅葉、銀杏，夕陽暖光 —— **第一版先做秋季**
- 冬 = 夜（19:00–04:59）：細雪、紅梅，藍色夜空與燈籠暖光

**重要規則**
1. **圖上不要有任何文字**（燈籠的「雷門」、招牌、籤號、門匾都由 App 疊上毛筆字）。AI 生圖畫漢字幾乎都會畫錯。
2. 物件類請生成在**純色平面背景**（純白或 #F1EADC），我會去背成透明 PNG；能直接輸出透明背景更好。
3. 你提供的參考照片（雷門、仲見世、五重塔、お札お守所、籤櫃、籤筒）只當**氛圍參考**，不要直接拿來做圖生圖或描圖：照片版權屬於攝影者（例如有浮水印的那幾張）。

## 二、共用 Prompt（每一張都要接在後面）

**風格錨點（STYLE）**
```
Japanese watercolor storybook illustration, soft wet-on-wet washes with visible cold-press paper grain, delicate sumi ink outlines, warm washi off-white paper tone (#F1EADC), muted vermilion and lacquer red (#B5321F), aged gold ochre (#8A5A1E), soft charcoal shadows, gentle late-autumn afternoon light, serene and reverent atmosphere, faint drifting incense haze, high detail, consistent hand-painted look
```

**負面 Prompt（NEGATIVE）**
```
text, letters, kanji, characters, signage text, watermark, signature, logo, photorealistic, photograph, 3d render, neon, harsh contrast, oversaturated, modern buildings, skyscrapers, cars, crowds in foreground, faces in detail, blurry, low resolution, frame, border
```

**季節替換字串（SEASON）**：把背景 Prompt 裡的 `{SEASON}` 換成下列其中一段
- 秋：`autumn, scattered red maple (momiji) and golden ginkgo leaves, warm amber light`
- 冬：`winter night, light falling snow, red plum blossoms, deep indigo evening sky, glowing warm lanterns casting soft light on the snow`
- 春：`spring, cherry blossoms in full bloom, drifting pale pink petals, soft morning light`
- 夏：`early summer, lush deep-green maple foliage (aomomiji), glass wind chimes (furin) with blank paper strips hanging from the eaves, clear bright sky with soft cumulus clouds, bright midday light`

> 畫夏季時，STYLE 裡的 `gentle late-autumn afternoon light` 要換成 `clear early-summer light`；畫冬季時換成 `quiet snowy night light`，否則整張會被拉回秋天的色調。
>
> 已交件的冬季背景是白天的灰天，第一版先由 App 疊一層夜色（壓暗、偏藍、燈籠加光暈）。之後若要更好看，再用上面的冬季夜晚字串重畫六張，檔名一樣用 `_winter`。

**常用工具參數**
- Midjourney：背景加 `--ar 9:19.5 --style raw --v 7`，物件加 `--ar 1:1 --style raw --v 7`；同一批用同一個 `--sref`（先挑出第一張滿意的圖當風格參考）以保持一致。
- 其他工具（DALL·E、Flux、SDXL 等）：直接用 STYLE＋NEGATIVE，並固定同一個 seed。

## 三、交付規格

| 類型 | 尺寸 | 格式 | 備註 |
|---|---|---|---|
| 全螢幕背景 | 1290×2796（直式 9:19.5） | PNG | 上方 15%、下方 30% 畫面要安靜留白，放 UI 用 |
| 背景分層 | 同上 | PNG | 若工具可分層：天空／遠景／中景／前景各一張，做視差用 |
| 物件 | 長邊 ≥ 2048 | PNG（透明或純色底） | 置中、四周留 10% 空白、正面或指定角度 |
| 小裝飾（葉、花瓣） | 512×512 | PNG | 每種 5 個不同形狀，做飄落粒子 |
| 可拼貼材質 | 1024×1024 | PNG | 需要四方連續（seamless tile） |

**交件位置與命名**：放在 `C:\Users\User\Sensoji\素材\`，檔名用下表的「編號」，例如 `BG01_autumn.png`、`OB02.png`。同一編號有多張候選就加 `_a`、`_b`。

## 四、場景背景（BG）

| 編號 | 用在哪 | 內容 |
|---|---|---|
| BG01 | 01 首頁 | 雷門正面仰望 |
| BG02 | 02 提問 | 仲見世參道，遠方寶藏門 |
| BG03 | 03 搖籤 | 本堂前的常香爐，香煙繚繞 |
| BG04 | 04 籤號、05 擲筊 | 籤亭（おみくじ處）內部 |
| BG05 | 07 解籤、09 紀錄 | 五重塔與屋簷，安靜的遠景 |
| BG06 | 08 結籤 | 結籤的籤架一隅 |

**BG01 雷門（首頁）**
```
Kaminarimon gate of Senso-ji temple in Asakusa seen from the front at a slightly low angle, vermilion pillars and beams, green lattice panels, grey tiled roof with white rafter ends, a large blank red paper lantern hanging in the center with black top and bottom rings (no characters on it), {SEASON}, calm empty plaza in front, upper area of the composition filled by the gate roof, lower third soft and quiet for UI, [STYLE]
```
備註：燈籠會另外疊上獨立物件 OB01 做擺動，所以背景版的燈籠可以畫得淡一點，或請工具畫一個「沒有燈籠」的版本（加 `without the lantern`）。

**BG02 仲見世參道（提問）**
```
Nakamise shopping street leading to Senso-ji, two long rows of traditional shops with tiled roofs and red paper lanterns, the Hozomon gate in the distance, {SEASON}, a few distant visitors as soft silhouettes, shop signs blank, vanishing-point perspective, airy and warm, lower half calm and softly faded for UI, [STYLE]
```

**BG03 常香爐（搖籤）**
```
the large bronze incense burner (jokoro) in front of Senso-ji main hall, thick ribbons of incense smoke rising and swirling, the main hall's huge roof and red lanterns softly blurred behind, {SEASON}, sacred and lively atmosphere of devotion, center area open and slightly misty for an object overlay, [STYLE]
```

**BG04 籤亭（籤號、擲筊）**
```
interior of a traditional omikuji fortune booth at Senso-ji, a whole wall of small numbered wooden drawers in a dark red lacquered frame (drawer labels blank), wooden counter in front, warm paper lantern light from above, {SEASON} glimpsed through the open side, intimate and quiet, center of the counter left empty for an object overlay, [STYLE]
```

**BG05 五重塔（解籤、紀錄）**
```
the five-story pagoda of Senso-ji rising against a soft sky, sweeping temple eaves in the foreground corner, {SEASON}, peaceful and spacious, most of the frame is calm sky and soft washes so text can sit on top, [STYLE]
```

**BG06 結籤架（凶籤）**
```
a wooden omikuji tying rack at Senso-ji with many folded white paper fortune slips knotted onto its rails, a soft temple wall behind, {SEASON}, quiet and comforting mood, gentle light, empty space on one rail for an overlay, [STYLE]
```

## 五、物件（OB，需去背，做動畫用）

**OB01 雷門大燈籠（首頁主視覺，會擺動）**
```
a single giant Japanese red paper lantern (chochin) like the one at Kaminarimon, front view, barrel shape with fine horizontal ribs, glossy vermilion paper, black lacquered top ring and ornate black metal bottom base, blank face with no characters, isolated on a plain off-white background, [STYLE]
```
同一張再出兩種角度：`slightly turned to the left`、`slightly turned to the right`（做擺動補間）。

**OB02 籤筒（搖籤主角）**
```
a traditional hexagonal omikuji shaking box, aged silver metal with soft scratches and warm reflections, small hole on the top, front three-quarter view, upright, isolated on a plain off-white background, no lettering on the box, [STYLE]
```
再出一個木製版本：`made of dark lacquered wood with brass corners`（之後二選一）。

**OB03 籤棒**
```
a single thin bamboo omikuji stick, pale natural bamboo with subtle grain and a rounded top, a small flat blank area near the top for a number, straight vertical view, isolated on a plain off-white background, [STYLE]
```
另出一張 `a bundle of about twelve such sticks, slightly fanned out`（籤筒口露出的那束）。

**OB04 百格籤櫃（籤櫃推鏡、抽屜拉開）**
```
front view of a wall cabinet of 100 small wooden drawers in a 10 by 10 grid, light hinoki wood drawer fronts with round pale wooden knobs, thin dark red lacquered frame between drawers, small blank metal label plates on each drawer, perfectly orthographic straight-on view, even lighting, [STYLE]
```
另出：
- `a single drawer pulled halfway out, three-quarter view, the inside empty, isolated on a plain off-white background`
- `a single drawer front, straight-on, isolated`（做拉開動畫的獨立件）

**OB05 筊杯（六十甲子籤擲筊）**
```
a pair of traditional Taiwanese divination moon blocks (jiaobei), crescent-shaped, red lacquered wood, one showing the flat side and one showing the rounded side, top-down view, isolated on a plain off-white background, [STYLE]
```
另出 `both flat sides up`、`both rounded sides up`、`a single block mid-air, tilted`。

**OB06 常香爐（可選，搖籤畫面前景）**
```
a large bronze temple incense burner with a small roof on top, front view, soft patina, gentle smoke rising, isolated on a plain off-white background, [STYLE]
```

**OB07 結好的籤條**
```
a narrow strip of white paper fortune slip folded lengthwise and tied in a simple knot around a thin wooden rail, close-up, side view, isolated on a plain off-white background, [STYLE]
```

**OB08 台灣籤詩紙（六十甲子籤用的空白籤紙）**
```
a blank traditional Taiwanese temple fortune paper slip, vertical rectangle, pale pink paper with a thin printed red double border and an empty title box at the top, empty body area, slight paper texture and soft wear, flat top-down view, no characters at all, isolated on a plain off-white background, [STYLE]
```

## 六、3D 版本（若決定用 3D 做會動的物件才需要）

把 STYLE 換成：
```
stylized 3D render with a hand-painted watercolor texture, soft subsurface lighting, gentle ambient occlusion, matte materials, warm late-autumn light, consistent with a Japanese watercolor storybook, clean silhouette, isolated on a plain off-white background
```
適用：OB02 籤筒、OB03 籤棒、OB04 籤櫃與抽屜、OB05 筊杯。若工具能輸出 3D 模型（.glb），請一併給我，可做即時旋轉與物理晃動。

## 七、裝飾小物（DE，做飄落與點綴粒子）

| 編號 | Prompt 主體（接 STYLE） |
|---|---|
| DE01 紅葉 | `a single red Japanese maple leaf, five variations in shape and shade, each isolated on plain off-white background` |
| DE02 銀杏 | `a single golden ginkgo leaf, five variations, isolated` |
| DE03 櫻花瓣 | `a single pale pink cherry blossom petal and one small full blossom, five variations, isolated` |
| DE04 雪花 | `soft watercolor snowflakes and snow dots, five variations, isolated` |
| DE05 香煙 | `a wisp of incense smoke, soft grey-white watercolor, tall vertical, three variations, isolated on plain off-white background` |

## 八、材質（TX，四方連續）

| 編號 | Prompt 主體（接 STYLE，最後加 `seamless tileable texture, flat, top-down`） |
|---|---|
| TX01 和紙 | `warm off-white washi paper with soft fibers` —— 全 App 底色 |
| TX02 檜木 | `light hinoki wood grain, pale and fine` —— 卡片、按鈕底 |
| TX03 朱漆 | `aged vermilion lacquer surface with subtle wear` —— 門楣、主按鈕 |
| TX04 銅綠屋瓦 | `copper roof with soft green patina` —— 頁首裝飾帶 |

## 九、App 圖示與啟動畫面

**IC01 App 圖示**
```
app icon, a single glowing red paper lantern centered, blank face, warm off-white washi background, simple bold silhouette readable at small size, [STYLE]
```
**IC02 啟動畫面**：用 BG01 秋季版加上 OB01，不另外生圖。

## 十、優先順序（先畫這些就能做出完整的第一版）

1. OB01 燈籠、OB02 籤筒、OB03 籤棒、OB04 籤櫃（含抽屜）—— 求籤動畫主線
2. BG01 雷門、BG03 常香爐、BG04 籤亭（秋季）
3. TX01 和紙、TX02 檜木、DE01 紅葉、DE05 香煙
4. OB05 筊杯、OB08 台灣籤紙、BG06 結籤架、OB07 籤條
5. BG02、BG05、IC01
6. 冬、春兩季的背景與 DE02–DE04
7. 夏季背景與 DE06、OB09（第十二節）
8. （可選）冬季夜晚版背景重畫

## 十一、素材回來之後我會做的事

- 去背、統一色調（對齊 #F1EADC 紙色與朱紅）、裁成交付規格。
- 背景拆層做視差；燈籠、籤筒、抽屜在設計稿上做出動態示意。
- 更新設計稿每個畫面與 `BUILD_PLAN.md` 的素材表，讓 Claude Code 直接引用。

## 十二、夏季組（補畫）

**交件命名**：背景加 `_summer`，例如 `BG01_summer_nolantern.png`、`BG03_summer.png`；其餘照原編號。物件（燈籠、籤筒、籤櫃、筊杯等）四季共用，**不用重畫**。

**夏季 STYLE（取代第二節的 STYLE，只用在夏季背景與夏季小物）**
```
Japanese watercolor storybook illustration, soft wet-on-wet washes with visible cold-press paper grain, delicate sumi ink outlines, warm washi off-white paper tone (#F1EADC), muted vermilion and lacquer red (#B5321F), fresh deep greens and soft sky blue, bright midday early-summer light, serene and reverent atmosphere, faint drifting incense haze, high detail, consistent hand-painted look
```
色調提醒：綠色要偏「水彩的青楓綠」帶一點黃，不要鮮豔的草綠；天空淡藍就好，整張仍以紙色為底。

**六張背景**：沿用第四節各 BG 的 Prompt，`{SEASON}` 換成夏季字串，再接上下列的夏季補充。

| 編號 | 夏季補充（接在該 BG Prompt 的 `{SEASON}` 後面） |
|---|---|
| BG01 雷門 | `lush green maple branches framing the gate, a few glass wind chimes on the side eaves, bright clear sky behind the roof` ＋ `without the lantern`（首頁用無燈籠版） |
| BG02 仲見世 | `paper wind chimes and green bamboo blinds (sudare) hung along the shop fronts, strong summer sunlight with soft shadows on the paving` |
| BG03 常香爐 | `stalls of potted Chinese lantern plants (hozuki) with bright orange husks and glass wind chimes near the main hall, as during the Hozuki-ichi summer fair` —— 七月酸漿市的代表畫面 |
| BG04 籤亭 | `cool shade inside the booth, deep green foliage and dappled sunlight glimpsed through the open side, a single glass wind chime hanging at the opening` |
| BG05 五重塔 | `tall cumulus clouds in a pale blue sky behind the pagoda, green treetops at the bottom corner` |
| BG06 結籤架 | `dappled green shade from maple leaves over the rack, soft summer light` |

**夏季小物（DE，做粒子與點綴）**

| 編號 | Prompt 主體（接夏季 STYLE） |
|---|---|
| DE06 青楓葉 | `a single fresh green Japanese maple leaf (aomomiji), five variations in shape and shade, each isolated on plain off-white background` |

**夏季物件（OB，去背）**

**OB09 風鈴（首頁簷下輕晃、搖籤時隨晃動發聲）**
```
a single Japanese glass wind chime (furin), clear glass bell with hand-painted goldfish and blue wave pattern, a small clapper, a long blank paper strip (tanzaku) hanging below with no writing, front view, isolated on a plain off-white background, [STYLE]
```
另出一張 `slightly swinging to the side, paper strip lifted by a breeze`（做擺動補間）。

**OB10 酸漿（可選，結籤或解籤畫面的點綴）**
```
a small sprig of Chinese lantern plant (hozuki) with three bright orange papery husks and green leaves, isolated on a plain off-white background, [STYLE]
```

**夏季優先順序**：BG01、BG03、BG04 → DE06、OB09 → 其餘背景 → OB10。（夏季對應正午，不需要螢火。）

## 十三、待重畫（已交件但品質不夠）

| 編號 | 問題 | 重畫方式 |
|---|---|---|
| DE03 櫻花瓣 | 白花瓣和紙色太接近，去背後邊緣變淡 | 原 Prompt 不變，背景改成 `isolated on a plain dark background (#2A221C)` |
| TX02 檜木 | 木紋裡畫進了煙霧，拼貼時看得出重複 | 原 Prompt 加 `clean wood only, no smoke, no haze, even lighting` |
| TX03 朱漆 | 色塊太大，拼貼重複感明顯 | 原 Prompt 加 `fine even texture, small-scale wear, no large blotches, even lighting` |
