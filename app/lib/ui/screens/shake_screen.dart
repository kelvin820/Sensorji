import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../logic/session.dart';
import '../../logic/shake.dart';
import '../widgets/season_scaffold.dart';

/// 需要的有效晃動次數（BUILD_PLAN 第 5 節：約 5–8 次）。
const shakesToDraw = 6;

/// 03 搖籤：籤筒隨晃動擺動，晃滿次數後落籤。之後籤筒換成 Rive shaker.riv。
class ShakeScreen extends StatefulWidget {
  const ShakeScreen({super.key, required this.session});
  final DrawSession session;

  @override
  State<ShakeScreen> createState() => _ShakeScreenState();
}

class _ShakeScreenState extends State<ShakeScreen> with TickerProviderStateMixin {
  ShakeDetector? _detector;
  int _count = 0;
  bool _dropping = false;
  late final AnimationController _wobble =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _drop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detector != null) return;
    final settings = AppScope.of(context).settings;
    _detector = ShakeDetector(
      sensitivity: settings.sensitivity,
      onShake: (intensity, _) => _onShake(intensity),
    )..start();
  }

  @override
  void dispose() {
    _detector?.stop();
    _wobble.dispose();
    _drop.dispose();
    super.dispose();
  }

  void _onShake(double intensity) {
    if (_dropping) return;
    final s = AppScope.of(context);
    if (s.settings.haptics) HapticFeedback.lightImpact();
    _wobble.forward(from: 0);
    setState(() => _count++);
    if (_count >= shakesToDraw) _dropStick();
  }

  Future<void> _dropStick() async {
    if (_dropping) return;
    final s = AppScope.of(context);
    _dropping = true;
    _detector?.stop();
    widget.session.number = s.draw.drawNumber(widget.session.deck);
    if (s.settings.haptics) HapticFeedback.mediumImpact();
    final reduced = MediaQuery.disableAnimationsOf(context);
    // 擲筊失敗重搖時縮短落籤動畫
    if (!reduced) {
      _drop.duration = Duration(milliseconds: widget.session.attempt > 1 ? 500 : 1100);
      await _drop.forward(from: 0);
    }
    if (mounted) context.pushReplacement('/number', extra: widget.session);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final text = Theme.of(context).textTheme;
    final fg = seasonText(context, session.season);
    final title = session.attempt > 1 ? '第 ${session.attempt} 次求籤' : '誠心搖籤';
    return SeasonScaffold(
      season: session.season,
      scene: 3,
      appBar: AppBar(title: Text(title), foregroundColor: fg),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            session.question.isEmpty ? session.category.label : '「${session.question}」',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLarge?.copyWith(color: fg),
          ),
          Expanded(child: Center(child: _Shaker(wobble: _wobble, drop: _drop, deck: session.deck))),
          Semantics(
            label: '搖晃進度 $_count / $shakesToDraw',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < shakesToDraw; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _count ? Palette.vermilion : fg.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('拿穩手機，上下輕搖', style: text.bodyMedium?.copyWith(color: fg)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _dropping ? null : _dropStick,
            style: TextButton.styleFrom(foregroundColor: fg, minimumSize: const Size(44, 48)),
            child: const Text('無法搖晃？點此抽籤'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Shaker extends StatelessWidget {
  const _Shaker({required this.wobble, required this.drop, required this.deck});

  final Animation<double> wobble;
  final Animation<double> drop;
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([wobble, drop]),
      builder: (context, _) {
        final w = sin(wobble.value * pi * 3) * (1 - wobble.value) * 0.18;
        final d = Curves.easeOutCubic.transform(drop.value);
        return SizedBox(
          width: 260,
          height: 360,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // 落出的籤棒
              Positioned(
                bottom: 150 + d * 150,
                child: Opacity(
                  opacity: drop.value == 0 ? 0 : 1,
                  child: Transform.rotate(
                    angle: d * 0.5,
                    child: Image.asset('assets/objects/OB03.webp', height: 200),
                  ),
                ),
              ),
              Transform.rotate(
                angle: w,
                alignment: Alignment.bottomCenter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset('assets/objects/OB02.webp', height: 300),
                    Text(
                      deck == Deck.sensoji ? '觀音籤' : '六十甲子',
                      style: serif(const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Palette.ink,
                        letterSpacing: 4,
                      )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
