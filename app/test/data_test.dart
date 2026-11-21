import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensoji/data/models.dart';
import 'package:sensoji/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('資料檔完整（100／60 筆、欄位不缺、類別對照有效）', () async {
    final repo = await PoemRepository.load(rootBundle);
    expect(repo.count(Deck.sensoji), 100);
    expect(repo.count(Deck.tw60), 60);
    expect(repo.categories, hasLength(8));

    for (var n = 1; n <= 100; n++) {
      final p = repo.poem(Deck.sensoji, n);
      expect(p.lines, hasLength(4));
      expect(p.rank, isNotEmpty);
      expect(p.image, 'assets/slips/sensoji_${n.toString().padLeft(3, '0')}.webp');
      expect(repo.judgment(n), isNotNull);
    }
    for (var n = 1; n <= 60; n++) {
      expect(repo.poem(Deck.tw60, n).ganzhi, hasLength(2));
    }
  });

  test('第 28 籤缺「旅行」時改用整段判語', () async {
    final repo = await PoemRepository.load(rootBundle);
    final j = repo.judgment(28)!;
    expect(j.items.containsKey('旅行'), isFalse);
    expect(j.forItem('旅行'), j.original);
    expect(repo.judgment(1)!.forItem('病人'), '病人本ぶくすべし');
  });
}
