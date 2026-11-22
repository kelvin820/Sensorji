/// 籤筒的擺動物理（分鏡 ①）：純邏輯，方便測試。
///
/// 三個阻尼彈簧：
/// - [angle]：籤筒左右擺（弧度），平衡點跟著手機傾斜 [tilt] 走；
/// - [lift]：每搖一下籤筒往上彈（像素，負值是往上）；
/// - [jiggle]：籤棒尖端在洞口上下跳（像素），模擬籤束碰撞。
library;

import 'dart:math';

class ShakerPhysics {
  ShakerPhysics([Random? random]) : _random = random ?? Random();

  final Random _random;

  /// 手機左右傾斜 −1…1（由加速度計換算，已平滑）。
  double tilt = 0;

  double angle = 0, angleVel = 0;
  double lift = 0, liftVel = 0;
  double jiggle = 0, jiggleVel = 0;

  /// 傾斜到底時籤筒最多偏多少（約 11°）。
  static const maxTiltAngle = 0.2;

  /// 一次有效晃動：籤筒被甩一下、往上彈、籤束跳起來。[intensity] 0…1。
  void kick(double intensity) {
    final dir = _random.nextBool() ? 1.0 : -1.0;
    angleVel += dir * (1.4 + 2.6 * intensity);
    liftVel -= 140 + 260 * intensity;
    jiggleVel -= 90 + 220 * intensity;
  }

  /// 前進 [dt] 秒。大步長拆小步，掉幀時也穩定。
  void step(double dt) {
    var left = dt.clamp(0.0, 0.1);
    while (left > 0) {
      final h = min(left, 1 / 120);
      left -= h;
      final target = tilt.clamp(-1.0, 1.0) * maxTiltAngle;
      angleVel += (-70 * (angle - target) - 6 * angleVel) * h;
      angle += angleVel * h;
      liftVel += (-260 * lift - 20 * liftVel) * h;
      lift += liftVel * h;
      jiggleVel += (-320 * jiggle - 14 * jiggleVel) * h;
      jiggle += jiggleVel * h;
    }
  }

  /// 都回到平衡點、幾乎不動了。
  bool get settled {
    final target = tilt.clamp(-1.0, 1.0) * maxTiltAngle;
    return (angle - target).abs() < 1e-3 &&
        angleVel.abs() < 1e-2 &&
        lift.abs() < 0.2 &&
        liftVel.abs() < 1 &&
        jiggle.abs() < 0.2 &&
        jiggleVel.abs() < 1;
  }
}
