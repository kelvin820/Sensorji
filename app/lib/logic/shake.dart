/// 搖晃偵測（BUILD_PLAN 第 5 節）：加速度變化量超過門檻、且與上一次間隔 ≥ 150 ms 才算一次。
library;

import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

enum ShakeSensitivity {
  low('低', 18),
  medium('中', 13),
  high('高', 9);

  const ShakeSensitivity(this.label, this.threshold);
  final String label;

  /// 去除重力後的加速度門檻（m/s²）。
  final double threshold;
}

/// 純邏輯，方便測試：餵入（時間, 加速度）樣本，回傳這次是否算一次有效晃動。
class ShakeCounter {
  ShakeCounter({required this.threshold, this.minInterval = const Duration(milliseconds: 150)});

  final double threshold;
  final Duration minInterval;
  Duration? _last;
  int count = 0;

  /// 回傳 0 表示不算；否則回傳這一下的強度（0–1）。
  double feed(Duration t, double x, double y, double z) {
    final magnitude = sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return 0;
    if (_last != null && t - _last! < minInterval) return 0;
    _last = t;
    count++;
    return ((magnitude - threshold) / (threshold * 2)).clamp(0.05, 1.0);
  }

  void reset() {
    _last = null;
    count = 0;
  }
}

/// 接上 sensors_plus。Web 沒有 DeviceMotion 或桌機時不會有事件，畫面另有點按抽籤。
class ShakeDetector {
  ShakeDetector({required ShakeSensitivity sensitivity, required this.onShake})
      : _counter = ShakeCounter(threshold: sensitivity.threshold);

  final ShakeCounter _counter;
  final void Function(double intensity, int count) onShake;
  StreamSubscription<UserAccelerometerEvent>? _sub;
  final Stopwatch _clock = Stopwatch();

  int get count => _counter.count;

  void start() {
    _clock.start();
    _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (e) {
        final intensity = _counter.feed(_clock.elapsed, e.x, e.y, e.z);
        if (intensity > 0) onShake(intensity, _counter.count);
      },
      onError: (_) {}, // 裝置沒有感測器：保持安靜，使用點按抽籤
      cancelOnError: true,
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _clock.stop();
  }
}
