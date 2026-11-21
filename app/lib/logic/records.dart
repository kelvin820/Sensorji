import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import 'season.dart';

/// 一次求籤紀錄（BUILD_PLAN 第 9 節），只存本機。
class Reading {
  Reading({
    required this.id,
    required this.time,
    required this.season,
    required this.deck,
    required this.categoryId,
    required this.question,
    required this.number,
    required this.tag,
    Map<String, String>? sections,
    this.tied = false,
    this.favorite = false,
  }) : sections = sections ?? {};

  final String id;
  final DateTime time;
  final Season season;
  final Deck deck;
  final String categoryId;
  String question;
  final int number;

  /// 吉凶或干支。
  final String tag;

  /// AI 解說全文，鍵為 InterpretSection.name。
  final Map<String, String> sections;
  bool tied;
  bool favorite;

  Map<String, Object> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'season': season.suffix,
        'deck': deck.name,
        'category': categoryId,
        'question': question,
        'number': number,
        'tag': tag,
        'sections': sections,
        'tied': tied,
        'favorite': favorite,
      };

  factory Reading.fromJson(Map<String, dynamic> j) => Reading(
        id: j['id'] as String,
        time: DateTime.parse(j['time'] as String),
        season: Season.fromSuffix(j['season'] as String?) ?? Season.autumn,
        deck: Deck.values.byName(j['deck'] as String),
        categoryId: j['category'] as String,
        question: j['question'] as String,
        number: j['number'] as int,
        tag: j['tag'] as String,
        sections: (j['sections'] as Map).cast<String, String>(),
        tied: j['tied'] as bool? ?? false,
        favorite: j['favorite'] as bool? ?? false,
      );
}

/// 紀錄存放。第一版用 shared_preferences 存 JSON（紀錄量小、Android／Web 都可用）；
/// 之後若需要查詢或大量資料再換 drift，介面不變。
class RecordStore extends ChangeNotifier {
  RecordStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _items.addAll([
          for (final j in jsonDecode(raw) as List) Reading.fromJson(j as Map<String, dynamic>),
        ]);
      } catch (_) {
        // 資料損毀時從空白開始，不讓 App 無法啟動
      }
    }
  }

  static const _key = 'readings_v1';
  final SharedPreferences _prefs;
  final List<Reading> _items = [];

  static Future<RecordStore> load() async => RecordStore(await SharedPreferences.getInstance());

  /// 新的在前。
  List<Reading> get all => List.unmodifiable(_items.reversed);

  Reading? byId(String id) {
    for (final r in _items) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> save(Reading r) async {
    if (byId(r.id) == null) _items.add(r);
    await _persist();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((r) => r.id == id);
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode([for (final r in _items) r.toJson()]));
    notifyListeners();
  }
}
