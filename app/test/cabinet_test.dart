import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/app/theme.dart';
import 'package:sensoji/data/models.dart';
import 'package:sensoji/ui/widgets/cabinet.dart';

Future<void> pumpCabinet(WidgetTester tester, Deck deck, {required bool reduced, int number = 77}) async {
  useGoogleFonts = false;
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduced);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: DrawerCabinet(number: number, deck: deck))));
}

Finder image(String name) => find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith('$name.webp'),
    );

void main() {
  testWidgets('③ 淺草寺：籤櫃推近 → 抽屜面寫籤號 → 拉開抽屜', (tester) async {
    await pumpCabinet(tester, Deck.sensoji, reduced: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(image('OB04'), findsOneWidget, reason: '先看到整面籤櫃');
    expect(image('OB04_drawer_out'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2800));
    expect(image('OB04'), findsNothing, reason: '推近後換成抽屜面');
    expect(image('OB04_drawer_front'), findsOneWidget);

    await tester.pump(kCabinetDuration);
    expect(image('OB04_drawer_out'), findsOneWidget, reason: '最後抽屜拉開');
    expect(image('OB04_drawer_front'), findsNothing);
    for (final ch in ['第', '七', '十', '籤']) {
      expect(find.text(ch), findsWidgets);
    }
    await tester.pumpWidget(const SizedBox()); // 停掉呼吸光暈
  });

  testWidgets('六十甲子：只有抽屜面，不拉開', (tester) async {
    await pumpCabinet(tester, Deck.tw60, reduced: false, number: 5);
    expect(image('OB04'), findsNothing);
    await tester.pump(kCabinetDuration);
    expect(image('OB04_drawer_front'), findsOneWidget);
    expect(image('OB04_drawer_out'), findsNothing);
    expect(find.text('五'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('減少動態效果：直接是拉開的抽屜，沒有持續動畫', (tester) async {
    await pumpCabinet(tester, Deck.sensoji, reduced: true, number: 1);
    await tester.pumpAndSettle();
    expect(image('OB04_drawer_out'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
  });
}
