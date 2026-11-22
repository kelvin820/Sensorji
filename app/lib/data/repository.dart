import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// 從 assets/data 載入全部籤詩資料（約 120 KB，啟動時一次載入）。
class PoemRepository {
  PoemRepository._(this._sensoji, this._tw60, this._judgments, this.categories, this._gloss);

  final Map<int, Poem> _sensoji;
  final Map<int, Poem> _tw60;
  final Map<int, Judgment> _judgments;
  final List<Category> categories;
  final Map<Deck, Map<int, List<String>>> _gloss;

  static Future<PoemRepository> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    Future<dynamic> read(String name) async => jsonDecode(await b.loadString('assets/data/$name'));

    final sensoji = (await read('poems_sensoji.json'))['poems'] as List;
    final tw60 = (await read('poems_tw60.json'))['poems'] as List;
    final judgments = await read('judgments_sensoji.json') as List;
    final cats = (await read('category_map.json'))['categories'] as List;
    Future<Map<int, List<String>>> gloss(String deck) async => {
          for (final j in (await read('line_gloss_$deck.json'))['poems'] as List)
            j['number'] as int: [for (final g in j['gloss'] as List) g as String],
        };

    return PoemRepository._(
      {for (final j in sensoji) j['number'] as int: Poem.sensoji(j as Map<String, dynamic>)},
      {for (final j in tw60) j['number'] as int: Poem.tw60(j as Map<String, dynamic>)},
      {for (final j in judgments) j['number'] as int: Judgment.fromJson(j as Map<String, dynamic>)},
      [for (final j in cats) Category.fromJson(j as Map<String, dynamic>)],
      {Deck.sensoji: await gloss('sensoji'), Deck.tw60: await gloss('tw60')},
    );
  }

  int count(Deck deck) => deck == Deck.sensoji ? _sensoji.length : _tw60.length;

  Poem poem(Deck deck, int number) => (deck == Deck.sensoji ? _sensoji : _tw60)[number]!;

  /// 逐句白話（事先寫好的靜態資料，與 Poem.lines 同順序）；沒有資料時回傳空清單。
  List<String> gloss(Deck deck, int number) => _gloss[deck]?[number] ?? const [];

  Judgment? judgment(int number) => _judgments[number];

  Category category(String id) => categories.firstWhere((c) => c.id == id);
}
