import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/app/theme.dart';
import 'package:sensoji/data/models.dart';
import 'package:sensoji/data/repository.dart';
import 'package:sensoji/ui/widgets/slip_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('100 籤都有熱區：四句由右到左排、不重疊，判語在最左', () async {
    final repo = await PoemRepository.load(rootBundle);
    for (var n = 1; n <= 100; n++) {
      final h = repo.hotspots(n);
      expect(h, isNotNull, reason: '第 $n 籤');
      expect(h!.lines, hasLength(4));
      for (var i = 0; i < 3; i++) {
        expect(h.lines[i].left, closeTo(h.lines[i + 1].right, 0.001), reason: '第 $n 籤第 ${i + 1} 句左緣接下一句');
        expect(h.lines[i].width, inInclusiveRange(0.15, 0.21), reason: '第 $n 籤第 ${i + 1} 句寬度');
      }
      expect(h.judgment.right, closeTo(h.lines[3].left, 0.001));
      expect(h.judgment.left, lessThan(0.08));
      expect(h.lines[0].right, greaterThan(0.92));
    }
  });

  testWidgets('⑤ 點一句：浮出這句白話、框起來；再點同一句收起；點判語看分項', (tester) async {
    useGoogleFonts = false;
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 讀 asset 是真的非同步 I/O，要在 runAsync 裡做，否則在測試的假時間裡永遠等不到
    final repo = (await tester.runAsync(() => PoemRepository.load(rootBundle)))!;
    final poem = repo.poem(Deck.sensoji, 1);
    final gloss = repo.gloss(Deck.sensoji, 1);
    final key = GlobalKey<SlipReaderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SlipReader(
          key: key,
          poem: poem,
          hotspots: repo.hotspots(1)!,
          gloss: gloss,
          judgment: repo.judgment(1),
          image: const ColoredBox(color: Colors.white),
        ),
      ),
    ));

    // 點第二句那一欄的中間（座標換算成畫面上的位置）
    final slip = tester.getRect(find.byType(AspectRatio));
    Offset at(Rect r) => Offset(slip.left + r.center.dx * slip.width, slip.top + r.center.dy * slip.height);
    final h = repo.hotspots(1)!;

    await tester.tapAt(at(h.lines[1]));
    await tester.pumpAndSettle();
    expect(key.currentState!.selected, 1);
    expect(find.text(gloss[1]), findsOneWidget);
    expect(find.text('第 2 句'), findsOneWidget);

    await tester.tapAt(at(h.lines[1]));
    await tester.pumpAndSettle();
    expect(key.currentState!.selected, isNull);
    expect(find.text(gloss[1]), findsNothing);

    await tester.tapAt(at(h.judgment));
    await tester.pumpAndSettle();
    expect(find.text('判語'), findsOneWidget);
    expect(find.text('願望'), findsOneWidget);

    await tester.tap(find.byTooltip('收起'));
    await tester.pumpAndSettle();
    expect(key.currentState!.selected, isNull);
  });
}
