import '../data/models.dart';
import 'season.dart';
import 'settings.dart';

/// 一次求籤流程的狀態：從「開始求籤」到看完解說。
/// 季節在流程開始時鎖定，途中跨過時段也不換（BUILD_PLAN 第 1 節）。
class DrawSession {
  DrawSession({
    required this.deck,
    required this.category,
    required this.inputMode,
    required this.season,
    this.question = '',
  }) : id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  final String id;
  final Deck deck;
  final Category category;
  final InputMode inputMode;
  final Season season;
  String question;

  /// 第幾次搖籤（擲筊失敗重搖會累加）。
  int attempt = 1;
  int? number;
}
