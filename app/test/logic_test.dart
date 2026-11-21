import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensoji/data/models.dart';
import 'package:sensoji/logic/draw.dart';
import 'package:sensoji/logic/interpret_client.dart';
import 'package:sensoji/logic/season.dart';
import 'package:sensoji/logic/shake.dart';

void main() {
  group('籤號亂數', () {
    test('範圍與分布均勻（卡方檢定）', () {
      for (final deck in Deck.values) {
        final draw = DrawService(Random(42));
        final counts = List.filled(deck.size + 1, 0);
        const n = 200000;
        for (var i = 0; i < n; i++) {
          final x = draw.drawNumber(deck);
          expect(x, inInclusiveRange(1, deck.size));
          counts[x]++;
        }
        final expected = n / deck.size;
        final chi2 = counts.skip(1).fold<double>(0, (a, c) => a + pow(c - expected, 2) / expected);
        // 自由度 99／59，p=0.001 的臨界值約 149／98
        expect(chi2, lessThan(deck == Deck.sensoji ? 149 : 98), reason: '${deck.name} χ²=$chi2');
      }
    });

    test('預設使用安全亂數', () {
      expect(DrawService().drawNumber(Deck.sensoji), inInclusiveRange(1, 100));
    });
  });

  group('擲筊', () {
    test('機率：聖 1/2、笑 1/4、陰 1/4', () {
      final draw = DrawService(Random(7));
      final c = {for (final r in JiaoResult.values) r: 0};
      const n = 100000;
      for (var i = 0; i < n; i++) {
        final r = draw.throwJiao();
        c[r] = c[r]! + 1;
      }
      expect(c[JiaoResult.holy]! / n, closeTo(0.5, 0.01));
      expect(c[JiaoResult.laughing]! / n, closeTo(0.25, 0.01));
      expect(c[JiaoResult.negative]! / n, closeTo(0.25, 0.01));
    });

    test('連續三聖杯才確認', () {
      final s = JiaobeiSession(3);
      s.add(JiaoResult.holy);
      s.add(JiaoResult.holy);
      expect(s.status, JiaobeiStatus.inProgress);
      s.add(JiaoResult.holy);
      expect(s.status, JiaobeiStatus.confirmed);
      expect(() => s.add(JiaoResult.holy), throwsStateError);
    });

    test('中途非聖杯即失敗', () {
      final s = JiaobeiSession(3)
        ..add(JiaoResult.holy)
        ..add(JiaoResult.laughing);
      expect(s.status, JiaobeiStatus.failed);
    });

    test('一次聖杯模式', () {
      expect((JiaobeiSession(1)..add(JiaoResult.holy)).status, JiaobeiStatus.confirmed);
      expect((JiaobeiSession(1)..add(JiaoResult.negative)).status, JiaobeiStatus.failed);
      expect(JiaobeiMode.none.required, 0);
    });
  });

  group('季節', () {
    DateTime at(int h, [int m = 0, int month = 11]) => DateTime(2026, month, 21, h, m);

    test('依時辰的邊界', () {
      expect(seasonByHour(at(4, 59)), Season.winter);
      expect(seasonByHour(at(5)), Season.spring);
      expect(seasonByHour(at(10, 59)), Season.spring);
      expect(seasonByHour(at(11)), Season.summerNoon);
      expect(seasonByHour(at(13, 59)), Season.summerNoon);
      expect(seasonByHour(at(14)), Season.summer);
      expect(seasonByHour(at(15, 59)), Season.summer);
      expect(seasonByHour(at(16)), Season.autumn);
      expect(seasonByHour(at(18, 59)), Season.autumn);
      expect(seasonByHour(at(19)), Season.winter);
      expect(seasonByHour(at(0)), Season.winter);
    });

    test('依真實季節', () {
      expect(seasonByMonth(at(9, 0, 3)), Season.spring);
      expect(seasonByMonth(at(12, 0, 7)), Season.summerNoon);
      expect(seasonByMonth(at(17, 0, 9)), Season.summer);
      expect(seasonByMonth(at(9, 0, 10)), Season.autumn);
      expect(seasonByMonth(at(9, 0, 12)), Season.winter);
      expect(seasonByMonth(at(9, 0, 2)), Season.winter);
    });

    test('固定季節', () {
      expect(resolveSeason(SeasonMode.fixed, at(20), Season.spring), Season.spring);
      expect(resolveSeason(SeasonMode.fixed, at(12), Season.summer), Season.summerNoon);
    });

    test('背景與粒子路徑', () {
      expect(Season.summerNoon.background(1, noLantern: true), 'assets/bg/BG01_summer_noon_nolantern.webp');
      expect(Season.autumn.particles, hasLength(10));
      expect(Season.winter.isNight, isTrue);
    });
  });

  group('搖晃偵測', () {
    test('門檻與 150 ms 間隔', () {
      final c = ShakeCounter(threshold: 13);
      Duration ms(int v) => Duration(milliseconds: v);
      expect(c.feed(ms(0), 5, 5, 5), 0); // 未達門檻
      expect(c.feed(ms(10), 20, 0, 0), greaterThan(0));
      expect(c.feed(ms(100), 20, 0, 0), 0); // 間隔太短
      expect(c.feed(ms(170), 0, 20, 0), greaterThan(0));
      expect(c.count, 2);
    });
  });

  group('SSE 解析', () {
    test('切出事件', () async {
      final lines = Stream.fromIterable([
        'event: start',
        'data: {"section":"meaning"}',
        '',
        'event: delta',
        'data: {"section":"meaning","text":"月"}',
        '',
        'event: done',
        'data: {"truncated":false}',
        '',
      ]);
      final events = await parseSse(lines).toList();
      expect(events.map((e) => e.$1), ['start', 'delta', 'done']);
      expect(events[1].$2['text'], '月');
    });
  });
}
