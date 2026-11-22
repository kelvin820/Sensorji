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
    _quietly(() => _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
          (e) {
            final intensity = _counter.feed(_clock.elapsed, e.x, e.y, e.z);
            if (intensity > 0) onShake(intensity, _counter.count);
          },
          onError: (_) {}, // 裝置沒有感測器：保持安靜，使用點按抽籤
          cancelOnError: true,
        ));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _clock.stop();
  }
}

/// 手機左右傾斜（分鏡 ① 籤筒跟著擺）：用含重力的加速度計 x 軸換算成 −1…1，並做低通平滑。
/// 左緣朝下時為正。沒有感測器（Web 桌機）時不會有事件，維持 0。
class TiltSensor {
  TiltSensor(this.onTilt);

  final void Function(double tilt) onTilt;
  StreamSubscription<AccelerometerEvent>? _sub;
  double _smooth = 0;

  void start() {
    _quietly(() => _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
          (e) {
            _smooth += ((e.x / 9.8).clamp(-1.0, 1.0) - _smooth) * 0.2;
            onTilt(_smooth);
          },
          onError: (_) {},
          cancelOnError: true,
        ));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

/// sensors_plus 設定取樣頻率時是另外發出的非同步呼叫，沒有感測器外掛的環境（部分瀏覽器、測試）
/// 會丟出沒人接的錯誤。在這個 zone 裡啟動，錯誤就安靜吞掉，畫面仍可點按抽籤。
void _quietly(void Function() body) => runZonedGuarded(body, (_, _) {});
