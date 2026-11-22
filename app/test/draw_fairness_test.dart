// 籤號公平性：用 App 實際的抽籤服務（Random.secure）抽一百萬次，做卡方適合度檢定。
// 若每個號碼機率相同，卡方值應落在自由度 n−1 的卡方分佈內；
// 超過 p = 0.001 的臨界值（淺草寺 99 自由度 148.23、六十甲子 59 自由度 98.32）才判定不平均。
import 'package:flutter_test/flutter_test.dart';
import 'package:sensoji/data/models.dart';
import 'package:sensoji/logic/draw.dart';

void main() {
  for (final (deck, critical) in [(Deck.sensoji, 148.23), (Deck.tw60, 98.32)]) {
    test('${deck.name}：1–${deck.size} 每個號碼機率相同（卡方檢定）', () {
      const n = 1000000;
      final draw = DrawService(); // 與 App 相同：Random.secure()
      final counts = List.filled(deck.size + 1, 0);
      for (var i = 0; i < n; i++) {
        counts[draw.drawNumber(deck)]++;
      }
      expect(counts[0], 0, reason: '不會抽到 0');
      final hits = counts.sublist(1);
      final expected = n / deck.size;
      final chi2 = hits.fold(0.0, (s, c) => s + (c - expected) * (c - expected) / expected);
      final lo = hits.reduce((a, b) => a < b ? a : b);
      final hi = hits.reduce((a, b) => a > b ? a : b);
      // ignore: avoid_print
      print('${deck.name}：抽 $n 次，每號期望 ${expected.toStringAsFixed(0)} 次；'
          '最少 $lo（${(lo / n * 100).toStringAsFixed(3)}%）、最多 $hi（${(hi / n * 100).toStringAsFixed(3)}%）；'
          '卡方 ${chi2.toStringAsFixed(1)}（自由度 ${deck.size - 1}，臨界值 $critical）');
      expect(hits.every((c) => c > 0), isTrue, reason: '每個號碼都抽得到');
      expect(chi2, lessThan(critical));
    });
  }
}
