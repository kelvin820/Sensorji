import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// 燈籠素材 OB01_raimon／OB01_sei（896×1326，字已合成在圖上，App 不疊字）。
const kLanternAspect = 1326 / 896; // 高 ÷ 寬

/// 旋轉中心：頂環中央，像素 (448, 24)（由素材 alpha 量得，三張燈籠圖相同）。
const kLanternPivot = Alignment(448 / 896 * 2 - 1, 24 / 1326 * 2 - 1);

/// 頂環中央距圖頂的比例，吊繩要接到這裡。
const kLanternPivotY = 24 / 1326;

// ── 好籤「成」燈籠（BUILD_PLAN 第 6 節） ──────────────────────────

/// 寬度約為畫面寬的 22%；寬螢幕（Web）封頂，免得燈籠大到喧賓奪主。
/// 燈籠刻意掛在籤紙右上角上方、與籤紙重疊（使用者決定：籤紙不縮小，好籤要有喜氣）。
const kGoodLanternWidthFactor = 0.22;
const kGoodLanternMaxWidth = 130.0;

/// 燈籠右緣距畫面右緣。
const kGoodLanternRight = 12.0;

/// 停住時，頂環在狀態列下方多少（吊繩從畫面頂端垂下來接到頂環）。
const kGoodLanternRingTop = 14.0;

/// 籤紙展開完成的時間點。目前籤紙沒有展開動畫，以進入籤詩頁的換頁轉場（約 0.3 秒）為準；
/// 之後做了展開動畫，改這個常數即可。
const kSlipUnfoldDuration = Duration(milliseconds: 300);

/// 展開完成後再等 0.4 秒才開始降下。
const kGoodLanternDelay = Duration(milliseconds: 400);
const kGoodLanternDrop = Duration(milliseconds: 900);

/// 擺動：±1.5°，週期 6 秒。
const kGoodLanternSwayDeg = 1.5;
const kGoodLanternSwayPeriod = Duration(seconds: 6);

/// 光暈：暖金色，低不透明度緩慢呼吸。
const kGoodLanternGlow = Color(0xFFE3C68E);
const kGoodLanternBreath = Duration(seconds: 4);

/// 「減少動態效果」時直接淡入。
const kGoodLanternFade = Duration(milliseconds: 400);

double goodLanternWidth(Size screen) =>
    min(screen.width * kGoodLanternWidthFactor, kGoodLanternMaxWidth);

/// 好籤時從右上角沿吊繩降下的「成」燈籠，放在整個畫面最上層，不吃點擊。
class GoodLantern extends StatefulWidget {
  const GoodLantern({super.key});

  @override
  State<GoodLantern> createState() => _GoodLanternState();
}

class _GoodLanternState extends State<GoodLantern> with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(vsync: this, duration: kGoodLanternDrop);
  late final AnimationController _sway = AnimationController(vsync: this, duration: kGoodLanternSwayPeriod);
  late final AnimationController _breath = AnimationController(vsync: this, duration: kGoodLanternBreath);
  late final AnimationController _fade = AnimationController(vsync: this, duration: kGoodLanternFade);
  bool? _reduced;
  bool _disposed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    final first = _reduced == null;
    _reduced = reduced;
    if (reduced) {
      _drop.value = 1;
      _sway.stop();
      _breath.stop();
      first ? _fade.forward() : _fade.value = 1;
    } else {
      _fade.value = 1;
      if (first) {
        Future.delayed(kSlipUnfoldDuration + kGoodLanternDelay, () {
          if (!_disposed) _drop.forward();
        });
      } else {
        _drop.value = 1;
      }
      _sway.repeat();
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _drop.dispose();
    _sway.dispose();
    _breath.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = goodLanternWidth(mq.size);
    final h = w * kLanternAspect;
    final restRingY = mq.viewPadding.top + kGoodLanternRingTop; // 停住時頂環的位置
    final hiddenRingY = -h; // 起點：整顆燈籠在畫面上方外面
    final reduced = _reduced ?? false;
    // ease-out 降下，最後輕微回彈（easeOutBack 會略過頭再回到定點）
    final drop = CurvedAnimation(parent: _drop, curve: const Cubic(0.22, 1.2, 0.36, 1));
    final glowSize = w * 1.9;

    return IgnorePointer(
      child: Semantics(
        label: '好籤：「成」字燈籠',
        child: FadeTransition(
          opacity: _fade,
          child: AnimatedBuilder(
            animation: Listenable.merge([_drop, _sway, _breath]),
            builder: (context, _) {
              final ringY = hiddenRingY + (restRingY - hiddenRingY) * drop.value;
              final angle = reduced
                  ? 0.0
                  : sin(_sway.value * 2 * pi) * kGoodLanternSwayDeg * pi / 180;
              final glowAlpha = reduced ? 0.4 : 0.28 + 0.22 * Curves.easeInOut.transform(_breath.value);
              final pivotX = mq.size.width - kGoodLanternRight - w / 2;
              final top = ringY - h * kLanternPivotY;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 吊繩：從畫面頂端垂到頂環，跟著燈籠降下。
                  if (ringY > 0)
                    Positioned(
                      left: pivotX - 1,
                      top: 0,
                      width: 2,
                      height: ringY + 2,
                      child: const ColoredBox(color: Palette.ink),
                    ),
                  Positioned(
                    left: pivotX - w / 2,
                    top: top,
                    width: w,
                    height: h,
                    child: Transform.rotate(
                      angle: angle,
                      alignment: kLanternPivot,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // 光暈在燈籠後面
                          Positioned(
                            left: (w - glowSize) / 2,
                            top: (h - glowSize) / 2,
                            width: glowSize,
                            height: glowSize,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    kGoodLanternGlow.withValues(alpha: glowAlpha),
                                    kGoodLanternGlow.withValues(alpha: glowAlpha * 0.45),
                                    kGoodLanternGlow.withValues(alpha: 0),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Image.asset('assets/objects/OB01_sei.webp', width: w, height: h),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
