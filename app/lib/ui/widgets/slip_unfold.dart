import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// 分鏡 ④ 籤紙抽出・展開（Flutter 程式動畫）。
///
/// 籤紙對折著從下方（抽屜）升上來 → 上半張沿對折線往上翻開（翻過一半前看到的是紙背）→
/// 一道斜射光掃過紙面 → 平放置中。對折處的陰影隨翻開淡掉，模擬紙面微捲。
/// [play] 為 false（從紀錄回看）或減少動態效果時直接顯示攤平的籤紙。
class SlipUnfold extends StatefulWidget {
  const SlipUnfold({super.key, required this.child, this.play = true});

  final Widget child;
  final bool play;

  @override
  State<SlipUnfold> createState() => _SlipUnfoldState();
}

// 時間軸（毫秒）
const _rise = (0, 650); // 對折的籤紙升上來
const _unfold = (450, 1500); // 翻開
const _sweep = (1450, 2400); // 斜射光掃過
const kSlipAnimDuration = Duration(milliseconds: 2400);

/// 籤紙攤平的時間點（好籤燈籠等這個時間點後再降下）。
const kSlipUnfoldEnd = Duration(milliseconds: 1500);

/// 紙背的顏色（和紙）。
const _paperBack = Color(0xFFEDE3D0);

class _SlipUnfoldState extends State<SlipUnfold> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: kSlipAnimDuration);
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    final first = _reduced == null;
    _reduced = reduced;
    if (reduced || !widget.play || !first) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg((int, int) r) {
    final ms = _c.value * kSlipAnimDuration.inMilliseconds;
    return ((ms - r.$1) / (r.$2 - r.$1)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        if (_c.value >= 1) return child!; // 攤平後就是原本的籤紙（可點、可縮放）
        final rise = Curves.easeOutCubic.transform(_seg(_rise));
        final unfold = Curves.easeInOutCubic.transform(_seg(_unfold));
        final sweep = _seg(_sweep);
        // 上半張的翻轉角：π＝摺在下半張上面（看到紙背），0＝攤平。
        final angle = pi * (1 - unfold);
        final showBack = angle > pi / 2;
        // 翻到正面後還沒攤平的部分，越斜越暗
        final topShade = showBack ? 0.0 : 0.35 * sin(angle);
        final foldShade = 0.28 * (1 - unfold);

        return IgnorePointer(
          child: Opacity(
            opacity: rise,
            child: Transform.translate(
              offset: Offset(0, 220 * (1 - rise)),
              child: Transform.scale(
                scale: 0.86 + 0.14 * Curves.easeOut.transform(_seg((0, 1500))),
                child: Stack(
                  children: [
                    // 下半張：不動，對折處有陰影
                    ClipRect(
                      clipper: const _Half(top: false),
                      child: Stack(
                        children: [
                          child!,
                          Positioned.fill(child: _shade(foldShade, fromTop: true)),
                        ],
                      ),
                    ),
                    // 上半張：繞中線翻開
                    Positioned.fill(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012) // 透視
                          ..rotateX(-angle),
                        child: ClipRect(
                          clipper: const _Half(top: true),
                          child: showBack
                              ? const ColoredBox(color: _paperBack, child: SizedBox.expand())
                              : Stack(
                                  fit: StackFit.passthrough,
                                  children: [
                                    child,
                                    Positioned.fill(child: _shade(topShade + foldShade, fromTop: false)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    // 斜射光掃過
                    if (sweep > 0 && sweep < 1) Positioned.fill(child: _light(sweep)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 對折線附近的陰影：[fromTop] 表示陰影在這半張的上緣（下半張），否則在下緣（上半張）。
  Widget _shade(double a, {required bool fromTop}) {
    if (a <= 0) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fromTop ? Alignment.center : Alignment.center,
          end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [Palette.ink.withValues(alpha: a), Palette.ink.withValues(alpha: 0)],
          stops: const [0, 0.6],
        ),
      ),
    );
  }

  /// 一道暖白的斜光帶，從左上掃到右下。
  Widget _light(double u) {
    final x = -1.6 + 3.2 * Curves.easeInOut.transform(u);
    final a = 0.42 * sin(pi * u);
    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(x - 0.9, -1),
            end: Alignment(x + 0.9, 1),
            colors: [
              const Color(0xFFFFF6E0).withValues(alpha: 0),
              const Color(0xFFFFF6E0).withValues(alpha: a),
              const Color(0xFFFFF6E0).withValues(alpha: 0),
            ],
            stops: const [0.35, 0.5, 0.65],
          ),
        ),
      ),
    );
  }
}

/// 只留上半或下半。
class _Half extends CustomClipper<Rect> {
  const _Half({required this.top});
  final bool top;

  @override
  Rect getClip(Size size) =>
      top ? Rect.fromLTWH(0, 0, size.width, size.height / 2) : Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2);

  @override
  bool shouldReclip(_Half old) => old.top != top;
}
