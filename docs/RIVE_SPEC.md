# Rive 製作規格（給 Rive 製作人）

程式端（Flutter）照這份規格接線。**名稱要完全一致**（大小寫、底線），改名請先告知程式端。
分鏡與畫面見設計稿：https://claude.ai/artifact/Cb1crrBnFc8ZnHajoAZTQE

## 共通規則

- 素材：只用 `app/assets/objects/`、`sprites/`、`textures/` 的水彩圖（來源 `素材/processed/`，v2.7）。匯入 Rive 前先縮到實際需要的尺寸（手機寬 1080 px 為上限）。
- 背景、籤號、文字**不要**做進 Rive：背景由 App 依季節換；籤號、「雷門」「觀音籤」等字由 App 疊字（字型要跟 App 一致）。需要疊字的位置請放一個空的 **節點（Node）並命名**，程式會讀它的位置與旋轉。
- 每個檔一個 artboard、一個 state machine，state machine 一律命名 `main`。
- 執行端：Flutter `rive` 套件，Android 與 Web（CanvasKit）都要跑；不要用 Rive 的音效（音效由 App 播，以 Rive 事件觸發）。
- 效能：中階 Android 60 fps。每個檔案建議 ≤ 1.5 MB；骨架 ≤ 30 根、網格頂點能少則少。
- 減少動態效果：每個 state machine 都要有布林輸入 `reduced`，為 true 時跳過慢動作與鏡頭運動，直接到結果狀態（保留淡入淡出即可）。
- 事件（Rive Events）名稱用英文小寫底線；需要配音效的時間點一律發事件，App 收到後播音、震動。

## 檔案清單

### 1. `shaker.riv`：搖籤筒（分鏡 ①、③ 搖籤畫面、六十甲子籤同款）

素材：OB02 籤筒（或 OB02_wood）、OB03 籤棒、OB03_bundle 籤束。

| 輸入 | 型別 | 說明 |
|---|---|---|
| `tilt` | number −1…1 | 手機左右傾斜，籤筒隨之擺動（App 已做平滑） |
| `intensity` | number 0…1 | 這一下晃動的強度，用來決定籤束跳動幅度 |
| `shake` | trigger | 一次有效晃動（每次觸發籤束碰撞跳動一次） |
| `progress` | number 0…1 | 累計搖晃進度，越接近 1 籤棒越往外冒 |
| `drop` | trigger | 落籤：一支籤棒慢動作滑出、翻轉、落定 |
| `idle_wait` | boolean | 語音模式已晃滿但還在錄音時，維持輕晃等待 |
| `reduced` | boolean | 減少動態效果 |

| 事件 | 時機 |
|---|---|
| `clack` | 每次籤束碰撞（App 播竹籤碰撞音＋輕震） |
| `stick_land` | 籤棒落地 |
| `drop_done` | 落籤動畫結束，App 換到 04 籤號畫面 |

節點：`number_anchor`（籤棒上籤號的位置，App 疊毛筆字籤號；籤號逐筆浮現由 App 做）。

### 2. `cabinet.riv`：百格籤櫃（分鏡 ③，僅淺草寺）

素材：OB04 整牆（遠景）、OB04_drawer_front（近景）、OB04_drawer_out。

| 輸入 | 型別 | 說明 |
|---|---|---|
| `number` | number 1…100 | 籤號；10×10，第 1 號在左上，橫向排列（如需改排法請告知） |
| `go` | trigger | 鏡頭推進到該格 → 抽屜亮起 → 拉開 |
| `reduced` | boolean | 直接顯示拉開的抽屜 |

| 事件 | 時機 |
|---|---|
| `drawer_glow` | 抽屜亮起 |
| `drawer_open` | 開始拉開（App 播木頭摩擦聲） |
| `cabinet_done` | 結束，App 接籤紙抽出（分鏡 ④ 由 App shader 做） |

節點：`drawer_label`（抽屜上的號碼位置，App 疊字）、`slip_origin`（籤紙抽出的起點）。
注意：OB04 只有 1600×1600，推進到近處時請切換成 OB04_drawer_front，不要直接放大 OB04。

### 3. `jiaobei.riv`：擲筊（六十甲子籤）

素材：OB05_single、OB05_flat（平面朝上）、OB05_round（凸面朝上）。

| 輸入 | 型別 | 說明 |
|---|---|---|
| `result` | number | 0 = 聖杯（一平一凸）、1 = 笑杯（兩平）、2 = 陰杯（兩凸）；擲之前由 App 設定 |
| `throw` | trigger | 筊杯拋起、落地彈跳、停定在 `result` 的樣子 |
| `reduced` | boolean | 直接顯示停定結果 |

| 事件 | 時機 |
|---|---|
| `jiao_land` | 每次落地（彈跳可多次，App 播落地聲） |
| `throw_done` | 停定，App 顯示結果文字與進度 |

### 4. `tie.riv`：凶籤結籤（分鏡 ⑥，僅淺草寺）

素材：OB08 空白籤紙、OB07 結好的籤；背景 BG06（App 繪製，本身就是結籤架）。

| 輸入 | 型別 | 說明 |
|---|---|---|
| `fold` | number 0…1 | 使用者拖曳進度：0 = 攤開的籤紙，1 = 折成細條 |
| `tie` | trigger | 折好後繫上籤架、繩結收緊 |
| `reduced` | boolean | 直接顯示結好的籤 |

| 事件 | 時機 |
|---|---|
| `fold_step` | 每折一折（App 播紙聲） |
| `knot` | 繩結收緊（App 播風鈴＋一長一短震動） |
| `tie_done` | 結束，App 讓畫面漸暗 |

節點：`slip_face`（攤開時籤紙的位置與大小，App 會把該籤的正版籤紙圖貼在這裡；所以 OB08 只是形狀與摺痕參考）。
需確認：Rive 能否把 App 傳入的籤紙圖貼在變形中的網格上——若不行，改為 OB08 空白籤紙折疊，攤開狀態由 App 疊圖、開始折時交叉淡化。

### 5. `lantern.riv`：雷門燈籠（01 首頁）

素材：OB01。吊繩畫在 Rive 裡即可。

| 輸入 | 型別 | 說明 |
|---|---|---|
| `wind` | number 0…1 | 擺動幅度（App 依季節給；夏季稍大） |
| `reduced` | boolean | 靜止 |

旋轉中心在頂環中央。節點：`text_anchor`（燈籠上「雷門」二字位置，App 疊字）。

### 6. `ambient_summer.riv`：夏季點綴（可選，也可由 App 補間）

素材：OB09 風鈴、OB09_swing、OB10 酸漿。一個 artboard 放風鈴、另一個放酸漿，或拆兩檔皆可。

| 輸入 | 型別 | 說明 |
|---|---|---|
| `wind` | number 0…1 | 擺動幅度 |
| `chime` | trigger | 搖籤時風鈴大一點擺動 |
| `reduced` | boolean | 靜止 |

事件：`chime_ring`（App 播風鈴音）。

## 交付順序

1. `shaker.riv`（最優先：用來在中階 Android 實機驗證效果與 60 fps）
2. `jiaobei.riv`、`cabinet.riv`
3. `tie.riv`、`lantern.riv`、`ambient_summer.riv`

交付時把 `.riv` 放進 `app/assets/rive/`，並附上 Rive 編輯器的分享連結以便調整。
