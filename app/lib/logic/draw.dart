/// 抽籤與擲筊規則（BUILD_PLAN 第 5 節）。
library;

import 'dart:math';

import '../data/models.dart';

/// 籤號用安全亂數產生。
class DrawService {
  DrawService([Random? random]) : _random = random ?? Random.secure();
  final Random _random;

  int drawNumber(Deck deck) => _random.nextInt(deck.size) + 1;

  /// 擲一次筊：聖杯 1/2、笑杯 1/4、陰杯 1/4。
  JiaoResult throwJiao() {
    // 兩片筊各自獨立：一平一凸＝聖杯。
    final a = _random.nextBool();
    final b = _random.nextBool();
    if (a != b) return JiaoResult.holy;
    return a ? JiaoResult.laughing : JiaoResult.negative;
  }
}

enum JiaoResult {
  holy('聖杯', '一平一凸：神明應允'),
  laughing('笑杯', '兩平面朝上：神明笑而不答'),
  negative('陰杯', '兩凸面朝上：神明不同意');

  const JiaoResult(this.label, this.meaning);
  final String label;
  final String meaning;

  /// 給 Rive jiaobei.riv 的 result 輸入。
  int get riveValue => index;
}

/// 擲筊確認設定（僅六十甲子籤）。
enum JiaobeiMode {
  none('不擲筊', 0),
  once('擲一次聖杯', 1),
  thrice('連續三個聖杯', 3);

  const JiaobeiMode(this.label, this.required);
  final String label;
  final int required;
}

enum JiaobeiStatus { inProgress, confirmed, failed }

/// 一次擲筊確認的進度：連續 [required] 個聖杯才算確認，任一次非聖杯即失敗。
class JiaobeiSession {
  JiaobeiSession(this.required) : assert(required > 0);

  final int required;
  final List<JiaoResult> results = [];

  int get holyCount => results.where((r) => r == JiaoResult.holy).length;

  JiaobeiStatus get status {
    if (results.any((r) => r != JiaoResult.holy)) return JiaobeiStatus.failed;
    return holyCount >= required ? JiaobeiStatus.confirmed : JiaobeiStatus.inProgress;
  }

  void add(JiaoResult r) {
    if (status != JiaobeiStatus.inProgress) throw StateError('擲筊已結束');
    results.add(r);
  }
}
