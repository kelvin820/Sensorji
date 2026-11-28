"""合成 App 的音效（全部用程式算出來，沒有外部素材，沒有授權問題）。

輸出到 app/assets/sounds/*.wav（44.1 kHz、16-bit、單聲道）。只用標準函式庫：
    python tools/synth_sounds.py

聲音的做法：
  竹籤相碰 clack_*  ：短促的噪音敲擊 + 幾個快速衰減的竹管共振（不和諧的泛音比）
  籤落地 stick_land ：較重的一聲，低一點的共振，緊接一個小回彈
  磬 bell           ：缽形銅磬的泛音比 1 : 2.71 : 5.15 : 8.2，每個泛音成對微微走音產生「嗡—」的拍頻，長尾音
  抽屜 drawer       ：木頭摩擦（低通噪音、帶顆粒感的起伏），最後一聲輕輕的碰
  籤紙展開 unfold   ：紙張沙沙聲（高通噪音裡隨機的細小爆裂）
  折一折 fold       ：一下短促的紙張摺痕聲
  風鈴 chime        ：幾個五聲音階的金屬音，隨機間隔敲響
  筊杯落地 jiao_*   ：木塊碰地的悶響（低頻共振 + 敲擊）
隨機數種子固定，每次產生的檔案都一樣。
"""

import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "app" / "assets" / "sounds"
TAU = 2 * math.pi


# ── 小工具 ──────────────────────────────────────────────────

def zeros(sec):
    return [0.0] * int(SR * sec)


def mix(dst, src, at=0.0, gain=1.0):
    """把 src 疊到 dst 的 at 秒處（必要時延長 dst）。"""
    i0 = int(at * SR)
    need = i0 + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, v in enumerate(src):
        dst[i0 + i] += v * gain
    return dst


def noise(n, rng):
    return [rng.uniform(-1, 1) for _ in range(n)]


def biquad(x, kind, f, q=0.707):
    """RBJ biquad：lowpass / highpass / bandpass。"""
    w = TAU * f / SR
    cw, sw = math.cos(w), math.sin(w)
    a = sw / (2 * q)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "hp":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:  # bandpass，峰值增益 0 dB
        b0, b1, b2 = a, 0.0, -a
    a0, a1, a2 = 1 + a, -2 * cw, 1 - a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        out = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, out
        y[i] = out
    return y


def mode(freq, decay, sec, amp=1.0, phase=0.0, attack=0.0015):
    """一個衰減的正弦共振（decay：振幅降到 1/e 的秒數）。"""
    n = int(sec * SR)
    na = max(1, int(attack * SR))
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = math.exp(-t / decay) * (min(1.0, i / na))
        out[i] = amp * env * math.sin(TAU * freq * t + phase)
    return out


def envelope(x, fn):
    n = len(x)
    return [v * fn(i / SR, i / n) for i, v in enumerate(x)]


def fade_out(x, sec=0.01):
    n = min(len(x), int(sec * SR))
    for i in range(n):
        x[-1 - i] *= (i / n) ** 2
    return x


def normalize(x, peak):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


def write(name, x, peak=0.8, tail=0.01):
    x = fade_out(normalize(x, peak), tail)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
    print(f"{path.name:18s} {len(x) / SR:5.2f}s")


# ── 各種聲音 ────────────────────────────────────────────────

def clack(rng, pitch=1.0, weight=1.0, sec=0.16):
    """竹籤互碰：噪音敲擊 + 竹管的幾個不和諧共振。"""
    n = int(sec * SR)
    hit = envelope(noise(n, rng), lambda t, _: math.exp(-t / 0.004))
    hit = biquad(hit, "bp", 2800 * pitch, 0.9)
    out = [v * 0.9 for v in hit]
    for ratio, dec, amp in ((1.0, 0.020, 1.0), (2.31, 0.014, 0.6), (3.87, 0.010, 0.35), (5.6, 0.006, 0.2)):
        f = 1150 * pitch * ratio * rng.uniform(0.97, 1.03)
        mix(out, mode(f, dec * weight, sec, amp, rng.uniform(0, TAU), attack=0.0004))
    return out


def stick_land(rng):
    """一支籤落到籤筒口／地上：重的一聲 + 小回彈。"""
    out = clack(rng, pitch=0.62, weight=2.2, sec=0.45)
    mix(out, mode(310, 0.05, 0.3, 0.8), 0)  # 木頭的悶聲
    mix(out, clack(rng, pitch=0.66, weight=1.2, sec=0.2), at=0.085, gain=0.35)
    return out


def bell(rng):
    """銅磬：泛音成對微微走音，產生慢慢起伏的拍頻；長尾音。"""
    sec = 4.6
    f0 = 432.0
    out = zeros(sec)
    for ratio, dec, amp in ((1.0, 2.6, 1.0), (2.71, 1.5, 0.55), (5.15, 0.8, 0.28), (8.2, 0.45, 0.14), (11.9, 0.25, 0.06)):
        for detune in (-0.35 * ratio ** 0.5, 0.35 * ratio ** 0.5):
            mix(out, mode(f0 * ratio + detune, dec, sec, amp * 0.5, rng.uniform(0, TAU), attack=0.002))
    # 木槌敲下去那一下
    strike = envelope(noise(int(0.03 * SR), rng), lambda t, _: math.exp(-t / 0.003))
    mix(out, biquad(strike, "bp", 1800, 1.2), gain=0.5)
    return out


