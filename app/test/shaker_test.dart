import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensoji/logic/draw.dart';
import 'package:sensoji/logic/shaker_physics.dart';
import 'package:sensoji/ui/widgets/shaker.dart';

void simulate(ShakerPhysics p, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    p.step(1 / 60);
  }
}

Future<GlobalKey<ShakerState>> pumpShaker(WidgetTester tester, {required bool reduced}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduced);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final key = GlobalKey<ShakerState>();
  var landed = 0;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(child: Shaker(key: key, label: '觀音籤', progress: 0.5, onLand: () => landed++)),
    ),
  ));
  addTearDown(() => expect(landed, reduced ? 0 : 1, reason: '落地回呼只觸發一次'));
  return key;
}

void main() {
  group('籤筒物理', () {
    test('靜止時回到手機傾斜對應的角度', () {
      final p = ShakerPhysics(Random(1))..tilt = 1;
      simulate(p, 4);
      expect(p.angle, closeTo(ShakerPhysics.maxTiltAngle, 1e-3));
      expect(p.settled, isTrue);
    });

    test('搖一下會擺動、彈起，之後衰減回平衡', () {
      final p = ShakerPhysics(Random(1));
      p.kick(1);
      simulate(p, 0.1);
      expect(p.angle.abs(), greaterThan(0.05), reason: '被甩動');
      expect(p.lift, lessThan(-3), reason: '往上彈');
      expect(p.jiggle, lessThan(-3), reason: '籤棒往外跳');
      simulate(p, 5);
      expect(p.settled, isTrue);
    });

    test('掉幀的大步長也不會爆掉', () {
      final p = ShakerPhysics(Random(1))..kick(1);
      for (var i = 0; i < 20; i++) {
        p.step(0.5);
      }
      expect(p.angle.isFinite && p.angle.abs() < 1, isTrue);
    });
  });

  test('籤號轉中文', () {
    expect(chineseNumber(1), '一');
    expect(chineseNumber(10), '十');
    expect(chineseNumber(77), '七十七');
    expect(chineseNumber(100), '百');
  });

  testWidgets('② 落籤：籤棒滑出、翻轉落定，籤號逐字寫出後才完成', (tester) async {
    final key = await pumpShaker(tester, reduced: false);
    await tester.pump(const Duration(milliseconds: 500)); // 籤筒在搖

    var done = false;
    key.currentState!.drop(77).then((_) => done = true);
    await tester.pump();
    expect(find.text('第'), findsNothing, reason: '還在滑出');

    await tester.pump(kDropDuration * 0.6);
    expect(done, isFalse);

    await tester.pump(kDropDuration * 0.45);
    expect(done, isTrue);
    for (final ch in ['第', '七', '十', '籤']) {
      expect(find.text(ch), findsWidgets);
    }
    await tester.pumpWidget(const SizedBox()); // 停掉物理的 ticker
  });

  testWidgets('減少動態效果：不擺動，落籤直接完成並顯示籤號', (tester) async {
    final key = await pumpShaker(tester, reduced: true);
    key.currentState!.kick(1);
    await tester.pumpAndSettle(); // 沒有持續跑的動畫
    await key.currentState!.drop(3);
    await tester.pumpAndSettle();
    expect(find.text('三'), findsOneWidget);
  });
}
