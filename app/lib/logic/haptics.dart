/// 震動：Android 直接用馬達（可調長度與強度），比系統的觸覺回饋（HapticFeedback）明顯得多。
/// 其他平台或呼叫失敗時退回 HapticFeedback。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Haptics {
  static const _channel = MethodChannel('sensoji/haptics');

  /// 震一下：[ms] 毫秒，[strength] 0…1（對應馬達強度 1…255）。
  static Future<void> pulse(int ms, double strength) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('pulse', {
          'ms': ms,
          'amplitude': (1 + strength.clamp(0.0, 1.0) * 254).round(),
        });
        return;
      } catch (_) {
        // 舊機型或外掛不在：退回系統觸覺回饋
      }
    }
    await (strength > 0.6 ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact());
  }

  /// 搖一下：越用力震越久、越強。
  static Future<void> shake(double intensity) => pulse(45 + (40 * intensity).round(), 0.55 + 0.45 * intensity);

  /// 籤棒落地：一記重擊。
  static Future<void> land() => pulse(110, 1);
}