def drawer(rng):
    """木抽屜拉開：低通的摩擦噪音，強弱帶顆粒起伏，最後輕碰一下。"""
    sec = 0.95
    n = int(sec * SR)
    raw = noise(n, rng)
    # 摩擦的顆粒：每 15～40 ms 一個強弱
    grain = [0.0] * n
    i = 0
    level = 0.5
    while i < n:
        step = int(rng.uniform(0.015, 0.04) * SR)
        target = rng.uniform(0.35, 1.0)
        for k in range(min(step, n - i)):
            grain[i + k] = level + (target - level) * k / step
        level = target
        i += step
    body = biquad(biquad(raw, "lp", 900, 0.8), "hp", 120)
    shape = lambda t, u: min(1, t / 0.08) * (1 - 0.35 * u) * (1 if u < 0.78 else max(0, (0.86 - u) / 0.08))
    out = [v * g * shape(i / SR, i / n) for i, (v, g) in enumerate(zip(body, grain))]
    # 拉到底：木頭碰一下
    thunk = mode(180, 0.06, 0.3, 1.0)
    mix(thunk, mode(520, 0.025, 0.3, 0.5))
    mix(out, thunk, at=0.80, gain=0.3)
    return out


def paper_crackle(rng, sec, density, bright=4000):
    """紙張沙沙：隨機出現的細小爆裂（短促、高通的噪音）。density：每秒幾個，可為函式。"""
    out = zeros(sec)
    t = 0.0
    while t < sec:
        d = density(t / sec) if callable(density) else density
        t += rng.expovariate(max(d, 1))
        if t >= sec:
            break
        ln = int(rng.uniform(0.002, 0.012) * SR)
        click = envelope(noise(ln, rng), lambda tt, u: (1 - u) ** 2)
        mix(out, click, at=t, gain=rng.uniform(0.2, 1.0))
    # 底下一層很輕的摩擦
    hiss = envelope(noise(len(out), rng), lambda tt, u: 0.06)
    mix(out, hiss)
    return biquad(biquad(out, "hp", bright), "lp", 11000)


def unfold(rng):
    """籤紙展開：先慢後快再收尾的沙沙聲，最後輕輕一「啪」攤平。"""
    sec = 1.1
    out = paper_crackle(rng, sec, lambda u: 25 + 260 * math.sin(math.pi * min(1, u / 0.9)), bright=2500)
    out = envelope(out, lambda t, u: min(1, t / 0.05) * (1 if u < 0.85 else (1 - u) / 0.15))
    flap = envelope(noise(int(0.06 * SR), rng), lambda t, _: math.exp(-t / 0.012))
    mix(out, biquad(flap, "bp", 900, 0.7), at=0.92, gain=1.2)
    return out


def fold(rng):
    """折一折：一下短的紙張摺痕聲。"""
    sec = 0.16
    out = paper_crackle(rng, sec, 450, bright=3000)
    out = envelope(out, lambda t, u: min(1, t / 0.01) * (1 - u) ** 1.5)
    crease = envelope(noise(int(0.03 * SR), rng), lambda t, _: math.exp(-t / 0.006))
    mix(out, biquad(crease, "bp", 1500, 1.0), at=0.02, gain=1.5)
    return out


def chime(rng):
    """風鈴：五聲音階的幾個金屬棒，隨機間隔敲響（繩結收緊後的「安定」）。"""
    sec = 3.2
    out = zeros(sec)
    scale = [1568.0, 1760.0, 2093.0, 2349.0, 2637.0, 3136.0]  # G6 A6 C7 D7 E7 G7
    t = 0.0
    for k in range(6):
        f = rng.choice(scale)
        rod = zeros(1.8)
        for ratio, dec, amp in ((1.0, 0.9, 1.0), (2.76, 0.35, 0.4), (5.4, 0.15, 0.2)):
            mix(rod, mode(f * ratio, dec, 1.8, amp, rng.uniform(0, TAU), attack=0.001))
        mix(out, rod, at=t, gain=(1.0 if k == 0 else rng.uniform(0.35, 0.7)) * (1 - k * 0.1))
        t += rng.uniform(0.12, 0.32)
    return out[: int(sec * SR)]


def jiao(rng, heavy):
    """筊杯（木塊）碰地：低頻悶響 + 敲擊，輕的那一下（彈跳）短而高。"""
    sec = 0.4 if heavy else 0.22
    out = zeros(sec)
    hit = envelope(noise(int(0.02 * SR), rng), lambda t, _: math.exp(-t / 0.003))
    mix(out, biquad(hit, "bp", 1600 if heavy else 2200, 0.8), gain=0.8)
    p = 1.0 if heavy else 1.25
    for f, dec, amp in ((190, 0.07, 1.0), (470, 0.035, 0.6), (1130, 0.015, 0.35)):
        mix(out, mode(f * p * rng.uniform(0.97, 1.03), dec * (1 if heavy else 0.6), sec, amp, attack=0.0008))
    if heavy:  # 兩片筊杯幾乎同時落地：第二片慢一點點
        second = zeros(sec)
        for f, dec, amp in ((205, 0.06, 0.8), (505, 0.03, 0.5)):
            mix(second, mode(f, dec, sec - 0.03, amp, attack=0.0008))
        mix(out, second, at=0.028, gain=0.7)
    return out[: int(sec * SR)]


def main():
    rng = random.Random(20261128)
    for i, pitch in enumerate((1.0, 1.12, 0.9), start=1):
        write(f"clack_{i}", clack(rng, pitch), peak=0.7)
    write("stick_land", stick_land(rng), peak=0.9)
    write("bell", bell(rng), peak=0.75, tail=1.2)
    write("drawer", drawer(rng), peak=0.7)
    write("unfold", unfold(rng), peak=0.6)
    write("fold", fold(rng), peak=0.55)
    write("chime", chime(rng), peak=0.55, tail=0.8)
    write("jiao_heavy", jiao(rng, True), peak=0.9)
    write("jiao_light", jiao(rng, False), peak=0.55)


if __name__ == "__main__":
    main()
