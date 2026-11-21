import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// 當季飄落物。同時最多 [count] 片（BUILD_PLAN 第 6 節：≤ 30），「減少動態效果」時不顯示。
class ParticleLayer extends StatefulWidget {
  const ParticleLayer({super.key, required this.sprites, this.count = 14});

  final List<String> sprites;
  final int count;

  @override
  State<ParticleLayer> createState() => _ParticleLayerState();
}

class _Flake {
  _Flake(Random r, int spriteCount) {
    reset(r, spriteCount, initial: true);
  }

  late double x, y, size, speed, sway, phase, spin, angle;
  late int sprite;

  void reset(Random r, int spriteCount, {bool initial = false}) {
    x = r.nextDouble();
    y = initial ? r.nextDouble() : -0.1;
    size = 18 + r.nextDouble() * 22;
    speed = 0.025 + r.nextDouble() * 0.035; // 每秒落下的畫面比例
    sway = 0.01 + r.nextDouble() * 0.03;
    phase = r.nextDouble() * pi * 2;
    spin = (r.nextDouble() - 0.5) * 1.2;
    angle = r.nextDouble() * pi * 2;
    sprite = r.nextInt(spriteCount);
  }
}

class _ParticleLayerState extends State<ParticleLayer> with SingleTickerProviderStateMixin {
  final _random = Random();
  late final List<_Flake> _flakes =
      List.generate(widget.count, (_) => _Flake(_random, widget.sprites.length));
  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: const Duration(days: 1))..forward();
  Duration _last = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _step() {
    final now = _ticker.lastElapsedDuration ?? Duration.zero;
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.25) return;
    for (final f in _flakes) {
      f.y += f.speed * dt;
      f.phase += dt;
      f.angle += f.spin * dt;
      if (f.y > 1.1) f.reset(_random, widget.sprites.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        _step();
        return LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              for (final f in _flakes)
                Positioned(
                  left: (f.x + sin(f.phase) * f.sway) * c.maxWidth,
                  top: f.y * c.maxHeight,
                  child: Transform.rotate(
                    angle: f.angle,
                    child: Image.asset(widget.sprites[f.sprite], width: f.size, gaplessPlayback: true),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 香煙裊裊：DE05 三張緩慢上升、淡出。
class SmokeLayer extends StatefulWidget {
  const SmokeLayer({super.key});

  @override
  State<SmokeLayer> createState() => _SmokeLayerState();
}

class _SmokeLayerState extends State<SmokeLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Builder(builder: (context) {
                final t = (_c.value + i / 3) % 1.0;
                return Positioned(
                  left: box.maxWidth * (0.38 + i * 0.1),
                  bottom: box.maxHeight * (0.05 + t * 0.35),
                  child: Opacity(
                    opacity: (sin(t * pi) * 0.55).clamp(0.0, 1.0),
                    child: Image.asset('assets/sprites/DE05_${i + 1}.webp', height: 160),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
