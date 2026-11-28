import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/ui/widgets/tie_fold.dart';

Finder tiedImage() => find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith('OB07.webp'),
    );

void main() {
  late List<int> steps;
  late int knots;
  late int dones;

  Future<GlobalKey<TieFoldState>> pumpTie(WidgetTester tester, {bool tied = false}) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    steps = [];
    knots = 0;
    dones = 0;
    final key = GlobalKey<TieFoldState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TieFold(
          key: key,
          slipImage: 'assets/slips/sensoji_003.webp',
          tied: tied,
          onFoldStep: steps.add,
          onKnot: () => knots++,
          onDone: () => dones++,
        ),
      ),
    ));
    return key;
  }

  testWidgets('⑥ 往左拖折起來：每折一段通知一次；折過 60% 放開就自己折完並結上', (tester) async {
    final key = await pumpTie(tester);
    final g = await tester.startGesture(tester.getCenter(find.byType(TieFold)));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-16, 0));
      await tester.pump();
    }
    expect(key.currentState!.fold, greaterThan(0.6));
    expect(steps, [1, 2, 3], reason: '拖到約 70% 時折過三段');
    await g.up();
    await tester.pumpAndSettle();
    expect(steps, [1, 2, 3, 4, 5]);
    expect(knots, 1, reason: '繩結收緊一次');
    expect(dones, 1);
    expect(tiedImage(), findsOneWidget);
  });

  testWidgets('折不到 60% 就放開：攤回去，不會結', (tester) async {
    final key = await pumpTie(tester);
    await tester.drag(find.byType(TieFold), const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(key.currentState!.fold, 0);
    expect(knots, 0);
    expect(tiedImage(), findsNothing);
  });

  testWidgets('「幫我折好」自動完成；已結過的籤直接顯示結好的樣子', (tester) async {
    final key = await pumpTie(tester);
    key.currentState!.foldAll();
    await tester.pumpAndSettle();
    expect(knots, 1);
    expect(dones, 1);

    await pumpTie(tester, tied: true);
    await tester.pumpWidget(const SizedBox()); // 換新的 widget
    final again = await pumpTie(tester, tied: true);
    expect(again.currentState!.done, isTrue);
    expect(tiedImage(), findsOneWidget);
    expect(knots, 0, reason: '已結過不再觸發繩結');
  });
}
