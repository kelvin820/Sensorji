/// 籤詩資料模型（BUILD_PLAN 第 3 節）。
library;

import 'dart:ui' show Rect;

enum Deck {
  sensoji('淺草寺觀音百籤', 100),
  tw60('台灣六十甲子籤', 60);

  const Deck(this.label, this.size);
  final String label;
  final int size;
}

class Poem {
  const Poem({
    required this.deck,
    required this.number,
    required this.lines,
    this.rank,
    this.ganzhi,
    this.image,
  });

  final Deck deck;
  final int number;
  final List<String> lines;

  /// 淺草寺：吉凶（大吉、吉、半吉、小吉、末小吉、末吉、凶）。
  final String? rank;

  /// 六十甲子籤：干支。
  final String? ganzhi;

  /// 淺草寺：正版籤紙圖（asset 路徑）。
  final String? image;

  bool get isBad => rank == '凶';

  /// 好籤（淺草寺百籤的大吉、吉）：籤詩頁會降下「成」燈籠。
  /// 六十甲子籤沒有吉凶（rank 為 null），不算。
  bool get isGood => rank == '大吉' || rank == '吉';

  /// 籤號後面括號裡顯示的字：吉凶或干支。
  String get tag => rank ?? ganzhi ?? '';

  factory Poem.sensoji(Map<String, dynamic> j) => Poem(
        deck: Deck.sensoji,
        number: j['number'] as int,
        rank: j['rank'] as String,
        lines: (j['lines'] as List).cast<String>(),
        image: j['image'] as String,
      );

  factory Poem.tw60(Map<String, dynamic> j) => Poem(
        deck: Deck.tw60,
        number: j['number'] as int,
        ganzhi: j['ganzhi'] as String,
        lines: (j['lines'] as List).cast<String>(),
      );
}

class Category {
  const Category({
    required this.id,
    required this.label,
    required this.sensojiItem,
    required this.tw60Item,
  });

  final String id;
  final String label;

  /// 對應淺草寺判語的分項名稱。
  final String sensojiItem;

  /// 六十甲子籤的分項名稱（只給 LLM 參考）。
  final String tw60Item;

  String itemFor(Deck deck) => deck == Deck.sensoji ? sensojiItem : tw60Item;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        label: j['label'] as String,
        sensojiItem: j['sensoji'] as String,
        tw60Item: j['tw60'] as String,
      );
}

/// 淺草寺籤紙上可以點的區域（分鏡 ⑤），座標是對整張籤紙圖的 0…1 比例。
/// 由 tools/hotspots.py 從籤紙圖量出，存在 assets/data/hotspots_sensoji.json。
class SlipHotspots {
  const SlipHotspots({required this.lines, required this.judgment});

  /// 四句，與 Poem.lines 同順序（第一句在籤紙最右欄）。
  final List<Rect> lines;

  /// 最左欄的判語。
  final Rect judgment;

  static Rect _rect(List<dynamic> v) => Rect.fromLTRB(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      );

  factory SlipHotspots.fromJson(Map<String, dynamic> j) => SlipHotspots(
        lines: [for (final r in j['lines'] as List) _rect(r as List)],
        judgment: _rect(j['judgment'] as List),
      );
}

class Judgment {
  const Judgment({required this.number, required this.original, required this.items});

  final int number;
  final String original;
  final Map<String, String> items;

  /// 該分項判語；缺分項（第 28 籤沒有「旅行」）時回傳整段原文。
  String forItem(String item) => items[item] ?? original;

  factory Judgment.fromJson(Map<String, dynamic> j) => Judgment(
        number: j['number'] as int,
        original: j['judgment_original'] as String,
        items: (j['items'] as Map).cast<String, String>(),
      );
}
