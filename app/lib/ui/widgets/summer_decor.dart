import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// 夏季點綴（BUILD_PLAN 第 2 節）：簷下的江戶風鈴 OB09、角落的酸漿 OB10。
/// 都是繞頂端掛點的單擺；「減少動態效果」時靜止。

/// OB09 風鈴 493×1600，掛鉤中央在 x = 245.5、頂端透明邊 20 px。
const kChimeAspect = 1600 / 493;
const kChimePivot = Alignment(245.5 / 493 * 2 - 1, 20 / 1600 * 2 - 1);

/// OB10 酸漿 814×1600，莖的頂端約在 x = 300。
const kHozukiAspect = 1600 / 814;
const kHozukiPivot = Alignment(300 / 814 * 2 - 1, -0.97);

/// 會擺動的掛飾：平常隨風微擺（[idleDeg]、[period]），[kick] 時再加一記衰減的擺盪。
class Pendulum extends StatefulWidget {
  const Pendulum({
    super.key,
    required this.child,
    required this.pivot,
    this.idleDeg = 2.5,
    this.period = const Duration(milliseconds: 4200),
    this.phase = 0,
  });

  final Widget child;
  final Alignment pivot;
  final double idleDeg;
  final Duration period;

  /// 起始相位（0–1），同畫面有兩個掛飾時錯開。
  final double phase;

  @override
  State<Pendulum> createState() => PendulumState();
}

class PendulumState extends State<Pendulum> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _now = Duration.zero;

  /// 被推一下的擺盪：振幅（弧度）與開始時間。
  double _kickAmp = 0;
  Duration _kickAt = Duration.zero;
  bool _reduced = false;

  static const _maxKick = 0.32; // 約 18°
  static const _kickDecay = 1.6; // 秒
  static const _kickFreq = 1.3; // Hz

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _tick(Duration t) => setState(() => _now = t);

  /// 推一下（[strength] 0–1），例如搖籤時。
  void kick(double strength) {
    if (_reduced) return;
    // 疊在目前剩下的擺盪上，但不超過上限
    _kickAmp = min(_maxKick, _currentKickAmp() + strength.clamp(0.0, 1.0) * 0.2);
    _kickAt = _now;
  }

  double _currentKickAmp() {
    final s = (_now - _kickAt).inMicroseconds / 1e6;
    return _kickAmp * exp(-s / _kickDecay);
  }

  /// 目前的角度（弧度）；測試用。
  double get angle {
    if (_reduced) return 0;
    final t = _now.inMicroseconds / 1e6;
    final p = widget.period.inMicroseconds / 1e6;
    final idle = sin((t / p + widget.phase) * 2 * pi) * widget.idleDeg * pi / 180;
    final s = (_now - _kickAt).inMicroseconds / 1e6;
    return idle + _currentKickAmp() * sin(s * _kickFreq * 2 * pi);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Transform.rotate(angle: angle, alignment: widget.pivot, child: widget.child);
}

/// 簷下風鈴：從畫面頂端垂一段細繩接到掛鉤。
class WindChime extends StatelessWidget {
  const WindChime({super.key, this.pendulumKey, required this.height, this.rope = 0});
  final GlobalKey<PendulumState>? pendulumKey;
  final double height;

  /// 掛鉤上方的繩長。
  final double rope;

  @override
  Widget build(BuildContext context) {
    final w = height / kChimeAspect;
    return IgnorePointer(
      child: SizedBox(
        width: w,
        height: rope + height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            if (rope > 0)
              Positioned(
                top: 0,
                left: w * (kChimePivot.x + 1) / 2 - 0.75,
                child: Container(width: 1.5, height: rope + height * 0.015, color: const Color(0x99403020)),
              ),
            Positioned(
              top: rope,
              left: 0,
              child: Pendulum(
                key: pendulumKey,
                pivot: kChimePivot,
                idleDeg: 3,
                period: const Duration(milliseconds: 3600),
                child: Image.asset(
                  'assets/objects/OB09.webp',
                  width: w,
                  height: height,
                  semanticLabel: '風鈴',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 酸漿：一枝掛在角落，微微隨風擺。
class Hozuki extends StatelessWidget {
  const Hozuki({super.key, required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: Pendulum(
            pivot: kHozukiPivot,
            idleDeg: 1.6,
            period: const Duration(milliseconds: 5200),
            phase: 0.3,
            child: Image.asset('assets/objects/OB10.webp', height: height, width: height / kHozukiAspect),
          ),
        ),
      );
}

/// 酸漿掛在右上角（App 列下方），一半露在畫面外，在內容之下。
class HozukiCorner extends StatelessWidget {
  const HozukiCorner({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = (mq.size.height * 0.2).clamp(120.0, 190.0);
    return Positioned(
      top: mq.padding.top + kToolbarHeight - 8,
      right: -h / kHozukiAspect * 0.35,
      child: Opacity(opacity: 0.9, child: Hozuki(height: h)),
    );
  }
}
